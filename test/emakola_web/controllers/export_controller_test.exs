defmodule EmakolaWeb.ExportControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.AuthTokens

  @export_path "/admin/export/analytics.pdf"

  describe "GET /admin/export/analytics.pdf without a session token" do
    test "returns 401", %{conn: conn} do
      conn = get(conn, @export_path)

      assert response(conn, 401) == "Unauthorized"
    end
  end

  describe "GET /admin/export/analytics.pdf with a raw (unsigned) subject" do
    test "returns 401", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      raw_subject = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, raw_subject)
        |> get(@export_path)

      assert response(conn, 401) == "Unauthorized"
    end
  end

  describe "GET /admin/export/analytics.pdf with a signed merchant session" do
    test "passes auth and redirects to reports on invalid dates", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, signed)
        |> get(@export_path, %{"start_date" => "not-a-date"})

      assert redirected_to(conn) == "/admin/reports"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid date range provided."
    end

    test "merchant without a store redirects to dashboard", %{conn: conn} do
      merchant = create_merchant!()
      signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, signed)
        |> get(@export_path)

      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end
end
