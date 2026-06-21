defmodule EmakolaWeb.AuthControllerTest do
  use EmakolaWeb.ConnCase, async: true

  alias EmakolaWeb.{AuthController, AuthTokens}

  setup %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Phoenix.Controller.fetch_flash()

    {:ok, conn: conn}
  end

  describe "success/4 — OAuth → cookie-session bridge" do
    test "signs the merchant subject into :user_token and redirects to /dashboard",
         %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()

      conn = AuthController.success(conn, {:google, :callback}, merchant, "provider-token")

      assert redirected_to(conn) == "/dashboard"

      token = get_session(conn, :user_token)
      assert is_binary(token)
      assert {:ok, subject} = AuthTokens.verify_subject(token)
      assert subject == AshAuthentication.user_to_subject(merchant)
    end
  end

  describe "failure/3" do
    test "redirects to /auth/login with an error flash", %{conn: conn} do
      conn = AuthController.failure(conn, {:google, :callback}, :provider_error)

      assert redirected_to(conn) == "/auth/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "didn't work"
    end
  end

  describe "success/4 — customer OAuth → storefront session" do
    test "stores :customer_token and redirects to the store's account page",
         %{conn: conn} do
      {_merchant, store} = Emakola.Factory.create_merchant_with_store!()

      {:ok, customer} =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(
          :register_with_oauth2,
          %{user_info: %{"email" => "shopper@example.com", "name" => "Ama"}, oauth_tokens: %{}},
          tenant: store.id
        )
        |> Ash.create(authorize?: false)

      conn =
        conn
        |> put_session("customer_oauth_store_slug", store.slug)
        |> AuthController.success({:google, :callback}, customer, "tok")

      assert redirected_to(conn) == "/@#{store.slug}/account"
      assert {:ok, _subject} = AuthTokens.verify_subject(get_session(conn, :customer_token))
    end
  end
end
