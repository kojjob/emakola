defmodule EmakolaWeb.Storefront.SusuLinkLiveTest do
  @moduledoc """
  TC-3 Task 7: the buyer-facing `/susu/:code` page — both faces (public
  bare-code + signed "My susu" progress link) in one LiveView.

  Test-setup convention: plans are activated/completed by driving the REAL
  domain functions directly (`SusuChunks.initiate_chunk/4` +
  `Emakola.Payments.Gateways.Mock`, the hardcoded-success stub — NOT Mox),
  mirroring `susu_chunks_test.exs`'s own setup helpers. Only the actual
  action under test in each case exercises `Emakola.Payments.GatewayMock`
  (Mox) via the LiveView, matching `pay_link_live_test.exs`'s pattern.
  """

  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

  alias Emakola.Orders.SusuChunks
  alias Emakola.Orders.SusuCompletion
  alias Emakola.Orders.SusuPlan
  alias Emakola.Payments.Gateways.Mock
  alias Emakola.Payments.Payment
  alias EmakolaWeb.SusuTokens

  setup :verify_on_exit!

  defp future_deadline(days \\ 30), do: DateTime.add(DateTime.utc_now(), days, :day)

  defp create_plan!(store, attrs) do
    attrs = Map.new(attrs) |> Map.put_new(:deadline, future_deadline())

    SusuPlan
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  defp reload_plan(plan), do: Ash.get!(SusuPlan, plan.id, authorize?: false)

  defp mark_success!(payment) do
    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.update!(authorize?: false)
  end

  defp buyer_params, do: %{"name" => "Ama Mensah", "phone" => "0201234567"}

  # Activates a plan for real via the same path production uses (initiate +
  # confirm), so `customer_id`/`delivery_address` are genuine, not hand-set.
  defp activate!(plan, buyer \\ nil) do
    buyer = buyer || buyer_params()
    amount = min(5_000, plan.total_amount)

    {:ok, %{payment: payment}} = SusuChunks.initiate_chunk(plan, amount, buyer, Mock)
    payment |> mark_success!() |> SusuChunks.confirm_chunk()
    reload_plan(plan)
  end

  # Pays in two chunks (half, then the remainder) rather than one — a
  # single `activate!/1` chunk of `total_amount` would complete the plan
  # immediately in `activate!/1` itself for small totals, never exercising
  # the "already active, one more chunk completes it" path this helper
  # needs.
  defp complete!(plan) do
    first_amount = max(div(plan.total_amount, 2), 1)
    {:ok, %{payment: first}} = SusuChunks.initiate_chunk(plan, first_amount, buyer_params(), Mock)
    first |> mark_success!() |> SusuChunks.confirm_chunk()

    active = reload_plan(plan)
    remaining = SusuPlan.remaining(active)

    {:ok, %{payment: second}} = SusuChunks.initiate_chunk(active, remaining, %{}, Mock)
    second |> mark_success!() |> SusuChunks.confirm_chunk()

    completed = reload_plan(plan)
    {:ok, order} = SusuCompletion.complete(completed.id)
    {completed, order}
  end

  defp use_gateway_mock! do
    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)
  end

  defp signed_path(plan), do: "/susu/#{plan.code}?t=#{SusuTokens.sign_susu_plan(plan.id)}"

  # -- Store lifecycle --------------------------------------------------

  test "suspended store renders the unavailable message on the public face", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    store
    |> Ash.Changeset.for_update(:suspend, %{reason: "test"})
    |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/susu/#{plan.code}")
    assert html =~ "available right now"
    refute html =~ "phx-submit"
  end

  test "suspended store renders the unavailable message on the signed face too", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan)

    store
    |> Ash.Changeset.for_update(:suspend, %{reason: "test"})
    |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, signed_path(active))
    assert html =~ "available right now"
    refute html =~ "phx-submit"
  end

  test "unknown code 404s", %{conn: conn} do
    assert_raise Ash.Error.Query.NotFound, fn -> live(conn, "/susu/zzzzzzzz") end
  end

  # -- Catalog stock re-check -------------------------------------------

  test "catalog plan with an out-of-stock variant renders the sold-out message", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 0})

    plan =
      create_plan!(store, %{
        type: :catalog,
        variant_id: variant.id,
        quantity: 1,
        total_amount: 8_000
      })

    {:ok, _view, html} = live(conn, "/susu/#{plan.code}")
    assert html =~ "sold out"
    refute html =~ "phx-submit"
  end

  test "catalog plan whose stock drops below quantity between mount and submit re-checks and blocks",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 2})

    plan =
      create_plan!(store, %{
        type: :catalog,
        variant_id: variant.id,
        quantity: 2,
        total_amount: 16_000
      })

    {:ok, view, html} = live(conn, "/susu/#{plan.code}")
    assert html =~ "phx-submit"

    variant
    |> Ash.Changeset.for_update(:update, %{stock_quantity: 1})
    |> Ash.update!(authorize?: false)

    html =
      view
      |> form("#susu-start-form", %{
        "amount" => "160",
        "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
      })
      |> render_submit()

    assert html =~ "sold out"

    assert Payment
           |> Ash.Query.filter(susu_plan_id == ^plan.id)
           |> Ash.read!(authorize?: false) == []
  end

  # -- Pending public face: start form -----------------------------------

  test "renders a custom plan's summary, deadline, and progress on the public face", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    {:ok, _view, html} = live(conn, "/susu/#{plan.code}")

    assert html =~ store.name
    assert html =~ "Fridge"
    assert html =~ "150"
    assert html =~ "0% paid"
  end

  test "submitting the start form initiates a chunk via the gateway with no split, susu metadata",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    use_gateway_mock!()

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params.amount == 5_000
      refute Map.has_key?(params, :split)
      assert params.metadata == %{payment_method: "susu_chunk"}
      {:ok, %{reference: "PAY-susu-ref", authorization_url: "https://pay.test/susu"}}
    end)

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#susu-start-form", %{
      "amount" => "50",
      "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
    })
    |> render_submit()

    [payment] =
      Payment
      |> Ash.Query.filter(susu_plan_id == ^plan.id)
      |> Ash.read!(authorize?: false)

    assert payment.amount == 5_000
    assert payment.payout_hold_reason == "susu_plan"
  end

  test "start form amount below the minimum chunk renders a friendly error and creates no payment",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()

    plan =
      create_plan!(store, %{
        type: :custom,
        title: "Fridge",
        total_amount: 15_000,
        min_chunk: 5_000
      })

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

    html =
      view
      |> form("#susu-start-form", %{
        "amount" => "10",
        "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
      })
      |> render_submit()

    assert html =~ "minimum"

    assert Payment
           |> Ash.Query.filter(susu_plan_id == ^plan.id)
           |> Ash.read!(authorize?: false) == []
  end

  test "start form missing buyer name/phone renders a friendly error", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

    html =
      view
      |> form("#susu-start-form", %{"amount" => "50", "buyer" => %{"name" => "Ama"}})
      |> render_submit()

    assert html =~ "name and phone"
  end

  test "typing into the start form updates fields via the validate handler", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

    html =
      view
      |> form("#susu-start-form", %{"buyer" => %{"name" => "Kwame Asante"}})
      |> render_change()

    assert html =~ "Kwame Asante"
  end

  # -- Active public face: progress + resend -----------------------------

  test "active plan's public face shows progress and a resend form, not a chunk form", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan)

    {:ok, _view, html} = live(conn, "/susu/#{active.code}")

    assert html =~ "33% paid"
    assert html =~ "susu-resend-form"
    refute html =~ "susu-chunk-form"
    refute html =~ "Cancel this plan"
  end

  test "resend sends the signed link by SMS when the phone matches the one on file", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan, %{"name" => "Ama Mensah", "phone" => "0201234567"})

    expect(Emakola.SMSProviderMock, :send_sms, fn to, message, _opts ->
      assert to == "+233201234567"
      assert message =~ "/susu/#{active.code}"
      {:ok, %{}}
    end)

    {:ok, view, _html} = live(conn, "/susu/#{active.code}")
    Mox.allow(Emakola.SMSProviderMock, self(), view.pid)

    html =
      view
      |> form("#susu-resend-form", %{"phone" => "0201234567"})
      |> render_submit()

    assert html =~ "on file"
  end

  test "resend with a phone that doesn't match the one on file sends no SMS but claims success (no enumeration)",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan, %{"name" => "Ama Mensah", "phone" => "0201234567"})

    expect(Emakola.SMSProviderMock, :send_sms, 0, fn _to, _message, _opts -> {:ok, %{}} end)

    {:ok, view, _html} = live(conn, "/susu/#{active.code}")
    Mox.allow(Emakola.SMSProviderMock, self(), view.pid)

    html =
      view
      |> form("#susu-resend-form", %{"phone" => "0209999999"})
      |> render_submit()

    assert html =~ "on file"
  end

  # -- Signed face: next-chunk, delivery edit, cancel --------------------

  test "signed face renders progress, a next-chunk form (bounds shown), delivery edit, and a cancel button",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()

    plan =
      create_plan!(store, %{
        type: :custom,
        title: "Fridge",
        total_amount: 15_000,
        collect_delivery: true
      })

    active = activate!(plan)

    {:ok, _view, html} = live(conn, signed_path(active))

    assert html =~ "susu-chunk-form"
    assert html =~ "Cancel this plan"
    assert html =~ "Delivery details"
    refute html =~ "susu-resend-form"
  end

  test "submitting the signed next-chunk form initiates another chunk via the gateway", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan)
    use_gateway_mock!()

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params.amount == 3_000
      refute Map.has_key?(params, :split)
      {:ok, %{reference: "PAY-susu-2", authorization_url: "https://pay.test/susu2"}}
    end)

    {:ok, view, _html} = live(conn, signed_path(active))
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#susu-chunk-form", %{"amount" => "30"})
    |> render_submit()

    payments =
      Payment
      |> Ash.Query.filter(susu_plan_id == ^plan.id)
      |> Ash.read!(authorize?: false)

    assert length(payments) == 2
  end

  test "editing delivery details on the signed face updates the plan", %{conn: conn} do
    store = Emakola.Factory.create_store!()

    plan =
      create_plan!(store, %{
        type: :custom,
        title: "Fridge",
        total_amount: 15_000,
        collect_delivery: true
      })

    active = activate!(plan)

    {:ok, view, _html} = live(conn, signed_path(active))

    view
    |> form("#susu-delivery-form", %{
      "delivery" => %{
        "name" => "Ama Mensah",
        "phone" => "0201234567",
        "address" => "42 New Street"
      }
    })
    |> render_submit()

    updated = reload_plan(active)
    assert updated.delivery_address["address"] == "42 New Street"
  end

  test "cancelling on the signed face cancels the plan and shows the closed message", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan)

    {:ok, view, _html} = live(conn, signed_path(active))

    html =
      view
      |> element("button", "Cancel this plan")
      |> render_click()

    assert html =~ "cancelled"
    assert reload_plan(active).status == :cancelled
  end

  # -- Completed --------------------------------------------------------

  test "public face of a completed plan shows a closed message, no tracking link", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 5_000})
    {completed, _order} = complete!(plan)

    {:ok, _view, html} = live(conn, "/susu/#{completed.code}")

    assert html =~ "fully paid"
    refute html =~ "Track your order"
  end

  test "signed face of a completed plan links to the order's tracking page", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 5_000})
    {completed, order} = complete!(plan)

    {:ok, _view, html} = live(conn, signed_path(completed))

    assert html =~ "Track your order"
    assert html =~ "/s/#{store.slug}/track/#{order.order_number}"
  end

  # -- Terminal states (expired / cancelled) ------------------------------

  test "an expired plan renders the closed message on both faces", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
    active = activate!(plan)

    expired =
      active
      |> Ash.Changeset.for_update(:expire, %{})
      |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/susu/#{expired.code}")
    assert html =~ "expired"

    {:ok, _view, html} = live(conn, signed_path(expired))
    assert html =~ "expired"
  end

  # -- Threat suite: unsigned face cannot move money ----------------------

  describe "threat suite" do
    test "an unsigned active plan's page cannot chunk via a direct event push", %{conn: conn} do
      store = Emakola.Factory.create_store!()
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      active = activate!(plan)

      {:ok, view, _html} = live(conn, "/susu/#{active.code}")

      render_hook(view, "chunk", %{"amount" => "30"})

      payments =
        Payment
        |> Ash.Query.filter(susu_plan_id == ^plan.id)
        |> Ash.read!(authorize?: false)

      # Only the one payment created by `activate!/1` in setup — the direct
      # push created nothing.
      assert length(payments) == 1
    end

    test "an unsigned active plan's page cannot chunk via a direct 'start' event push either", %{
      conn: conn
    } do
      store = Emakola.Factory.create_store!()
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      active = activate!(plan)

      {:ok, view, _html} = live(conn, "/susu/#{active.code}")

      render_hook(view, "start", %{
        "amount" => "30",
        "buyer" => %{"name" => "Eve", "phone" => "0200000000"}
      })

      payments =
        Payment
        |> Ash.Query.filter(susu_plan_id == ^plan.id)
        |> Ash.read!(authorize?: false)

      assert length(payments) == 1
    end

    test "an unsigned active plan's page cannot cancel via a direct event push", %{conn: conn} do
      store = Emakola.Factory.create_store!()
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      active = activate!(plan)

      {:ok, view, _html} = live(conn, "/susu/#{active.code}")

      render_hook(view, "cancel_plan", %{})

      assert reload_plan(active).status == :active
    end

    test "an unsigned active plan's page cannot edit delivery via a direct event push", %{
      conn: conn
    } do
      store = Emakola.Factory.create_store!()

      plan =
        create_plan!(store, %{
          type: :custom,
          title: "Fridge",
          total_amount: 15_000,
          collect_delivery: true
        })

      active = activate!(plan)
      original_address = active.delivery_address

      {:ok, view, _html} = live(conn, "/susu/#{active.code}")

      render_hook(view, "update_delivery", %{
        "delivery" => %{"name" => "Eve", "phone" => "0200000000", "address" => "Nowhere"}
      })

      assert reload_plan(active).delivery_address == original_address
    end

    test "a stale pending-mounted socket cannot tokenlessly start-chunk a plan activated via another path",
         %{conn: conn} do
      store = Emakola.Factory.create_store!()
      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

      # Mounts while the plan is still :pending — the socket's @state and
      # @plan assigns are captured here and never refreshed until an event
      # fires.
      {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

      # Activated via a DIFFERENT path — a concurrent buyer on another
      # tab/device paying the first chunk for real. This socket's
      # mount-time state (:pending) is now stale.
      activate!(plan)

      render_hook(view, "start", %{
        "amount" => "30",
        "buyer" => %{"name" => "Eve", "phone" => "0200000000"}
      })

      payments =
        Payment
        |> Ash.Query.filter(susu_plan_id == ^plan.id)
        |> Ash.read!(authorize?: false)

      # Only the ONE payment `activate!/1` created for real — the stale
      # "start" push moved no money.
      assert length(payments) == 1
      assert reload_plan(plan).status == :active

      # Friendly refresh, not a raw error: the socket re-computed to the
      # plan's real (now active, unsigned) state instead of staying stuck
      # on the pending start form.
      html = render(view)
      refute html =~ "susu-start-form"
      assert html =~ "susu-resend-form"
    end

    test "a valid signed token for a DIFFERENT plan is unauthorized on this plan's code", %{
      conn: conn
    } do
      store = Emakola.Factory.create_store!()

      other_plan =
        create_plan!(store, %{type: :custom, title: "Other", total_amount: 15_000})
        |> activate!()

      plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})
      active = activate!(plan)

      wrong_token = SusuTokens.sign_susu_plan(other_plan.id)
      {:ok, view, html} = live(conn, "/susu/#{active.code}?t=#{wrong_token}")

      # Renders the PUBLIC face (resend form), not the signed face.
      assert html =~ "susu-resend-form"
      refute html =~ "susu-chunk-form"

      render_hook(view, "chunk", %{"amount" => "30"})
      render_hook(view, "cancel_plan", %{})

      assert reload_plan(active).status == :active

      payments =
        Payment
        |> Ash.Query.filter(susu_plan_id == ^plan.id)
        |> Ash.read!(authorize?: false)

      assert length(payments) == 1
    end
  end

  # -- search_overlay (TC-1 Critical) -------------------------------------

  test "search overlay keyup on the susu page doesn't crash the socket", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Kente dress", total_amount: 15_000})

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

    html =
      view
      |> element("#search-input")
      |> render_keyup(%{"value" => "kente"})

    # The socket survived and re-rendered the page (not just the overlay).
    assert html =~ "Kente dress"
  end

  test "closing the search overlay on the susu page doesn't crash the socket", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    plan = create_plan!(store, %{type: :custom, title: "Fridge", total_amount: 15_000})

    {:ok, view, _html} = live(conn, "/susu/#{plan.code}")

    html =
      view
      |> element("button[aria-label='Close search']")
      |> render_click()

    assert html =~ "Fridge"
  end
end
