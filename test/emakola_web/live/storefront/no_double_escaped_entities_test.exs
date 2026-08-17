defmodule EmakolaWeb.Storefront.NoDoubleEscapedEntitiesTest do
  @moduledoc """
  No storefront page may show a buyer a double-escaped HTML entity.

  Writing `&amp;` inside a HEEx attribute or expression gets escaped again at
  render time, so the buyer reads the literal text "&amp;" — Atelier's PDP
  shipped an accordion titled "SHIPPING &AMP; RETURNS" this way. In the
  rendered document that mistake is always the byte sequence `&amp;amp;`,
  which is what this sweep hunts across every theme's funnel pages.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  @double_escape "&amp;amp;"

  defp store_on_theme!(theme_id) do
    store = Factory.create_store!(%{currency: "GHS"})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => theme_id}})
    |> Ash.update!(authorize?: false)
  end

  defp stocked_product!(store) do
    product = Factory.create_product!(store, %{title: "Kente Wrap"})
    _variant = Factory.create_variant!(product, store, %{price: 12_000, stock_quantity: 5})

    product
    |> Ash.Changeset.for_update(:activate, %{}, authorize?: false)
    |> Ash.update!(authorize?: false)
  end

  for theme_id <- ThemeResolver.theme_ids() do
    test "#{theme_id}: funnel pages carry no double-escaped entities", %{conn: conn} do
      store = store_on_theme!(unquote(theme_id))
      product = stocked_product!(store)

      for path <- [
            "/s/#{store.slug}",
            "/s/#{store.slug}/products",
            "/s/#{store.slug}/products/#{product.slug}"
          ] do
        {:ok, _view, html} = live(conn, path)

        refute html =~ @double_escape,
               "#{unquote(theme_id)} #{path}: a buyer-visible \"&amp;\" is being " <>
                 "escaped twice (renders as the literal text &amp;)"
      end
    end
  end
end
