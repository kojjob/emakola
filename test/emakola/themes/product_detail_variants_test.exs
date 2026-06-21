defmodule Emakola.Themes.ProductDetailVariantsTest do
  @moduledoc """
  Renderer-level smoke test: every theme's `ProductDetail.render/1`
  must handle a product with variants without raising.

  Pins the regression caught at /@kente-kingdom/products/... where
  five themes wrote `option_type.values` instead of the actual
  `option_type.option_values` field on `Emakola.Catalog.OptionType`.

  We render against the real Ash struct (with option_values loaded)
  rather than a hand-rolled map, so any future field rename or
  relationship change surfaces here too.
  """
  use EmakolaWeb.ConnCase, async: true

  alias Emakola.Factory

  @themes [
    {Emakola.Themes.Spotlight, "spotlight"},
    {Emakola.Themes.Akoma, "akoma"},
    {Emakola.Themes.Pharmacy, "pharmacy"},
    {Emakola.Themes.Beauty, "beauty"},
    {Emakola.Themes.HomeLiving, "home_living"},
    {Emakola.Themes.Electronics, "electronics"},
    {Emakola.Themes.Fashion, "fashion"},
    {Emakola.Themes.Heritage, "heritage"}
  ]

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    product = Factory.create_product!(store, %{title: "Tee with size"})

    size_option = Factory.create_option_type!(product, store, %{name: "Size", position: 0})
    Factory.create_option_value!(size_option, store, %{value: "S", position: 0})
    Factory.create_option_value!(size_option, store, %{value: "M", position: 1})
    Factory.create_option_value!(size_option, store, %{value: "L", position: 2})

    Factory.create_variant!(product, store, %{price: 12_000, stock_quantity: 5})

    require Ash.Query

    loaded_product =
      Emakola.Catalog.Product
      |> Ash.Query.filter(id == ^product.id)
      |> Ash.Query.load([:variants, :images, :min_price, :max_price])
      |> Ash.read_one!(authorize?: false)

    [option_type] =
      Emakola.Catalog.OptionType
      |> Ash.Query.filter(product_id == ^product.id)
      |> Ash.Query.load(:option_values)
      |> Ash.read!(authorize?: false)

    %{
      store: store,
      product: loaded_product,
      option_type: option_type,
      option_values: option_type.option_values
    }
  end

  for {theme_module, label} <- @themes do
    @theme_module theme_module
    @label label

    test "#{@label} ProductDetail renders product with variants without raising", %{
      store: store,
      product: product,
      option_type: option_type,
      option_values: option_values
    } do
      theme = Emakola.Themes.ThemeResolver.resolve(%{"theme" => @label}, store)
      product_detail = Module.concat(@theme_module, ProductDetail)

      [first_value | _] = option_values

      assigns = %{
        __changed__: nil,
        store: store,
        theme: theme,
        product: product,
        related_products: [],
        categories: [],
        cart_count: 0,
        selected_variant: nil,
        option_types: [option_type],
        selected_options: %{option_type.id => first_value.id},
        quantity: 1,
        current_image_index: 0
      }

      rendered = product_detail.render(assigns)
      html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

      # Each option value must render its label
      for option_value <- option_values do
        assert html =~ option_value.value,
               "#{@label}: expected option value '#{option_value.value}' in rendered output"
      end

      # The selected value must show as visually selected via the
      # phx-value-value=<option_value.id> attribute
      assert html =~ first_value.id,
             "#{@label}: selected option_value id should appear in HTML"

      # Defensive: bug-shaped errors leave the field name hanging
      refute html =~ "option_type.values",
             "#{@label}: leaked an unrendered template fragment"
    end
  end
end
