defmodule EmakolaWeb.Auth.ConfirmController do
  @moduledoc """
  The page a merchant lands on from the confirmation email.

  ash_authentication generates its own page for `require_interaction?: true`
  — a bare form with no CSRF token, which the `:browser` pipeline then
  refuses with `Plug.CSRFProtection.InvalidCSRFTokenError`. Confirmation
  therefore could not complete at all. That went unnoticed while sign-in
  ignored confirmation; now that access depends on it, it is the difference
  between a merchant opening their shop and being locked out of it forever.

  The interaction itself is the point of the page and stays: a bare GET must
  not confirm, because mail scanners prefetch links.
  """
  use EmakolaWeb, :controller

  def show(conn, %{"confirm" => token}) when is_binary(token) and token != "" do
    render(conn, :show, token: token, layout: false)
  end

  def show(conn, _params) do
    conn
    |> put_flash(:error, "That confirmation link is incomplete. Sign in to get a fresh one.")
    |> redirect(to: ~p"/auth/login")
  end
end
