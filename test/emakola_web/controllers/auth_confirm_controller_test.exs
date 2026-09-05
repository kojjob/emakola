defmodule EmakolaWeb.Auth.ConfirmControllerTest do
  @moduledoc """
  The page the confirmation email actually lands on.

  ash_authentication generates its own interaction page for
  `require_interaction?: true`, and that page carries no CSRF token — so
  submitting it through the `:browser` pipeline raises
  `Plug.CSRFProtection.InvalidCSRFTokenError` and the account is never
  confirmed. That was survivable while sign-in ignored confirmation. Now that
  access depends on it, an unsubmittable form is a merchant permanently
  locked out of the shop they just signed up for.

  So we serve the page: same token, a real CSRF token, and copy a merchant
  who reads slowly can act on.
  """

  use EmakolaWeb.ConnCase, async: true

  describe "GET /auth/confirm" do
    test "renders a form that can actually be submitted", %{conn: conn} do
      conn = get(conn, ~p"/auth/confirm?confirm=sometoken")
      html = html_response(conn, 200)

      assert html =~ "_csrf_token"
      assert html =~ "sometoken"
      assert html =~ ~s(action="/oauth/merchant/confirm_new_merchant")
      assert html =~ ~s(method="post")
    end

    test "a bare visit without a token is sent to sign in", %{conn: conn} do
      conn = get(conn, ~p"/auth/confirm")

      assert redirected_to(conn) =~ "/auth/login"
    end

    test "the token is escaped rather than trusted", %{conn: conn} do
      nasty = ~S|"><script>alert(1)</script>|
      conn = get(conn, ~p"/auth/confirm?confirm=#{nasty}")
      html = html_response(conn, 200)

      refute html =~ "<script>alert(1)</script>"
    end
  end
end
