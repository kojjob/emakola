defmodule Emakola.Orders.CustomOrderRenderingTest do
  @moduledoc """
  Guard tests for TC-1 pay-link orders: a custom (variant-less) line item's
  display data lives entirely in its snapshot fields (product_title,
  variant_sku, unit_price, line_total). If the admin order show page or the
  order confirmation email ever start dereferencing `line_item.variant`
  instead, these tests crash loudly.

  TC-3 extends the same guard to a susu-completed order: `create_susu_line!`
  (custom plans, `Emakola.Orders.CheckoutService`) writes the exact same
  snapshot fields via the exact same `:create_custom` LineItem action as
  `checkout_custom!/3` — so a susu order's custom line is byte-identical, at
  the rendering layer, to a pay-link custom order's.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  alias EmakolaWeb.Helpers.Currency

  # Builds a fully `:completed` custom susu plan with one contribution
  # covering the whole total, then runs it through the real
  # `SusuCompletion.complete/1` — same path `SusuCompletionWorker` drives in
  # production — to get back a real, confirmed order with a custom
  # (variant-less) line item.
  defp create_completed_custom_susu_order!(store) do
    customer = Emakola.Factory.create_customer!(store)

    plan =
      Emakola.Orders.SusuPlan
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        type: :custom,
        title: "Custom susu kente cloth",
        total_amount: 12_000,
        deadline: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      |> Ash.create!(authorize?: false)

    plan =
      plan
      |> Ash.Changeset.for_update(:activate, %{
        customer_id: customer.id,
        delivery_address: %{
          "name" => "Ama Mensah",
          "phone" => "0201234567",
          "address" => "12 High St, Accra"
        }
      })
      |> Ash.update!(authorize?: false)

    payment =
      Emakola.Factory.create_payment!(store, %{
        susu_plan_id: plan.id,
        amount: 12_000,
        payout_held: true,
        payout_hold_reason: "susu_plan",
        metadata: %{"susu_counted" => true}
      })

    payment
    |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
    |> Ash.update!(authorize?: false)

    plan =
      plan
      |> Ash.Changeset.for_update(:record_contribution, %{amount_delta: 12_000})
      |> Ash.update!(authorize?: false)

    plan
    |> Ash.Changeset.for_update(:complete, %{})
    |> Ash.update!(authorize?: false)

    {:ok, order} = Emakola.Orders.SusuCompletion.complete(plan.id)
    order
  end

  test "admin order show renders a custom order from snapshots", %{conn: conn} do
    {conn, _user, store} = setup_authenticated_merchant(conn)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Custom kente dress", unit_price: 25_000},
        customer_name: "Ama",
        customer_phone: "0201234567"
      )

    {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

    assert html =~ "Custom kente dress"
    assert html =~ Currency.format_price(order.total, order.currency)
  end

  test "order confirmation email builds for a custom order without raising" do
    store = Emakola.Factory.create_store!()

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Custom kente dress", unit_price: 25_000},
        customer_name: "Ama",
        customer_phone: "0201234567"
      )

    order = Ash.load!(order, [:line_items], authorize?: false, tenant: store.id)

    customer =
      Ash.get!(Emakola.Customers.Customer, order.customer_id, authorize?: false, tenant: store.id)

    email = Emakola.Notifications.Emails.OrderEmail.order_confirmation(order, customer, store)

    assert %Swoosh.Email{} = email
    assert email.html_body =~ "Custom kente dress"
    assert email.text_body =~ "Custom kente dress"
  end

  test "admin order show renders a susu-completed custom order from snapshots", %{conn: conn} do
    {conn, _user, store} = setup_authenticated_merchant(conn)

    order = create_completed_custom_susu_order!(store)

    {:ok, _view, html} = live(conn, ~p"/admin/orders/#{order.id}")

    assert html =~ "Custom susu kente cloth"
    assert html =~ Currency.format_price(order.total, order.currency)
  end

  test "order confirmation email builds for a susu-completed order without raising" do
    store = Emakola.Factory.create_store!()

    order = create_completed_custom_susu_order!(store)
    order = Ash.load!(order, [:line_items], authorize?: false, tenant: store.id)

    customer =
      Ash.get!(Emakola.Customers.Customer, order.customer_id, authorize?: false, tenant: store.id)

    email = Emakola.Notifications.Emails.OrderEmail.order_confirmation(order, customer, store)

    assert %Swoosh.Email{} = email
    assert email.html_body =~ "Custom susu kente cloth"
    assert email.text_body =~ "Custom susu kente cloth"
  end

  test "storefront order confirmation page renders a susu-completed order from snapshots", %{
    conn: conn
  } do
    store = Emakola.Factory.create_store!()

    order = create_completed_custom_susu_order!(store)

    {:ok, _view, html} =
      live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

    assert html =~ order.order_number
    assert html =~ "Custom susu kente cloth"
  end
end
