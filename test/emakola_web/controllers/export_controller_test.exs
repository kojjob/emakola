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

  describe "GET /admin/export/analytics.pdf as an unverified merchant" do
    # Every other merchant surface is a LiveView behind Hooks.RequireAuth, so
    # the verification gate lives there. This route is a plain controller and
    # never passes through that hook. A merchant who registered before the gate
    # and never traded is left unverified by the backfill, still owns a store,
    # and still holds a session — so without this check they could keep pulling
    # their analytics out of an account they are otherwise locked out of.
    test "is refused rather than handed a report", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!(confirmed_at: nil)
      store = Emakola.Factory.create_store!()

      Emakola.Accounts.StoreMembership
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
        store_id: store.id,
        role: :owner
      })
      |> Ash.create!(authorize?: false)

      signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, signed)
        |> get(@export_path)

      assert response(conn, 401) == "Unauthorized"
    end
  end
end
