defmodule EmakolaWeb.Auth.WhatsAppLiveTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox
  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)
    Application.put_env(:emakola, :phone_auth_enabled, true)
    :ok
  end

  # Unique national number (no leading 0 — the +233 country code replaces the
  # trunk prefix) per test, so the live (ETS) send rate-limiter (3/10min per
  # phone) never accumulates across tests.
  defp unique_national_number do
    n = System.unique_integer([:positive]) |> rem(100_000_000)
    "2" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  test "new merchant: phone -> code -> email -> signed in", %{conn: conn} do
    parent = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c})
      {:ok, %{}}
    end)

    number = unique_national_number()

    {:ok, lv, _} = live(conn, ~p"/auth/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()
    assert_received {:code, code}

    lv |> form("#code-form", otp: %{code: code}) |> render_submit()
    # New phone -> email step
    result =
      lv
      |> form("#email-form",
        merchant: %{email: "wa-#{System.unique_integer([:positive])}@example.com", name: "Ama"}
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: to}}} = result
    assert to =~ "/auth/session"
  end

  test "existing merchant: phone -> code -> signed in (no email step)", %{conn: conn} do
    parent = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c})
      {:ok, %{}}
    end)

    number = unique_national_number()
    normalized = Emakola.Accounts.PhoneAuth.normalize("+233" <> number)
    Emakola.Factory.create_merchant!(phone: normalized)

    {:ok, lv, _} = live(conn, ~p"/auth/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()
    assert_received {:code, code}

    result = lv |> form("#code-form", otp: %{code: code}) |> render_submit()

    assert {:error, {:redirect, %{to: to}}} = result
    assert to =~ "/auth/session"
  end

  test "wrong code keeps the user on the code step with an error", %{conn: conn} do
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:ok, %{}} end)

    number = unique_national_number()

    {:ok, lv, _} = live(conn, ~p"/auth/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()

    html = lv |> form("#code-form", otp: %{code: "000000"}) |> render_submit()
    assert html =~ "Invalid code"
  end
end
