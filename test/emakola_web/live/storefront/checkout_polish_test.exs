defmodule EmakolaWeb.Storefront.CheckoutPolishTest do
  @moduledoc """
  Platform-wide checkout chrome fixes from the 2026-08-16 theme audit.

  Checkout is a shared DefaultRenderer, so every store's first checkout
  screen carried the same three defects: the absolutely-centered wordmark
  wrapped into the "Back to Bag" link on mobile, the Telecel Cash tile
  still wore a "VODA" logo, and AirtelTigo Money — advertised in "We
  accept" strips across the themes — was missing at the moment of payment.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Cart.CartStore

  setup do
    # A long store name — exactly the case that wrapped into "Back to Bag".
    store =
      create_store!(%{
        name: "Adwoa's Wonderful Fabrics and Provisions",
        currency: "GHS"
      })

    product = create_product!(store, %{title: "Test Shirt"})
    variant = create_variant!(product, store, %{price: 5000, stock_quantity: 20, sku: "TS-01"})

    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)

    %{store: store, variant: variant}
  end

  defp setup_cart_session(conn, variant) do
    session_id = Ecto.UUID.generate()

    CartStore.add_item(session_id, variant.store_id, %{
      variant_id: variant.id,
      product_title: "Test Shirt",
      variant_info: "TS-01",
      unit_price: 5000,
      quantity: 1,
      sku: "TS-01"
    })

    init_test_session(conn, %{"cart_session_id" => session_id})
  end

  test "the centered wordmark is bounded so it cannot wrap into Back to Bag", %{
    conn: conn,
    store: store,
    variant: variant
  } do
    conn = setup_cart_session(conn, variant)
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

    doc = LazyHTML.from_document(html)
    wordmark = LazyHTML.query(doc, "header span.truncate")

    assert Enum.any?(wordmark),
           "the checkout header wordmark must truncate — unbounded absolute text " <>
             "wraps to two lines on mobile and collides with the Back to Bag link"

    assert LazyHTML.text(wordmark) =~ "ADWOA"
  end

  test "the Telecel Cash tile no longer wears the VODA logo", %{
    conn: conn,
    store: store,
    variant: variant
  } do
    conn = setup_cart_session(conn, variant)
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/checkout")

    refute html =~ ">VODA<"
    assert html =~ "Telecel Cash"
  end

  test "AirtelTigo Money is offered and selectable at payment", %{
    conn: conn,
    store: store,
    variant: variant
  } do
    conn = setup_cart_session(conn, variant)
    {:ok, view, html} = live(conn, "/s/#{store.slug}/checkout")

    assert html =~ "AirtelTigo",
           "AirtelTigo Money is advertised in the themes' We-accept strips but " <>
             "missing as a payment option at checkout"

    assert has_element?(view, ~s(button[phx-value-method="airteltigo"]))

    render_click(view, "select_payment", %{"method" => "airteltigo"})

    assert has_element?(view, ~s(button[phx-value-method="airteltigo"] svg)),
           "selecting the AirtelTigo tile must mark it selected"
  end

  test "placing an order with AirtelTigo initiates payment instead of erroring", %{
    conn: conn,
    store: store,
    variant: variant
  } do
    conn = setup_cart_session(conn, variant)
    {:ok, view, _html} = live(conn, "/s/#{store.slug}/checkout")

    render_click(view, "select_payment", %{"method" => "airteltigo"})

    html =
      render_submit(view, "place_order", %{
        "phone" => "271234567",
        "fullname" => "Ama Mensah",
        "address" => "House 14, Osu",
        "region" => "greater_accra",
        "notes" => ""
      })

    refute html =~ "Unknown payment method"
  end
end
