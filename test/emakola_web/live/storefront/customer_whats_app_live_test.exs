defmodule EmakolaWeb.Storefront.CustomerWhatsAppLiveTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox
  require Ash.Query
  setup :verify_on_exit!

  alias Emakola.Factory

  setup do
    Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)
    Application.put_env(:emakola, :phone_auth_enabled, true)

    store =
      Factory.create_store!(%{
        name: "WA Store",
        slug: "wa-store-#{System.unique_integer([:positive])}",
        currency: "GHS"
      })

    %{store: store}
  end

  # Unique national number (no leading 0 — the +233 country code replaces the
  # trunk prefix) per test, so the live (ETS) send rate-limiter (3/10min per
  # phone) never accumulates across tests.
  defp unique_national_number do
    n = System.unique_integer([:positive]) |> rem(100_000_000)
    "2" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  test "new customer: phone -> code -> email -> signed in (store-scoped)", %{
    conn: conn,
    store: store
  } do
    parent = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c})
      {:ok, %{}}
    end)

    number = unique_national_number()

    {:ok, lv, _} = live(conn, ~p"/s/#{store.slug}/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()
    assert_received {:code, code}

    lv |> form("#code-form", otp: %{code: code}) |> render_submit()

    result =
      lv
      |> form("#email-form",
        customer: %{email: "wa-#{System.unique_integer([:positive])}@example.com", name: "Kofi"}
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: to}}} = result
    assert to =~ "/s/#{store.slug}/auth/customer-session"
  end

  test "existing customer signs in directly (no email step)", %{conn: conn, store: store} do
    parent = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c})
      {:ok, %{}}
    end)

    number = unique_national_number()
    normalized = Emakola.Accounts.PhoneAuth.normalize("+233" <> number)

    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(
      :register_with_phone,
      %{email: "existing-#{System.unique_integer([:positive])}@example.com", phone: normalized},
      tenant: store.id
    )
    |> Ash.create!(authorize?: false)

    {:ok, lv, _} = live(conn, ~p"/s/#{store.slug}/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()
    assert_received {:code, code}

    result = lv |> form("#code-form", otp: %{code: code}) |> render_submit()

    assert {:error, {:redirect, %{to: to}}} = result
    assert to =~ "/s/#{store.slug}/auth/customer-session"
  end

  test "cross-store isolation: a phone registered in store A does not sign into store B", %{
    conn: conn,
    store: store_b
  } do
    parent = self()

    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c})
      {:ok, %{}}
    end)

    store_a =
      Factory.create_store!(%{
        name: "Store A",
        slug: "store-a-#{System.unique_integer([:positive])}",
        currency: "GHS"
      })

    number = unique_national_number()
    normalized = Emakola.Accounts.PhoneAuth.normalize("+233" <> number)

    # Register the customer in store A only.
    Emakola.Customers.Customer
    |> Ash.Changeset.for_create(
      :register_with_phone,
      %{email: "a-only-#{System.unique_integer([:positive])}@example.com", phone: normalized},
      tenant: store_a.id
    )
    |> Ash.create!(authorize?: false)

    # Authenticate against store B with the same phone — should NOT find the
    # store-A customer, so the flow proceeds to the email (new-account) step.
    {:ok, lv, _} = live(conn, ~p"/s/#{store_b.slug}/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: number}) |> render_submit()
    assert_received {:code, code}

    html = lv |> form("#code-form", otp: %{code: code}) |> render_submit()

    # Stays in the LiveView on the email step (no redirect to a session).
    assert html =~ "email-form"
  end

  test "create_account is refused before OTP verification", %{conn: conn, store: store} do
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:ok, %{}} end)

    number = unique_national_number()
    phone = Emakola.Accounts.PhoneAuth.to_e164("+233", number)

    {:ok, lv, _} = live(conn, ~p"/s/#{store.slug}/whatsapp")

    # Request a code (assigns the phone, step -> :code) but DO NOT verify.
    render_submit(lv, "send_code", %{"phone" => %{"cc" => "+233", "number" => number}})

    # Scripted bypass: dispatch create_account directly, skipping verify_code.
    render_submit(lv, "create_account", %{
      "customer" => %{"email" => "squatter@example.com", "name" => "Squatter"}
    })

    customers =
      Emakola.Customers.Customer
      |> Ash.Query.filter(phone == ^phone)
      |> Ash.read!(authorize?: false)

    assert customers == []
  end
end
