defmodule Emakola.Orders.CustomOrderRenderingTest do
  @moduledoc """
  Guard tests for TC-1 pay-link orders: a custom (variant-less) line item's
  display data lives entirely in its snapshot fields (product_title,
  variant_sku, unit_price, line_total). If the admin order show page or the
  order confirmation email ever start dereferencing `line_item.variant`
  instead, these tests crash loudly.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  alias EmakolaWeb.Helpers.Currency

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
end
