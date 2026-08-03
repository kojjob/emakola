defmodule EmakolaWeb.Storefront.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  require Ash.Query

  setup :verify_on_exit!

  defp custom_link!(store, attrs \\ %{}) do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{store_id: store.id, type: :custom, title: "Kente dress", amount: 25_000}, attrs)
    )
    |> Ash.create!(authorize?: false)
  end

  defp catalog_link!(store, variant, attrs \\ %{}) do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{store_id: store.id, type: :catalog, variant_id: variant.id}, attrs)
    )
    |> Ash.create!(authorize?: false)
  end

  test "renders a custom link with store name, title, amount and buyer form", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ store.name
    assert html =~ "Kente dress"
    assert html =~ "250"
    assert html =~ "phone"
  end

  test "connected mount increments opened_count exactly once", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, _view, _html} = live(conn, "/pay/#{link.code}")

    reloaded = Ash.get!(Emakola.Orders.PayLink, link.id, authorize?: false, tenant: store.id)
    assert reloaded.opened_count == 1
  end

  test "expired link renders the inactive message, not a form", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "no longer active"
    refute html =~ "phx-submit"
  end

  test "cancelled and consumed links render the inactive message", %{conn: conn} do
    store = Emakola.Factory.create_store!()

    for status <- [:cancelled, :paid] do
      link = custom_link!(store)

      link
      |> Ash.Changeset.for_update(if(status == :paid, do: :mark_paid, else: :cancel), %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/pay/#{link.code}")
      assert html =~ "no longer active"
    end
  end

  test "suspended store renders the unavailable message, not a form", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    store
    |> Ash.Changeset.for_update(:suspend, %{reason: "test"})
    |> Ash.update!(authorize?: false)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")
    # Note: no apostrophe in the asserted substring — HEEx HTML-escapes "isn't"
    # to "isn&#39;t", so a literal apostrophe match would fail here.
    assert html =~ "available right now"
    refute html =~ "phx-submit"
  end

  # Verify-first finding: there is no `EmakolaWeb.NotFoundError` module in this
  # codebase. `get_pay_link_by_code/2` is a `get?: true` code interface, which
  # (per Ash.Resource.Interface's `not_found_error?: true` default) returns
  # `{:error, %Ash.Error.Query.NotFound{}}` rather than raising — the LiveView
  # re-raises that struct directly (mirrors how a controller 404 would surface
  # in this app; there's no bespoke web-layer 404 exception to reuse).
  test "unknown code 404s", %{conn: conn} do
    assert_raise Ash.Error.Query.NotFound, fn -> live(conn, "/pay/zzzzzzzz") end
  end

  test "delivery address field is present when collect_delivery is true", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")
    assert html =~ "pay-link-address"
  end

  test "delivery address field is absent when collect_delivery is false", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: false})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")
    refute html =~ "pay-link-address"
  end

  test "submitting the form creates the order and initiates payment", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    # Verify-first finding: config/test.exs points :payment_gateway at
    # Emakola.Payments.Gateways.Mock (a hardcoded-success stub, NOT routed
    # through Mox) by default — checkout_live_test.exs never overrides it.
    # Emakola.Payments.GatewayMock is the real Mox mock (defined in
    # test_helper.exs), so this test must swap the config to point at it, the
    # same way test/emakola/payments/workers/payout_worker_test.exs does.
    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params.amount == 25_000
      # No method picker on this page (unlike CheckoutLive) — the gateway
      # must not be restricted to a single channel, or MoMo (the primary
      # rail for this market) would be hidden from the hosted page.
      refute Map.has_key?(params, :channel)
      {:ok, %{reference: "PAY-test-ref", authorization_url: "https://pay.test/x"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    # The LiveView process (not the test process) calls the gateway — allow it
    # to use this test's Mox expectations (same pattern as
    # test/emakola_web/live/admin/product_live_test.exs).
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.total == 25_000
  end

  test "a protected: true link creates a payment with no split and a payout hold flagged", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{protected: true})

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-protected-ref", authorization_url: "https://pay.test/protected"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    payment =
      Emakola.Payments.Payment
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, tenant: store.id)
      |> List.first()

    assert payment.split_mode == :none
    assert payment.payout_held == true
    assert payment.payout_hold_reason == "buyer_protection"
  end

  # -- Internal rail settlement (Phase 3 Task 5) --
  #
  # Mirrors checkout_live_test.exs's "internal rail settlement" test: an
  # unverified store (the module's stores here never call verified_payout!)
  # hits OrderSettlement.prepare/2's :internal fallback, and PayLinkLive's
  # initiate_payment/3 (identical maybe_attach_split/2 + split_mode/1 helpers,
  # copied verbatim from CheckoutLive per that module's own comment) carries
  # it through with zero code changes.
  test "unverified store's pay-link charge lands entirely on the internal rail", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params[:split] in [nil, []]
      {:ok, %{reference: "PAY-internal-ref", authorization_url: "https://pay.test/internal"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    payment =
      Emakola.Payments.Payment
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, tenant: store.id)
      |> List.first()

    assert payment.split_mode == :internal

    {:ok, splits} =
      Emakola.Payments.PaymentSplit
      |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
      |> Ash.read(authorize?: false)

    assert splits != [], "Expected internal-rail allocations to be recorded"
    assert Enum.all?(splits, &(&1.settlement_method == :internal_hold))

    sum_splits = Enum.sum(Enum.map(splits, & &1.amount))
    assert sum_splits == order.total
  end

  test "invalid phone renders a friendly error and creates no order", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> form("#pay-link-form", %{
        "buyer" => %{"name" => "Ama Mensah", "phone" => "abc"}
      })
      |> render_submit()

    assert html =~ "Enter a valid phone number"

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert orders == []
  end

  # "0201234567" (local, 10 digits) is already covered by "submitting the form
  # creates the order and initiates payment" above.
  test "E.164-formatted phone with spaces initiates payment", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-e164-ref", authorization_url: "https://pay.test/e164"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Ama Mensah", "phone" => "+233 20 123 4567"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.total == 25_000
  end

  # Regression guard: PhoneAuth.normalize/1 pads any digit string with no
  # leading 0/233/234 with a "+233" prefix, so a short garbage number can
  # normalize to >= 9 digits and slip past a naive post-normalization count
  # check. Validating raw digit shape (before normalization) closes that gap.
  test "a short numeric string that would normalize to 9+ digits via +233 padding is rejected",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> form("#pay-link-form", %{"buyer" => %{"name" => "Ama Mensah", "phone" => "555555"}})
      |> render_submit()

    assert html =~ "Enter a valid phone number"

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert orders == []
  end

  test "a local phone one digit short of a valid number is rejected", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> form("#pay-link-form", %{"buyer" => %{"name" => "Ama Mensah", "phone" => "020123456"}})
      |> render_submit()

    assert html =~ "Enter a valid phone number"

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert orders == []
  end

  # -- GhanaPost digital address + landmark (TC-4 Task 2) --

  test "valid messy digital address normalizes and lands on the order with the landmark", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-addr-ref", authorization_url: "https://pay.test/addr"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{
        "name" => "Ama Mensah",
        "phone" => "0201234567",
        "address" => "House 14, Osu",
        "digital_address" => "ga 183 8164",
        "landmark" => "behind Achimota Melcom"
      }
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.shipping_address["digital_address"] == "GA-183-8164"
    assert order.shipping_address["landmark"] == "behind Achimota Melcom"
  end

  test "blank digital address and landmark are omitted from the order's shipping_address", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-blank-ref", authorization_url: "https://pay.test/blank"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{
        "name" => "Ama Mensah",
        "phone" => "0201234567",
        "address" => "House 14, Osu"
      }
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    refute Map.has_key?(order.shipping_address, "digital_address")
    refute Map.has_key?(order.shipping_address, "landmark")
  end

  test "invalid digital address shows a friendly error and creates no order", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> form("#pay-link-form", %{
        "buyer" => %{
          "name" => "Ama Mensah",
          "phone" => "0201234567",
          "address" => "House 14, Osu",
          "digital_address" => "not-a-code"
        }
      })
      |> render_submit()

    assert html =~ "Check the digital address — it looks like GA-183-8164"

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert orders == []
  end

  test "digital address and landmark fields render when collect_delivery is true", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ ~s(name="buyer[digital_address]")
    assert html =~ ~s(name="buyer[landmark]")
  end

  test "digital address and landmark fields are absent when collect_delivery is false", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: false})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    refute html =~ ~s(name="buyer[digital_address]")
    refute html =~ ~s(name="buyer[landmark]")
  end

  test "a landmark over 200 chars is truncated (never rejected) on the order", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: true})

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-longmark-ref", authorization_url: "https://pay.test/longmark"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    long_landmark = String.duplicate("a", 250)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{
        "name" => "Ama Mensah",
        "phone" => "0201234567",
        "address" => "House 14, Osu",
        "landmark" => long_landmark
      }
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.shipping_address["landmark"] == String.duplicate("a", 200)
  end

  # -- Default-address reuse carries GhanaPost fields (TC-4 final fix wave) --
  # `collect_delivery: false` never collects an address on the buyer form, so
  # checkout_custom! falls back to the customer's saved default Address (same
  # phone -> same placeholder-email customer). That fallback must carry
  # digital_address/landmark exactly like the buyer-entered flows do.

  test "collect_delivery: false reuses the customer's saved default address, including digital_address and landmark",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: false})

    phone = "0201234567"
    email = Emakola.Orders.CheckoutService.phone_placeholder_email(phone)
    customer = Emakola.Factory.create_customer!(store, email: email, name: "Ama Mensah")

    addr =
      Emakola.Factory.create_address!(customer, store,
        line_1: "12 Oxford Street",
        city: "Accra",
        digital_address: "ga 183 8164",
        landmark: "behind Achimota Melcom"
      )

    Emakola.Customers.Address
    |> Ash.ActionInput.for_action(:set_as_default, %{address_id: addr.id})
    |> Ash.run_action!()

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-reuse-ref", authorization_url: "https://pay.test/reuse"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{"buyer" => %{"name" => "Ama Mensah", "phone" => phone}})
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.shipping_address["digital_address"] == "GA-183-8164"
    assert order.shipping_address["landmark"] == "behind Achimota Melcom"
  end

  test "collect_delivery: false with a default address lacking GhanaPost fields omits the keys (legacy shape)",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: false})

    phone = "0209999999"
    email = Emakola.Orders.CheckoutService.phone_placeholder_email(phone)
    customer = Emakola.Factory.create_customer!(store, email: email, name: "Kofi Owusu")

    addr = Emakola.Factory.create_address!(customer, store, line_1: "1 High St", city: "Kumasi")

    Emakola.Customers.Address
    |> Ash.ActionInput.for_action(:set_as_default, %{address_id: addr.id})
    |> Ash.run_action!()

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn _params ->
      {:ok, %{reference: "PAY-legacy-ref", authorization_url: "https://pay.test/legacy"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{"buyer" => %{"name" => "Kofi Owusu", "phone" => phone}})
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    refute Map.has_key?(order.shipping_address, "digital_address")
    refute Map.has_key?(order.shipping_address, "landmark")
  end

  test "typing into the buyer form updates the field via the validate handler", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> form("#pay-link-form", %{"buyer" => %{"name" => "Kwame Asante"}})
      |> render_change()

    assert html =~ "Kwame Asante"
  end

  test "renders a catalog link with product card and quantity select", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 5})
    link = catalog_link!(store, variant)

    {:ok, view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "Woven Basket"
    assert html =~ "80"
    assert html =~ "pay-link-quantity"

    html =
      view
      |> element("#pay-link-quantity")
      |> render_change(%{"quantity" => "3"})

    assert html =~ ~s(value="3" selected)
  end

  test "catalog link with an out-of-stock variant renders the sold-out message", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 0})
    link = catalog_link!(store, variant)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "sold out"
    refute html =~ "phx-submit"
  end

  test "catalog link whose variant no longer exists renders sold-out, not a bare form", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 5})
    link = catalog_link!(store, variant)

    Ash.destroy!(variant, authorize?: false)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "sold out"
    refute html =~ "phx-submit"
    refute html =~ "Pay GH"
  end

  test "submitting a catalog link's form creates the order with pay_link_id and initiates payment",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 5})
    link = catalog_link!(store, variant)

    original = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, Emakola.Payments.GatewayMock)
    on_exit(fn -> Application.put_env(:emakola, :payment_gateway, original) end)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params.amount == 8_000
      refute Map.has_key?(params, :channel)
      {:ok, %{reference: "PAY-catalog-ref", authorization_url: "https://pay.test/catalog"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")
    Mox.allow(Emakola.Payments.GatewayMock, self(), view.pid)

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Kojo Buyer", "phone" => "0244000000"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.pay_link_id == link.id
    assert order.total == 8_000
  end

  test "cancelling the link after mount still blocks payment on submit", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    link
    |> Ash.Changeset.for_update(:cancel, %{})
    |> Ash.update!(authorize?: false)

    html =
      view
      |> form("#pay-link-form", %{
        "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
      })
      |> render_submit()

    assert html =~ "no longer active"
    refute html =~ "phx-submit"

    orders =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert orders == []
  end

  test "catalog link with a quantity of 2 preselects it and shows the ×2 amount, matching the admin quote",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Woven Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 5})
    link = catalog_link!(store, variant, %{quantity: 2})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ ~s(value="2" selected)
    assert html =~ EmakolaWeb.Helpers.Currency.format_price(8_000 * 2, "GHS")
  end

  # -- Buyer protection badge (TC-2 Task 11) --

  test "shows the protection badge for a protected pay link", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{protected: true})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "Protected by Makola"
  end

  test "hides the protection badge for a default (unprotected) pay link", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    refute html =~ "Protected by Makola"
  end

  test "hides the protection badge when the link opts out even though store protection is on",
       %{conn: conn} do
    store = Emakola.Factory.create_store!()

    store
    |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
    |> Ash.update!(authorize?: false)

    link = custom_link!(store, %{protected: false})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    refute html =~ "Protected by Makola"
  end

  test "hides the protection badge for a catalog link pointing at a dropship variant", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()

    store
    |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
    |> Ash.update!(authorize?: false)

    wholesaler = Emakola.Factory.create_store!()
    supplier = Emakola.Factory.create_supplier!(store, linked_store_id: wholesaler.id)
    product = Emakola.Factory.create_product!(store, %{title: "Dropship Basket"})

    variant =
      Emakola.Factory.create_variant!(product, store, %{
        price: 8_000,
        stock_quantity: 5,
        supplier_id: supplier.id
      })

    link = catalog_link!(store, variant, %{protected: true})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    refute html =~ "Protected by Makola"
  end

  test "shows the protection badge for a catalog link pointing at an own-stock variant", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store, %{title: "Own Stock Basket"})
    variant = Emakola.Factory.create_variant!(product, store, %{price: 8_000, stock_quantity: 5})
    link = catalog_link!(store, variant, %{protected: true})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "Protected by Makola"
  end

  test "search overlay keyup on the pay page doesn't crash the socket", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> element("#search-input")
      |> render_keyup(%{"value" => "kente"})

    # The socket survived and re-rendered the page (not just the overlay).
    assert html =~ "Kente dress"
  end

  test "closing the search overlay on the pay page doesn't crash the socket", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    html =
      view
      |> element("button[aria-label='Close search']")
      |> render_click()

    assert html =~ "Kente dress"
  end
end
