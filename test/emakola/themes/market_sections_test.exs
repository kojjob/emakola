defmodule Emakola.Themes.MarketSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Market.Components
  alias Emakola.Themes.{Market, Sections, ThemeResolver}

  @component_store %{
    slug: "stall",
    name: "Stall Front",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Shea Butter",
        slug: "shea-butter",
        description: nil,
        min_price: 4550,
        max_price: 4550,
        images: []
      },
      attrs
    )
  end

  defp render_component(fun, assigns) do
    assigns
    |> Map.put(:__changed__, nil)
    |> fun.()
    |> rendered_to_string()
  end

  describe "sections/0" do
    test "lists the four home sections in visual order" do
      keys = Enum.map(Market.sections(), & &1.key())

      assert keys == [
               "market/category_strip",
               "market/featured",
               "market/product_grid",
               "market/about"
             ]
    end

    test "every settings_schema entry declares a default" do
      for section <- Market.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end
  end

  describe "registry" do
    test "Market is sectionized and every section key resolves" do
      assert Sections.sectionized?(Market)

      for section <- Market.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "home render through SectionRenderer" do
    test "renders all four sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})
      create_category!(store, %{name: "Fresh Peppers"})
      product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
      create_variant!(product, store, %{price: 12345, stock_quantity: 5})

      html = render_home(store)

      # Category strip (nav must be labelled for screen readers)
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Fresh Peppers"
      # Featured stall-front card
      assert html =~ ~s(aria-label="Featured product")
      # Product grid
      assert html =~ "Shop All"
      assert html =~ "Kente Tote Bag"
      # Price chip: formatted from integer minor units, tabular numerals
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # About
      assert html =~ "About the Shop"

      # Flat sibling order: categories -> featured -> grid -> about
      assert String.match?(
               html,
               ~r/Product categories.*Featured product.*Shop All.*About the Shop/s
             )
    end

    test "empty products and categories render without crashing" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "Shop All"
      assert html =~ "About the Shop"
    end

    test "a store description renders in the about section" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "market"},
          description: "Hand-picked goods from Makola market."
        })

      html = render_home(store)

      assert html =~ "Hand-picked goods from Makola market."
    end
  end

  describe "price_chip/1" do
    test "renders the formatted price with tabular numerals" do
      html =
        render_component(&Components.price_chip/1, %{
          product: component_product(),
          store: @component_store
        })

      assert html =~ "GH₵ 45.50"
      assert html =~ "tabular-nums"
    end

    test "renders a range when min and max differ" do
      html =
        render_component(&Components.price_chip/1, %{
          product: component_product(%{min_price: 1000, max_price: 2500}),
          store: @component_store
        })

      assert html =~ "GH₵ 10 - GH₵ 25"
    end
  end

  describe "product_card/1" do
    test "looks finished with no image: initial, price chip, add to cart — no <img>" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      refute html =~ "<img"
      # Placeholder panel carries the product's initial
      assert html =~ ~r/>\s*S\s*</
      assert html =~ "GH₵ 45.50"
      assert html =~ "Shea Butter"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "keeps the placeholder panel beneath the image when one exists" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/shea.jpg"}]}),
          store: @component_store
        })

      assert html =~ ~s(src="/uploads/shea.jpg")
      assert html =~ ~s(alt="Shea Butter")
      assert html =~ ~s(loading="lazy")
      # The placeholder-first panel still renders underneath
      assert html =~ ~s(aria-hidden="true")
    end
  end

  describe "featured_card/1" do
    test "renders the stall front: oversized chip, title, and CTA" do
      html =
        render_component(&Components.featured_card/1, %{
          product: component_product(%{description: "Raw and unrefined."}),
          store: @component_store
        })

      assert html =~ "Featured"
      assert html =~ "Shea Butter"
      assert html =~ "Raw and unrefined."
      assert html =~ "GH₵ 45.50"
      assert html =~ "Add to Cart"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end
  end

  describe "about_card/1" do
    test "falls back to the neutral welcome copy without a description" do
      html = render_component(&Components.about_card/1, %{store: @component_store})

      assert html =~ "About the Shop"
      assert html =~ "Welcome to Stall Front."
      refute html =~ "Chat on WhatsApp"
    end

    test "renders the description and WhatsApp CTA when present" do
      store = %{
        @component_store
        | description: "Family stall since 1998.",
          whatsapp_number: "233200000000"
      }

      html = render_component(&Components.about_card/1, %{store: store})

      assert html =~ "Family stall since 1998."
      assert html =~ "Chat on WhatsApp"
      assert html =~ "wa.me/233200000000"
    end
  end

  defp render_home(store) do
    theme = ThemeResolver.resolve(store.theme_config || %{}, store)

    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.read!(authorize?: false)

    categories = Emakola.Catalog.list_root_categories!(store.id)

    %{
      store: store,
      products: products,
      categories: categories,
      theme: theme,
      cart_count: 0,
      __changed__: nil
    }
    |> Market.render_home()
    |> rendered_to_string()
  end
end
