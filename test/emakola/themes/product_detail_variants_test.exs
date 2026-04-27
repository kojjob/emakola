defmodule Emakola.Themes.ProductDetailVariantsTest do
  @moduledoc """
  Regression test for the `option_type.values` KeyError that crashed
  product detail pages on the 5 niche themes (Beauty, Electronics,
  Fashion, Home Living, Pharmacy). The OptionType resource exposes
  `option_values` (a relationship), not `values` — themes that
  iterate `option_type.values` raise KeyError at render time.

  Each test below loads an OptionType with its option_values and
  renders the theme's `product_detail` template via Phoenix.LiveView's
  `render_component/3`. Any future breakage of this contract fails fast.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  @themes [
    {Emakola.Themes.Beauty.ProductDetail, "beauty"},
    {Emakola.Themes.Electronics.ProductDetail, "electronics"},
    {Emakola.Themes.Fashion.ProductDetail, "fashion"},
    {Emakola.Themes.HomeLiving.ProductDetail, "home_living"},
    {Emakola.Themes.Pharmacy.ProductDetail, "pharmacy"}
  ]

  for {module, name} <- @themes do
    test "#{name} theme renders product detail with variant options without KeyError" do
      store =
        Factory.create_store!(%{
          name: "Variant Test Store",
          slug: "variant-test-#{unquote(name)}"
        })

      product = Factory.create_product!(store, %{title: "Test Product #{unquote(name)}"})

      option_type = Factory.create_option_type!(product, store, %{name: "Size"})
      ov_small = Factory.create_option_value!(option_type, store, %{value: "Small", position: 0})
      ov_large = Factory.create_option_value!(option_type, store, %{value: "Large", position: 1})

      option_type_loaded = %{option_type | option_values: [ov_small, ov_large]}

      assigns = %{
        store: store,
        theme: %{},
        product: %{product | variants: [], images: [], min_price: 5000, max_price: 5000},
        option_types: [option_type_loaded],
        selected_options: %{},
        selected_variant: nil,
        quantity: 1,
        related_products: [],
        categories: [],
        cart_count: 0,
        current_customer: nil,
        current_image_index: 0
      }

      html = render_component(&unquote(module).render/1, assigns)

      assert html =~ "Small"
      assert html =~ "Large"
    end
  end
end
