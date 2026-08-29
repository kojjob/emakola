defmodule EmakolaWeb.Storefront.TrackReachabilityTest do
  @moduledoc """
  /track/:order_number is routed, themed and tested — and the only thing that
  ever linked to it was an SMS. A buyer who deleted the message, or never got
  one because SMS is dummy-keyed, had no way back to it.

  Same orphaned-route shape as the admin digital-files page and the customer
  downloads page: reachable only by typing a URL nobody knows.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest

  defp order_for(store, customer) do
    product = create_product!(store)
    variant = create_variant!(product, store, price: 20_000, sku: "TRK-R", stock_quantity: 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 1}],
        customer_id: customer.id,
        shipping_address: %{"phone" => "+233240000012", "name" => "Ama"}
      )

    order
  end

  defp register_customer!(store) do
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "buyer-#{System.unique_integer([:positive])}@example.com",
      name: "Ama Buyer",
      phone: "+23324#{System.unique_integer([:positive])}",
      store_id: store.id,
      password: "password123",
      password_confirmation: "password123"
    })
    |> Ash.create!(authorize?: false)
  end

  defp log_in(conn, customer) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))
    Phoenix.ConnTest.init_test_session(conn, %{"customer_token" => token})
  end

  test "the order confirmation links the buyer to tracking", %{conn: conn} do
    store = create_store!()
    customer = register_customer!(store)
    order = order_for(store, customer)

    {:ok, _view, html} =
      live(conn, "/s/#{store.slug}/orders/#{order.order_number}/confirmation")

    assert html =~ "/s/#{store.slug}/track/#{order.order_number}"
  end

  test "the account orders tab links each order to tracking", %{conn: conn} do
    store = create_store!()
    customer = register_customer!(store)
    order = order_for(store, customer)

    {:ok, view, _html} = conn |> log_in(customer) |> live("/s/#{store.slug}/account")
    html = render_click(view, "switch_tab", %{"tab" => "orders"})

    assert html =~ "/s/#{store.slug}/track/#{order.order_number}"
  end
end
