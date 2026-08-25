defmodule EmakolaWeb.Auth.PhoneRecoveryLiveTest do
  @moduledoc """
  Recovering an account with a phone number instead of an email.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory
  import Mox

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    phone = "+2332" <> to_string(20_000_000 + System.unique_integer([:positive]))
    merchant = create_merchant!(%{phone: phone})
    test_pid = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: code}, _opts ->
      send(test_pid, {:code, code})
      {:ok, %{}}
    end)

    stub(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts -> {:ok, %{}} end)

    %{merchant: merchant, phone: phone}
  end

  test "the email recovery page offers the phone route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/auth/forgot-password")

    assert html =~ "/auth/recover-phone"
  end

  test "recovers an account end to end", %{conn: conn, merchant: merchant, phone: phone} do
    {:ok, view, _html} = live(conn, ~p"/auth/recover-phone")

    view |> form("#recover-phone-form", recover: %{phone: phone}) |> render_submit()

    assert_received {:code, code}
    assert has_element?(view, "#recover-code-form")

    # Success navigates to sign-in, so the view process is gone afterwards —
    # asserting on its render would be asserting on a dead process.
    view
    |> form("#recover-code-form", recover: %{code: code, password: "BrandNew123!"})
    |> render_submit()

    assert_redirect(view, "/auth/login")

    # The real proof: the new password works.
    assert {:ok, _} =
             Emakola.Accounts.Merchant
             |> Ash.Query.for_read(:sign_in_with_password, %{
               email: to_string(merchant.email),
               password: "BrandNew123!"
             })
             |> Ash.read_one(authorize?: false)
  end

  test "an unknown number looks exactly like a known one", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/auth/recover-phone")

    html =
      view
      |> form("#recover-phone-form", recover: %{phone: "+233209999999"})
      |> render_submit()

    # Never reveal whether a number has an account — this form would
    # otherwise enumerate every merchant's phone number.
    assert html =~ "code"
    refute html =~ "not found"
    refute html =~ "no account"
  end
end
