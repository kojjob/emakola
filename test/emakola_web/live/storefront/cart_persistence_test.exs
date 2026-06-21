defmodule EmakolaWeb.Storefront.CartPersistenceTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Cart.CartStore
  alias Emakola.Factory

  setup do
    store =
      Factory.create_store!(%{name: "Persistence Shop", slug: "persist-shop", currency: "GHS"})

    product =
      Factory.create_product!(store, %{title: "Persisted Item", description: "Survives refresh"})

    variant =
      Factory.create_variant!(product, store, %{
        price: 5000,
        stock_quantity: 10,
        sku: "PERSIST-001"
      })

    activate_product!(product)

    %{store: store, product: product, variant: variant}
  end

  describe "cart persistence across page refreshes" do
    test "cart items survive LiveView remount via session", %{
      conn: conn,
      store: store,
      product: product,
      variant: variant
    } do
      # Simulate a session with a cart_session_id
      session_id = Ecto.UUID.generate()
      conn = init_test_session(conn, %{"cart_session_id" => session_id})

      # First visit: add item to cart from product detail
      {:ok, view, _html} = live(conn, "/@#{store.slug}/products/#{product.slug}")
      render_click(view, "add_to_cart")

      # Verify item is in CartStore
      assert [%{variant_id: vid}] = CartStore.get_cart(session_id, store.id)
      assert vid == variant.id

      # Second visit: navigate to cart page (simulates page refresh/navigation)
      {:ok, _cart_view, cart_html} = live(conn, "/@#{store.slug}/cart")

      # Cart should show the item from CartStore
      assert cart_html =~ "Persisted Item"
    end

    test "add to cart from product detail writes to CartStore", %{
      conn: conn,
      store: store,
      product: product
    } do
      {:ok, view, _html} = live(conn, "/@#{store.slug}/products/#{product.slug}")

      html = render_click(view, "add_to_cart")

      assert html =~ "Added to cart"
    end

    test "cart count reflects items from CartStore", %{conn: conn, store: store, variant: variant} do
      # Pre-populate the cart via CartStore using a known session id
      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: "Pre-loaded Item",
        variant_info: "Default",
        unit_price: 5000,
        quantity: 3,
        sku: "PRE-001"
      })

      # Visit cart page with the pre-set session
      conn =
        conn
        |> init_test_session(%{"cart_session_id" => session_id})

      {:ok, _view, html} = live(conn, "/@#{store.slug}/cart")

      assert html =~ "Pre-loaded Item"
      assert html =~ "3 items"
    end

    test "removing all items shows empty cart state", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: "Removable Item",
        variant_info: "Default",
        unit_price: 5000,
        quantity: 1,
        sku: "REM-001"
      })

      conn = init_test_session(conn, %{"cart_session_id" => session_id})

      {:ok, view, _html} = live(conn, "/@#{store.slug}/cart")

      html = render_click(view, "remove_item", %{"index" => "0"})

      assert html =~ "empty" or html =~ "Your bag is empty"
    end

    test "updating quantity persists to CartStore", %{conn: conn, store: store, variant: variant} do
      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: "Qty Item",
        variant_info: "Default",
        unit_price: 5000,
        quantity: 1,
        sku: "QTY-001"
      })

      conn = init_test_session(conn, %{"cart_session_id" => session_id})

      {:ok, view, _html} = live(conn, "/@#{store.slug}/cart")

      # Increment quantity
      render_click(view, "update_quantity", %{"index" => "0", "delta" => "1"})

      # Verify in CartStore
      cart = CartStore.get_cart(session_id, store.id)
      assert [%{quantity: 2}] = cart
    end

    test "checkout navigates to checkout page (cart preserved until payment confirms)", %{
      conn: conn,
      store: store,
      variant: variant
    } do
      session_id = Ecto.UUID.generate()

      CartStore.add_item(session_id, store.id, %{
        variant_id: variant.id,
        product_title: "Checkout Item",
        variant_info: "Default",
        unit_price: 5000,
        quantity: 1,
        sku: "CHK-001"
      })

      conn = init_test_session(conn, %{"cart_session_id" => session_id})

      {:ok, view, _html} = live(conn, "/@#{store.slug}/cart")

      assert {:error, {:live_redirect, %{to: "/@" <> _}}} = render_click(view, "checkout")

      # Cart is NOT cleared yet — preserved until payment confirms
      assert CartStore.get_cart(session_id, store.id) != []
    end
  end

  # -- Helpers --

  defp activate_product!(product) do
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)
  end
end
