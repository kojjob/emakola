defmodule EmakolaWeb.ImpersonateSessionControllerTest do
  @moduledoc """
  Impersonation session bridging: `start` swaps the staff platform session for
  the merchant's `:user_token` (+ an `:impersonation` map) and audits; `exit`
  restores the staff session and audits. Both verify the real staff server-side.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  require Ash.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Factory

  defp no_csrf(conn), do: Plug.Conn.put_private(conn, :plug_skip_csrf_protection, true)

  defp audit(event) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(action == ^event)
    |> Ash.read!(authorize?: false, page: [limit: 200])
    |> case do
      %{results: results} -> results
      list when is_list(list) -> list
    end
  end

  describe "start" do
    setup %{conn: conn} do
      {conn, user, session} = setup_platform_staff(conn)
      {merchant, _store} = Factory.create_merchant_with_store!()
      %{conn: conn, user: user, session: session, merchant: merchant}
    end

    test "swaps the session to the merchant and audits", %{
      conn: conn,
      user: user,
      session: session,
      merchant: merchant
    } do
      conn = conn |> no_csrf() |> post(~p"/platform/impersonate/#{merchant.id}")

      assert redirected_to(conn) == "/dashboard"
      assert is_nil(get_session(conn, :platform_session_token))
      assert get_session(conn, :user_token)

      imp = get_session(conn, :impersonation)
      assert imp["staff_user_id"] == user.id
      assert imp["merchant_id"] == merchant.id
      assert imp["return_session_id"] == session.id
      assert imp["expires_at"] > System.os_time(:second)

      assert [entry] = audit(:impersonation_started)
      assert entry.actor_id == user.id
      assert entry.metadata["merchant_id"] == merchant.id
    end

    test "staff without :manage_merchants is rejected, session untouched", %{
      conn: base_conn,
      merchant: merchant
    } do
      {conn, _u, _s} = setup_platform_staff(base_conn, permissions: [:view_audit_log])
      conn = conn |> no_csrf() |> post(~p"/platform/impersonate/#{merchant.id}")

      assert redirected_to(conn) == "/platform"
      assert is_nil(get_session(conn, :impersonation))
      assert get_session(conn, :platform_session_token)
      assert audit(:impersonation_started) == []
    end

    test "a missing merchant is rejected", %{conn: conn} do
      conn = conn |> no_csrf() |> post(~p"/platform/impersonate/#{Ash.UUID.generate()}")
      assert redirected_to(conn) == "/platform"
      assert is_nil(get_session(conn, :impersonation))
    end
  end

  describe "exit" do
    test "restores the staff platform session, clears impersonation, and audits", %{conn: conn} do
      {_c, user, session} = setup_platform_staff(conn)

      conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_token, "merchant-token")
        |> put_session(:impersonation, %{
          "staff_user_id" => user.id,
          "merchant_id" => Ash.UUID.generate(),
          "expires_at" => System.os_time(:second) + 1000,
          "return_session_id" => session.id
        })
        |> get(~p"/platform/impersonate/exit")

      assert redirected_to(conn) == "/platform"
      assert is_nil(get_session(conn, :user_token))
      assert is_nil(get_session(conn, :impersonation))
      assert get_session(conn, :platform_session_token)

      assert [entry] = audit(:impersonation_ended)
      assert entry.actor_id == user.id
    end

    test "exit without an active impersonation just redirects", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> get(~p"/platform/impersonate/exit")
      assert redirected_to(conn) == "/platform"
    end
  end
end
