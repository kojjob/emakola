defmodule EmakolaWeb.Storefront.BottomNavParityTest do
  @moduledoc """
  One store, one mobile bottom bar — on shared pages too.

  Shared pages (cart, account, category) used to hardcode the generic
  Home/Search/Saved/Cart bar, so a theme with its own bar (Dede's
  WhatsApp-first Home/Menu/WhatsApp/Cart, Chale's uppercase tabs, Pace's
  dark pill) swapped to a foreign variant the moment the shopper reached
  the cart — and themes with no bar grew one only there. The bar now
  dispatches through `Chrome.bottom_nav/1`: the theme's own
  `storefront_bottom_nav/1` when exported, the generic bar otherwise —
  each branch stamped with a `data-bottom-nav` marker this test reads.
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
    test "#{theme_id}: the cart page carries the store's own bottom bar (or the marked fallback)",
         %{conn: conn} do
      theme_id = unquote(theme_id)
      store = store_on_theme!(theme_id)
      theme_module = ThemeResolver.theme_module(theme_id)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      if function_exported?(theme_module, :storefront_bottom_nav, 1) do
        assert html =~ ~s(data-bottom-nav="theme"),
               "#{theme_id} exports storefront_bottom_nav/1 but the cart page " <>
                 "doesn't render the theme's own bar"

        refute html =~ ~s(data-bottom-nav="fallback"),
               "#{theme_id}: the generic bar renders alongside (or instead of) " <>
                 "the theme's own bar on the cart page"
      else
        assert html =~ ~s(data-bottom-nav="fallback"),
               "#{theme_id} has no storefront_bottom_nav/1, so the cart page " <>
                 "must carry the marked generic bar"
      end
    end
  end
end
