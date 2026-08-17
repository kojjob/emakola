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
end
