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

  defp perform(fulfillment_id) do
    SupplierNotificationWorker.perform(%Oban.Job{
      args: %{"fulfillment_id" => fulfillment_id}
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
end
