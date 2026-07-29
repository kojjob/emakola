defmodule EmakolaWeb.Auth.ForgotPasswordLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

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
      |> form("form", forgot: %{email: email})
      |> render_submit()

    assert html =~ "If that email has a Makola account"
    assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
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
    refute_email_sent()
  end

  test "the login page links here instead of href=#", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    assert html =~ ~s(href="/auth/forgot-password")
  end
end
