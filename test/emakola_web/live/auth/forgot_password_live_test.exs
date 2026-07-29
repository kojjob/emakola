defmodule EmakolaWeb.Auth.ForgotPasswordLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp register!(email) do
    Emakola.Accounts.Merchant
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{email: email, password: "Password123!", password_confirmation: "Password123!"},
      authorize?: false
    )
    |> Ash.create!()
    |> tap(fn _ -> flush_emails() end)
  end

  # Reset mail is delivered off the request path (see PasswordResetSender —
  # a synchronous send would leak account existence via response latency), so
  # wait for it: Swoosh's assert_email_sent uses assert_received with no wait.
  defp await_email(timeout \\ 2_000) do
    assert_receive {:email, email}, timeout
    email
  end

  # Registration sends its own mail (welcome + confirmation); drain it so the
  # assertions below only see what the forgot-password flow sends.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  test "renders the request form with a back-to-login link", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/forgot-password")
    assert html =~ "Forgot your password"
    assert html =~ ~s(href="/auth/login")
  end

  test "a known email sends the reset mail and shows the neutral confirmation", %{conn: conn} do
    email = "forgot-#{System.unique_integer([:positive])}@example.com"
    register!(email)

    {:ok, lv, _html} = live(conn, ~p"/auth/forgot-password")

    html =
      lv
      |> form("#forgot-password-form", forgot: %{email: email})
      |> render_submit()

    assert html =~ "If that email has a Makola account"
    sent = await_email()
    assert {_, ^email} = hd(sent.to)
  end

  test "an unknown email shows the identical confirmation and sends nothing", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/auth/forgot-password")

    html =
      lv
      |> form("form",
        forgot: %{email: "nobody-#{System.unique_integer([:positive])}@example.com"}
      )
      |> render_submit()

    assert html =~ "If that email has a Makola account"
    refute_receive {:email, _}, 300
  end

  test "the login page links here instead of href=#", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    assert html =~ ~s(href="/auth/forgot-password")
  end
end
