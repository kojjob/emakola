defmodule EmakolaWeb.Storefront.OverlayContainmentTest do
  @moduledoc """
  Every `absolute inset-0` overlay must live inside a positioned ancestor.

  `absolute inset-0` positions an element against its nearest positioned
  ancestor. When the caller forgets `relative` on the container, the overlay
  anchors to some distant ancestor and paints over unrelated content — on
  Adwuma's product page the gallery image covered the entire buy box and
  click-blocked "Add to cart" on every viewport. Render tests can't see
  painting, but this structural rule can be checked in the markup: for every
  `.absolute.inset-0` node there must be a positioned ancestor.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Themes.ThemeResolver

  @overlay ".absolute.inset-0"
  @contained Enum.map_join(
               ~w(relative absolute fixed sticky),
               ", ",
               &".#{&1} .absolute.inset-0"
             )

  defp uncontained_overlays(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(@overlay) |> Enum.count()
    contained = doc |> LazyHTML.query(@contained) |> Enum.count()

    total - contained
  end

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
    test "#{theme_id}: every absolute-inset-0 overlay has a positioned ancestor", %{conn: conn} do
      store = store_on_theme!(unquote(theme_id))
      product = stocked_product!(store)

      for path <- [
            "/s/#{store.slug}",
            "/s/#{store.slug}/products",
            "/s/#{store.slug}/products/#{product.slug}"
          ] do
        {:ok, _view, html} = live(conn, path)

        assert uncontained_overlays(html) == 0,
               "#{unquote(theme_id)} #{path}: an `absolute inset-0` element has no " <>
                 "positioned ancestor — it will anchor to a distant container and can " <>
                 "paint over unrelated content (this is how Adwuma's buy box became unclickable)"
      end
    end
  end
end
