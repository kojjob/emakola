defmodule EmakolaWeb.Storefront.QuickAddTest do
  @moduledoc """
  A quick-add button on the product list must add to the cart, on every theme.

  Product cards are theme chrome: the same card component renders on the home
  page (StoreLive), the category page (CategoryLive) and the product list
  (ProductListLive). StoreLive and CategoryLive both handled `add_to_cart`.
  ProductListLive did not — so the very same button that worked on the home page
  raised FunctionClauseError on /products, killed the LiveView and reset the
  page. Four themes (pace, atelier, akwaaba, ntoma) render it there by default.

  The bug was already known: `fresh/product_list.ex` passes `add_to_cart={false}`
  with the comment "so a quick-add here would crash the live page." The defence
  was applied to one theme and never to the other four — which is exactly why
  this test asserts across every theme instead of the four we know about.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Cart.CartStore
  alias Emakola.Themes.ThemeResolver

  @themes ThemeResolver.theme_ids()

  defp seed(theme) do
    store = Emakola.Factory.create_store!(%{theme_config: %{"theme" => theme}})
    category = Emakola.Factory.create_category!(store, %{name: "Fruit"})

    product = Emakola.Factory.create_product!(store, %{title: "Mango", status: :active})
    Emakola.Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
    # Seeded so every theme renders its real gallery: a guard that runs
    # against an empty-state placeholder is a weaker guard.
    Emakola.Factory.create_image!(product, store)

    product
    |> Ash.Changeset.for_update(:update, %{category_id: category.id})
    |> Ash.update!(authorize?: false)

    %{store: store, product: product}
  end

  describe "the product list's quick-add button adds to the cart" do
    for theme <- @themes do
      @theme theme

      test "#{theme}", %{conn: conn} do
        %{store: store, product: product} = seed(@theme)

        {:ok, view, html} = live(conn, "/s/#{store.slug}/products")

        # A theme is free to offer no quick-add on the list (most link straight
        # to the product page). One that DOES offer it must make it work.
        if html =~ ~s(phx-click="add_to_cart") do
          assert has_element?(
                   view,
                   ~s([phx-click="add_to_cart"][phx-value-product-id="#{product.id}"])
                 ),
                 "the #{@theme} product list has a quick-add button that does not send product-id"

          # Would raise FunctionClauseError and kill the LiveView before the fix.
          render_click(view, "add_to_cart", %{"product-id" => product.id})

          cart_session_id = :sys.get_state(view.pid).socket.assigns.cart_session_id

          assert CartStore.cart_count(cart_session_id, store.id) == 1,
                 "the #{@theme} product list's quick-add button did not add anything to the cart"
        end
      end
    end
  end
end
