defmodule EmakolaWeb.Admin.ImpersonationTest do
  @moduledoc """
  End-to-end impersonation resolution: an active `:impersonation` session
  resolves the target merchant and surfaces the real staff as `impersonator`
  (banner + Exit); an expired window auto-exits; a normal merchant sees neither.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  defp impersonation_session(conn, staff, merchant, expires_at) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn
    |> init_test_session(%{})
    |> put_session(:user_token, token)
    |> put_session(:impersonation, %{
      "staff_user_id" => staff.id,
      "merchant_id" => merchant.id,
      "expires_at" => expires_at,
      "return_session_id" => Ash.UUID.generate()
    })
  end

  test "an active impersonation resolves the merchant and shows the banner", %{conn: conn} do
    {_c, staff, _s} = setup_platform_staff(conn)
    {merchant, _store} = Factory.create_merchant_with_store!()

    conn = impersonation_session(conn, staff, merchant, System.os_time(:second) + 1000)
    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "are viewing"
    assert html =~ to_string(staff.email)
    assert html =~ "Exit impersonation"
  end

  test "an expired impersonation auto-exits to the exit route", %{conn: conn} do
    {_c, staff, _s} = setup_platform_staff(conn)
    {merchant, _store} = Factory.create_merchant_with_store!()

    conn = impersonation_session(conn, staff, merchant, System.os_time(:second) - 1)
    assert {:error, {:redirect, %{to: "/platform/impersonate/exit"}}} = live(conn, ~p"/dashboard")
  end

  test "a normal merchant session shows no impersonation banner", %{conn: conn} do
    {conn, _merchant, _store} = setup_authenticated_merchant(conn)
    {:ok, _view, html} = live(conn, ~p"/dashboard")
    refute html =~ "Exit impersonation"
  end
end
