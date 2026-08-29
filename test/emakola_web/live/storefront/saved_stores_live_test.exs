defmodule EmakolaWeb.Storefront.SavedStoresLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /s/:slug/saved-stores" do
    test "redirects to login when not authenticated", %{conn: conn} do
      store = Factory.create_store!(%{name: "Host Store", slug: "host-store"})

      assert {:error, {:redirect, %{to: redirect_to}}} =
               live(conn, "/s/#{store.slug}/saved-stores")

      assert redirect_to =~ "/login"
    end
  end

  describe "GET /s/:slug/saved-stores (authenticated)" do
    setup %{conn: conn} do
      host = Factory.create_store!(%{name: "Host Store", slug: "host-store"})
      {customer, conn} = sign_in_customer(conn, host)
      %{conn: conn, customer: customer, host: host}
    end

    test "shows empty state when customer has no favorites", %{conn: conn, host: host} do
      {:ok, view, _html} = live(conn, "/s/#{host.slug}/saved-stores")

      assert has_element?(view, "#saved-stores[phx-update='stream'][data-count='0']")
      assert has_element?(view, "#saved-stores-empty")
      assert has_element?(view, "#saved-stores-count")
    end

    test "lists favorited stores", %{conn: conn, customer: customer, host: host} do
      shop = Factory.create_store!(%{name: "Cool Shop", slug: "cool-shop"})

      {:ok, favorite} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: shop.id},
          actor: customer
        )

      {:ok, view, _html} = live(conn, "/s/#{host.slug}/saved-stores")

      assert has_element?(view, "#saved-stores[data-count='1']")
      assert has_element?(view, "#favorites-#{favorite.id}")

      assert has_element?(
               view,
               "#favorites-#{favorite.id} button[aria-label='Remove Cool Shop from saved']"
             )
    end

    test "unfavorite button removes the row", %{conn: conn, customer: customer, host: host} do
      shop = Factory.create_store!(%{name: "Drop Me", slug: "drop-me"})

      {:ok, fav} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: shop.id},
          actor: customer
        )

      {:ok, view, _html} = live(conn, "/s/#{host.slug}/saved-stores")
      assert has_element?(view, "#favorites-#{fav.id}")

      view
      |> element(~s|button[phx-click="unfavorite"][phx-value-id="#{fav.id}"]|)
      |> render_click()

      refute has_element?(view, "#favorites-#{fav.id}")
      assert has_element?(view, "#saved-stores[data-count='0']")
      assert has_element?(view, "#saved-stores-empty")
    end

    test "a forged event cannot remove another customer's favorite", %{
      conn: conn,
      host: host
    } do
      other_customer =
        Factory.create_customer!(host, %{
          email: "other-saved-stores-#{System.unique_integer([:positive])}@example.com"
        })

      shop = Factory.create_store!(%{name: "Private Shop", slug: "private-shop"})

      {:ok, other_favorite} =
        Emakola.Customers.favorite_store(
          %{customer_id: other_customer.id, store_id: shop.id},
          actor: other_customer
        )

      {:ok, view, _html} = live(conn, "/s/#{host.slug}/saved-stores")
      render_hook(view, "unfavorite", %{"id" => other_favorite.id})

      assert has_element?(view, "#flash-error[role='alert']")
      assert has_element?(view, "#saved-stores[data-count='0']")

      assert {:ok, [remaining]} =
               Emakola.Customers.list_favorite_stores(other_customer.id,
                 actor: other_customer
               )

      assert remaining.id == other_favorite.id
    end
  end

  defp sign_in_customer(conn, store) do
    customer =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "saved-stores-#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        store_id: store.id,
        name: "Saved Test"
      })
      |> Ash.create!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:customer_token, token)

    {customer, conn}
  end
end
