defmodule EmakolaWeb.Auth.ResetPasswordLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  require Ash.Query

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{Merchant, Token}

  defp register_and_request_token! do
    email = "resetlv-#{System.unique_integer([:positive])}@example.com"

    merchant =
      Merchant
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{email: email, password: "Password123!", password_confirmation: "Password123!"},
        authorize?: false
      )
      |> Ash.create!()

    flush_emails()

    strategy = Info.strategy!(Merchant, :password)
    Strategy.action(strategy, :reset_request, %{"email" => email})

    token =
      assert_email_sent(fn sent ->
        [t] =
          Regex.run(~r{/auth/reset-password\?token=([^"\s]+)}, sent.text_body,
            capture: :all_but_first
          )

        t
      end)

    {merchant, email, token}
  end

  # Registration sends its own mail (welcome + confirmation); drain it so the
  # reset email is the next one asserted.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  test "renders the new-password form when a token is present", %{conn: conn} do
    {_m, _e, token} = register_and_request_token!()
    {:ok, _lv, html} = live(conn, ~p"/auth/reset-password?token=#{token}")
    assert html =~ "Set a new password"
  end

  test "a valid reset redirects to login, changes the password, and revokes other sessions", %{
    conn: conn
  } do
    {merchant, email, token} = register_and_request_token!()
    strategy = Info.strategy!(Merchant, :password)

    # A live session from before the reset — must die with the reset
    {:ok, _} =
      Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})

    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=#{token}")

    lv
    |> form("form",
      reset: %{password: "NewPassword456!", password_confirmation: "NewPassword456!"}
    )
    |> render_submit()

    flash = assert_redirect(lv, "/auth/login")
    assert flash["info"] =~ "Password updated"

    # Count BEFORE the verification sign-ins below — a successful sign-in
    # legitimately mints a fresh live token.
    subject = AshAuthentication.user_to_subject(merchant)

    live_tokens =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert live_tokens == [], "expected all pre-reset tokens to be revoked"

    assert {:ok, _} =
             Strategy.action(strategy, :sign_in, %{
               "email" => email,
               "password" => "NewPassword456!"
             })

    assert {:error, _} =
             Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})
  end

  test "a short password shows the interpolated error, not %{min}", %{conn: conn} do
    {_m, _e, token} = register_and_request_token!()
    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=#{token}")

    html =
      lv
      |> form("form", reset: %{password: "short", password_confirmation: "short"})
      |> render_submit()

    refute html =~ "%{min}"
    assert html =~ "greater than or equal to 8"
  end

  test "a garbage token shows the invalid-link state with a re-request link", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=garbage")

    html =
      lv
      |> form("form",
        reset: %{password: "NewPassword456!", password_confirmation: "NewPassword456!"}
      )
      |> render_submit()

    assert html =~ "link is invalid or has expired"
    assert html =~ ~s(href="/auth/forgot-password")
  end

  test "no token at all renders the invalid-link state immediately", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/reset-password")
    assert html =~ "link is invalid or has expired"
    assert html =~ ~s(href="/auth/forgot-password")
  end
end
