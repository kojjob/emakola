defmodule EmakolaWeb.Company.PressLiveTest do
  # async: false — the regression test mutates Application env (the press email
  # config key), which is global state.
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "renders boilerplate, brand asset download, and press contact", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/press")

    assert html =~ "Press &amp; media" or html =~ "Press"
    assert html =~ "Brand assets"
    assert html =~ ~s(href="/images/emakola-logo.svg")
    assert html =~ ~s(href="mailto:press@makola.io")
  end

  test "renders (no 500) even when the press email config key is absent", %{conn: conn} do
    # Reproduces the production bug: a server booted before the config was added
    # has no :press_email key, so the page must fall back to a default instead
    # of crashing on `"mailto:" <> nil`.
    original = Application.fetch_env(:emakola, :press_email)
    Application.delete_env(:emakola, :press_email)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:emakola, :press_email, value)
        :error -> Application.delete_env(:emakola, :press_email)
      end
    end)

    {:ok, _view, html} = live(conn, "/press")

    assert html =~ ~s(href="mailto:press@makola.io")
  end
end
