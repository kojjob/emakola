defmodule EmakolaWeb.Storefront.AboutRenderAuditTest do
  @moduledoc """
  Every registered theme must render /about without crashing.

  `AboutLive.render/1` asks `ThemeRenderer` for the theme's `:about` callback
  and, when the theme doesn't implement it, falls back — but the fallback used
  to call the very `render_about/1` the dispatcher just found missing, so any
  theme without the callback served visitors a Phoenix crash page (Spotlight
  shipped that way). The per-theme loop exists so a future theme cannot repeat
  it: registration alone puts a theme under this test.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  defp store_on_theme!(theme_id) do
    store = Factory.create_store!(%{currency: "GHS"})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => theme_id}})
    |> Ash.update!(authorize?: false)
  end

  for theme_id <- ThemeResolver.theme_ids() do
    test "#{theme_id}: /about renders instead of crashing", %{conn: conn} do
      store = store_on_theme!(unquote(theme_id))

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      assert html =~ store.name,
             "#{unquote(theme_id)}: /about rendered but never mentions the store"
    end
  end

  # /about used to be Atelier's page on every theme: 21 themes delegated to
  # Atelier.About, which renders Atelier's nav, footer and typography — the
  # store's entire chrome swapped for a different theme's on one click. The
  # audit ranked this the platform's #1 brand break.
  for theme_id <- ThemeResolver.theme_ids(), theme_id != "atelier" do
    test "#{theme_id}: /about wears the store's own chrome, not Atelier's", %{conn: conn} do
      store = store_on_theme!(unquote(theme_id))

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      refute html =~ "atelier-body",
             "#{unquote(theme_id)}: /about is rendering Atelier's page — foreign nav, " <>
               "footer and typography replace the store's own chrome"

      refute html =~ "text-8xl",
             "#{unquote(theme_id)}: /about still shows the giant letter-monogram " <>
               "placeholder where a designed story section should be"
    end
  end

  describe "theme-owned chrome on /about (mirrors fallback_chrome_test)" do
    test "a Beauty store's /about renders Beauty's nav and footer", %{conn: conn} do
      store = store_on_theme!("beauty")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      # Beauty nav header (cream, blurred, sand border) and footer (espresso)
      assert html =~ "bg-[#F5EFE5]/95"
      assert html =~ "bg-[#3D2F25]"
    end

    test "a Bold store's /about renders Bold's chrome", %{conn: conn} do
      store = store_on_theme!("bold")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      # Bold slate-900 nav/footer background
      assert html =~ "bg-[#0F172A]"
    end

    test "a Chale store's /about paints Chale's cobalt, not a stale fallback", %{conn: conn} do
      store = store_on_theme!("chale")

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/about")

      # Chale's theme_styles renders on shared pages with an empty theme map,
      # so its fallback literals paint the page. The cobalt restyle changed
      # defaults() but missed those fallbacks — the About accents came out
      # crimson (#DC143C) on a cobalt (#2547E8) theme.
      refute html =~ "#DC143C"
      assert html =~ "#2547E8"
    end
  end
end
