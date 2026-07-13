defmodule EmakolaWeb.Storefront.NoInventedPolicyCopyTest do
  @moduledoc """
  No theme may hardcode a delivery, returns or warranty promise the merchant
  never made.

  A store that has configured no delivery zones has promised nothing, so the
  storefront must promise nothing on its behalf — not "Free delivery on orders
  over GHS 500", not "Same-Day Delivery in Accra", not "30-day returns", not
  "1-year warranty". A merchant could not edit or disavow these: they were
  template literals, and two themes stated different numbers for the same
  store.

  Where the merchant HAS configured zones, the storefront says what those
  zones actually say — see the second half of this file. Delivery truth comes
  from `Emakola.Shipping.DeliveryZone`, which is also what the checkout
  already charges from.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  @all_themes ~w(atelier beauty bold electronics fashion fresh
                 home_living market pharmacy spotlight starter vibrant)

  # Promises a store with no configured zones cannot possibly have made.
  # "Delivery across Ghana" and "See this store's policies" are deliberately
  # NOT here: vague-but-true, and the merchant's own policies page is
  # authoritative.
  @invented_promise ~r/
      \d+\s*(?:-|–|to)?\s*\d*\s*business\s+days
    | \d+\s*[-–\s]\s*day\s+(?:returns?|window|warranty|guarantee|exchange)
    | \d+\s*[-–\s]\s*year\s+warranty
    | returns?\s+(?:accepted\s+)?within\s+\d+
    | free\s+(?:delivery|shipping)
    | same[-\s]?day\s+delivery
    | delivered\s+same\s+day
    | reply\s+within
    | money[-\s]?back
    | quality\s+guaranteed
  /ix

  defp seed(theme) do
    store = Factory.create_store!(%{theme_config: %{"theme" => theme}})
    product = Factory.create_product!(store, %{status: :active})
    Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
    {store, product}
  end

  describe "a store that configured no delivery zones promises nothing" do
    for theme <- @all_themes do
      @theme theme

      test "#{theme} home page", %{conn: conn} do
        {store, _product} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}")

        refute html =~ @invented_promise,
               "the #{@theme} home page states a delivery/returns promise this store never made"
      end

      test "#{theme} PDP", %{conn: conn} do
        {store, product} = seed(@theme)

        {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

        refute html =~ @invented_promise,
               "the #{@theme} PDP states a delivery/returns promise this store never made"
      end
    end
  end

  describe "checkout" do
    setup %{conn: conn} do
      {store, product} = seed("market")
      variant = Ash.load!(product, :variants, authorize?: false).variants |> List.first()

      session_id = Ecto.UUID.generate()
      conn = init_test_session(conn, %{"cart_session_id" => session_id})

      Emakola.Cart.CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: product.title,
        variant_info: "",
        unit_price: variant.price,
        sku: variant.sku,
        quantity: 1
      })

      %{conn: conn, store: store}
    end

    # The checkout charged a fee from the merchant's own delivery zone while
    # printing a timeline keyed off the region alone — "1-2 business days" for
    # Greater Accra. The price was the merchant's; the promise beside it was the
    # platform's, and no merchant could change it.
    test "states the delivery estimate the merchant's own zone actually gives", ctx do
      Factory.create_delivery_zone!(ctx.store, %{
        name: "Greater Accra",
        fee: 1500,
        estimated_days: 1
      })

      {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/checkout")

      assert html =~ "Next day"
      refute html =~ @invented_promise
    end

    test "a store with no zone for the region promises no timeline at all", ctx do
      {:ok, _view, html} = live(ctx.conn, "/s/#{ctx.store.slug}/checkout")

      assert html =~ "The seller will confirm your delivery time"
      refute html =~ @invented_promise
    end
  end

  describe "a store that configured zones says what its zones say" do
    test "the home page names the real zones and the real free-delivery threshold", %{conn: conn} do
      {store, _product} = seed("vibrant")

      Factory.create_delivery_zone!(store, %{
        name: "Accra",
        fee: 1500,
        estimated_days: 1,
        free_above_pesewas: 20_000
      })

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      # The merchant's own numbers — GH₵200 is 20_000 pesewas.
      assert html =~ "Accra"
      assert html =~ "GH₵ 200"
    end

    test "a same-day zone is the only way 'same day' reaches the page", %{conn: conn} do
      {store, _product} = seed("fresh")

      Factory.create_delivery_zone!(store, %{name: "Accra", fee: 1000, estimated_days: 0})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Same day"
      assert html =~ "Accra"
    end
  end
end
