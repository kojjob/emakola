defmodule EmakolaWeb.Auth.WhatsAppButtonTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Emakola.Factory

  # config/test.exs defaults :phone_auth_enabled to true; these tests flip it
  # explicitly and restore the default so neither leaks into other tests.
  setup do
    on_exit(fn -> Application.put_env(:emakola, :phone_auth_enabled, true) end)
    :ok
  end

  test "merchant login shows an enabled WhatsApp link when phone auth is on", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, true)
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    assert html =~ ~s(href="/auth/whatsapp")
    refute html =~ "Coming Soon"
  end

  test "merchant login hides WhatsApp when phone auth is off", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, false)
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    refute html =~ "/auth/whatsapp"
  end

  test "merchant register shows an enabled WhatsApp link when phone auth is on", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, true)
    {:ok, _lv, html} = live(conn, ~p"/auth/register")
    assert html =~ ~s(href="/auth/whatsapp")
    refute html =~ "Coming Soon"
  end

  test "customer login shows a store-scoped WhatsApp link when phone auth is on", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, true)

    store =
      Factory.create_store!(%{
        name: "Button Store",
        slug: "button-store-#{System.unique_integer([:positive])}",
        currency: "GHS"
      })

    {:ok, _lv, html} = live(conn, ~p"/s/#{store.slug}/login")
    assert html =~ "/s/#{store.slug}/whatsapp"
  end

  test "customer login hides WhatsApp when phone auth is off", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, false)

    store =
      Factory.create_store!(%{
        name: "Button Store Off",
        slug: "button-store-off-#{System.unique_integer([:positive])}",
        currency: "GHS"
      })

    {:ok, _lv, html} = live(conn, ~p"/s/#{store.slug}/login")
    refute html =~ "/whatsapp"
  end
end
