defmodule EmakolaWeb.Company.CareersLiveTest do
  # async: false — the regression test mutates Application env (the careers email
  # config key), which is global state.
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "renders culture, benefits and a general-application mailto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/careers")

    assert html =~ "Life at Makola"
    assert html =~ "No open roles"
    assert html =~ ~s(href="mailto:careers@makola.io")
    assert html =~ ~s(id="main-nav")
  end

  test "renders (no 500) even when the careers email config key is absent", %{conn: conn} do
    # Reproduces the production bug: a server booted before the config was added
    # has no :careers_email key, so the page must fall back to a default instead
    # of crashing on `"mailto:" <> nil`.
    original = Application.fetch_env(:emakola, :careers_email)
    Application.delete_env(:emakola, :careers_email)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:emakola, :careers_email, value)
        :error -> Application.delete_env(:emakola, :careers_email)
      end
    end)

    {:ok, _view, html} = live(conn, "/careers")

    assert html =~ ~s(href="mailto:careers@makola.io")
  end
end
