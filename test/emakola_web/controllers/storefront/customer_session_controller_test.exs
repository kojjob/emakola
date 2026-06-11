defmodule EmakolaWeb.Storefront.CustomerSessionControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias EmakolaWeb.AuthTokens

  setup do
    store = create_store!()
    customer = create_customer!(store)
    %{store: store, customer: customer}
  end

  describe "GET /s/:slug/auth/customer-session with a raw (unsigned) subject" do
    test "does not establish a session", %{conn: conn, store: store, customer: customer} do
      raw_subject = AshAuthentication.user_to_subject(customer)

      conn =
        get(
          conn,
          "/s/#{store.slug}/auth/customer-session?token=#{URI.encode_www_form(raw_subject)}"
        )

      assert redirected_to(conn) == "/s/#{store.slug}/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
      refute get_session(conn, :customer_token)
    end
  end

  describe "GET /s/:slug/auth/customer-session with a signed subject" do
    test "establishes a session and redirects to account", %{
      conn: conn,
      store: store,
      customer: customer
    } do
      signed = customer |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn =
        get(
          conn,
          "/s/#{store.slug}/auth/customer-session?token=#{URI.encode_www_form(signed)}"
        )

      assert redirected_to(conn) == "/s/#{store.slug}/account"
      assert get_session(conn, :customer_token) == signed

      # Follow-up request resolves the customer
      assert {:ok, _view, html} = live(conn, "/s/#{store.slug}/account")
      assert html =~ customer.name
    end
  end

  describe "GET /s/:slug/auth/customer-session with garbage or missing token" do
    test "garbage token redirects to login without session write", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/auth/customer-session?token=garbage")

      assert redirected_to(conn) == "/s/#{store.slug}/login"
      refute get_session(conn, :customer_token)
    end

    test "missing token redirects to login", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/auth/customer-session")

      assert redirected_to(conn) == "/s/#{store.slug}/login"
      refute get_session(conn, :customer_token)
    end
  end
end
