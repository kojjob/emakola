defmodule Emakola.Notifications.Workers.SupplierNotificationWorkerTest do
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.Notifications.Workers.SupplierNotificationWorker
  alias Emakola.Factory

  setup :verify_on_exit!

  # ── Helpers ────────────────────────────────────────────────────

  defp setup_store do
    {_merchant, store} = Factory.create_merchant_with_store!()
    store
  end

  defp create_order_with_address(store) do
    Factory.create_order!(store, %{
      total: 25_000,
      currency: "GHS",
      shipping_address: %{
        "line_1" => "5 Liberation Road",
        "city" => "Accra",
        "region" => "Greater Accra"
      }
    })
  end

  defp create_line_item!(order, store, fulfillment) do
    product = Factory.create_product!(store)
    variant = Factory.create_variant!(product, store, %{price: 5000})

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 2,
      fulfillment_id: fulfillment.id
    })
    |> Ash.create!(authorize?: false)
  end

  defp perform(fulfillment_id, opts \\ []) do
    SupplierNotificationWorker.perform(%Oban.Job{
      args: %{"fulfillment_id" => fulfillment_id},
      attempt: Keyword.get(opts, :attempt, 1),
      max_attempts: Keyword.get(opts, :max_attempts, 3)
    })
  end

  defp reload(fulfillment_id) do
    Ash.get!(Emakola.Orders.Fulfillment, fulfillment_id, authorize?: false)
  end

  # ── WhatsApp routing ───────────────────────────────────────────

  describe "supplier with whatsapp_number" do
    test "sends WhatsApp and marks fulfillment notified via :whatsapp" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000001"})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn to, template, params, _opts ->
        assert to == "+233200000001"
        assert template == "supplier_fulfillment"
        assert params.order_number == order.order_number
        {:ok, %{provider: :mock}}
      end)

      assert :ok == perform(fulfillment.id)

      reloaded = reload(fulfillment.id)
      assert reloaded.status == :notified
      assert reloaded.notified_via == :whatsapp
      assert reloaded.notified_at
    end
  end

  # ── SMS routing ────────────────────────────────────────────────

  describe "supplier with only contact_phone" do
    test "sends SMS and marks fulfillment notified via :sms" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{contact_phone: "+233200000002"})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn to, message, _opts ->
        assert to == "+233200000002"
        assert message =~ order.order_number
        {:ok, %{provider: :mock}}
      end)

      assert :ok == perform(fulfillment.id)

      reloaded = reload(fulfillment.id)
      assert reloaded.status == :notified
      assert reloaded.notified_via == :sms
    end
  end

  # ── Failed provider send ───────────────────────────────────────

  describe "provider send failure" do
    test "returns the error and leaves fulfillment pending (Oban retries)" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000004"})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts -> {:error, :timeout} end)

      assert {:error, :timeout} == perform(fulfillment.id)

      assert reload(fulfillment.id).status == :pending
    end
  end

  # ── No contact info ────────────────────────────────────────────

  describe "supplier with no contact info" do
    test "sends nothing and leaves fulfillment pending" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})

      # No SMS/WhatsApp expectations — verify_on_exit! ensures none are called.
      assert :ok == perform(fulfillment.id)

      assert reload(fulfillment.id).status == :pending
    end
  end

  # ── Merchant group (supplier_id nil) ───────────────────────────

  describe "merchant group fulfillment" do
    test "skips sending and returns :ok" do
      store = setup_store()
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: nil})

      assert :ok == perform(fulfillment.id)
      assert reload(fulfillment.id).status == :pending
    end
  end

  describe "cancelled fulfillment" do
    test "skips the supplier notification and leaves it cancelled" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000009"})
      order = create_order_with_address(store)

      fulfillment =
        Factory.create_fulfillment!(order, store, %{
          supplier_id: supplier.id,
          status: :cancelled
        })

      # No provider expectation: verify_on_exit! proves cancellation prevents
      # a queued supplier job from telling them to dispatch the order.
      assert :ok == perform(fulfillment.id)
      assert reload(fulfillment.id).status == :cancelled
    end
  end

  # ── Idempotency / resend ───────────────────────────────────────

  describe "already-notified fulfillment" do
    test "re-sends but does not re-transition (no illegal transition error)" do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000003"})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, 2, fn _to, _template, _params, _opts -> {:ok, %{}} end)

      assert :ok == perform(fulfillment.id)
      assert reload(fulfillment.id).status == :notified

      # Second run: re-send, still :notified, no crash.
      assert :ok == perform(fulfillment.id)
      assert reload(fulfillment.id).status == :notified
    end
  end

  # ── Missing fulfillment ────────────────────────────────────────

  describe "non-existent fulfillment" do
    test "returns error tuple" do
      assert {:error, :fulfillment_not_found} == perform(Ash.UUID.generate())
    end
  end

  # ── Channel fallthrough (the rail that is broken in production) ──

  describe "falling through from WhatsApp to SMS" do
    # The headline regression. Today notify_supplier/1 is a cond: it picks
    # WhatsApp whenever whatsapp_number is set and returns the error straight
    # up, so a supplier with BOTH numbers gets nothing at all when the WhatsApp
    # token is bad — which is exactly the production state.
    test "a WhatsApp failure still reaches the supplier by SMS" do
      store = setup_store()

      supplier =
        Factory.create_supplier!(store, %{
          whatsapp_number: "+233200000010",
          contact_phone: "+233200000011"
        })

      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts ->
        {:error, %{status: 401, body: "invalid token"}}
      end)

      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

      assert :ok == perform(fulfillment.id)

      reloaded = reload(fulfillment.id)
      assert reloaded.status == :notified
      assert reloaded.notified_via == :sms
      assert is_nil(reloaded.last_send_error), "a success must clear the previous failure"
    end

    # whatsapp_number has no constraints and the admin form is free text, so an
    # empty string is truthy, routes to WhatsApp with "", 400s at Meta, and
    # never tries SMS. Fixing this REDUCES sends, which is why it is not behind
    # the cost flag.
    test "an empty-string whatsapp_number is skipped entirely, not sent to Meta" do
      store = setup_store()

      supplier =
        Factory.create_supplier!(store, %{
          whatsapp_number: "   ",
          contact_phone: "+233200000012"
        })

      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      # No WhatsApp expectation at all — verify_on_exit! proves none was made.
      Emakola.SMSProviderMock
      |> expect(:send_sms, fn _to, _message, _opts -> {:ok, %{}} end)

      assert :ok == perform(fulfillment.id)
      assert reload(fulfillment.id).notified_via == :sms
    end

    # The store's own 200/hour limiter firing is not a reason to spend money.
    # Falling through here would convert a free WhatsApp into a paid SMS during
    # exactly the runaway the limiter exists to stop.
    test "a rate-limited WhatsApp halts instead of falling through to paid SMS" do
      store = setup_store()

      supplier =
        Factory.create_supplier!(store, %{
          whatsapp_number: "+233200000013",
          contact_phone: "+233200000014"
        })

      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _template, _params, _opts -> {:error, :rate_limited} end)

      # No SMS expectation — verify_on_exit! proves we did not spend.
      assert {:error, :rate_limited} == perform(fulfillment.id)
      assert reload(fulfillment.id).status == :pending
    end
  end

  # ── Failure visibility ─────────────────────────────────────────

  describe "making a failed send visible to the merchant" do
    setup do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000020"})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})
      create_line_item!(order, store, fulfillment)

      %{fulfillment: fulfillment}
    end

    test "records a label on the fulfillment, not just in oban_jobs", %{fulfillment: f} do
      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _t, _p, _o -> {:error, %{status: 401, body: "nope"}} end)

      perform(f.id)

      reloaded = reload(f.id)
      assert reloaded.last_send_error =~ "whatsapp"
      assert reloaded.last_send_error =~ "401"
      assert %DateTime{} = reloaded.last_send_error_at
      assert reloaded.status == :pending
    end

    # The provider body can carry phone numbers and Meta account identifiers,
    # which is why the channel itself logs "provider response omitted".
    test "stores a label, never the provider response body", %{fulfillment: f} do
      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _t, _p, _o ->
        {:error, %{status: 400, body: "+233555000111 is not a WhatsApp user"}}
      end)

      perform(f.id)

      refute reload(f.id).last_send_error =~ "233555000111"
    end

    test "returns {:error, _} while Oban still has retries left", %{fulfillment: f} do
      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _t, _p, _o -> {:error, :timeout} end)

      assert {:error, _} = perform(f.id, attempt: 1, max_attempts: 3)

      # The failure is already written — the merchant sees it now, not after
      # the last backoff.
      assert reload(f.id).last_send_error
    end

    # Without this the terminal failure lands in oban_jobs, where no merchant
    # will ever look, and the fulfilment sits :pending forever with nobody told.
    test "returns :ok on the final attempt so the failure rests on the row", %{fulfillment: f} do
      Emakola.WhatsAppProviderMock
      |> expect(:send_message, fn _to, _t, _p, _o -> {:error, :timeout} end)

      assert :ok == perform(f.id, attempt: 3, max_attempts: 3)
      assert reload(f.id).last_send_error
    end

    test "a supplier with no contact at all is labelled, not silent", %{} do
      store = setup_store()
      supplier = Factory.create_supplier!(store, %{})
      order = create_order_with_address(store)
      fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})

      assert :ok == perform(fulfillment.id)

      reloaded = reload(fulfillment.id)
      assert reloaded.last_send_error == "no_contact"
      assert reloaded.status == :pending
    end
  end
end
