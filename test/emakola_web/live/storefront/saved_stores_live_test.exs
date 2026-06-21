defmodule EmakolaWeb.Storefront.SavedStoresLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  describe "GET /@:slug/saved-stores" do
    test "redirects to login when not authenticated", %{conn: conn} do
      store = Factory.create_store!(%{name: "Host Store", slug: "host-store"})

      assert {:error, {:redirect, %{to: redirect_to}}} =
               live(conn, "/@#{store.slug}/saved-stores")

      assert redirect_to =~ "/login"
    end
  end

  describe "GET /@:slug/saved-stores (authenticated)" do
    setup %{conn: conn} do
      host = Factory.create_store!(%{name: "Host Store", slug: "host-store"})
      {customer, conn} = sign_in_customer(conn, host)
      %{conn: conn, customer: customer, host: host}
    end

    test "shows empty state when customer has no favorites", %{conn: conn, host: host} do
      {:ok, _view, html} = live(conn, "/@#{host.slug}/saved-stores")
      assert html =~ "No saved stores yet"
    end

    test "lists favorited stores", %{conn: conn, customer: customer, host: host} do
      shop = Factory.create_store!(%{name: "Cool Shop", slug: "cool-shop"})

      {:ok, _} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: shop.id},
          actor: customer
        )

      {:ok, _view, html} = live(conn, "/@#{host.slug}/saved-stores")
      assert html =~ "Cool Shop"
      assert html =~ "1 store you"
    end

    test "unfavorite button removes the row", %{conn: conn, customer: customer, host: host} do
      shop = Factory.create_store!(%{name: "Drop Me", slug: "drop-me"})

      {:ok, fav} =
        Emakola.Customers.favorite_store(
          %{customer_id: customer.id, store_id: shop.id},
          actor: customer
        )

      {:ok, view, html} = live(conn, "/@#{host.slug}/saved-stores")
      assert html =~ "Drop Me"

      html =
        view
        |> element(~s|button[phx-click="unfavorite"][phx-value-id="#{fav.id}"]|)
        |> render_click()

      refute html =~ "Drop Me"
      assert html =~ "No saved stores yet"
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
