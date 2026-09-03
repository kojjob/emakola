defmodule Emakola.Themes.MarketAdaptiveTest do
  @moduledoc """
  The Market home finishes at one product: nothing invented, nothing shown
  twice, no letter standing in for a picture, and the layout grows with the
  catalogue. Companion to `MarketSectionsTest`, which holds the older contract.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Market.Components
  alias Emakola.Themes.Market.Sections.{CategoryStrip, Hero}
  alias Emakola.Themes.{Market, ThemeResolver}

  @store %{
    slug: "stall",
    name: "Stall Front",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  defp product(attrs \\ %{}) do
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

  defp render(fun, assigns),
    do: assigns |> Map.put(:__changed__, nil) |> fun.() |> rendered_to_string()

  defp defaults(module), do: for(s <- module.settings_schema(), into: %{}, do: {s.key, s.default})

  describe "hero" do
    test "never borrows a product photo: the image comes only from the merchant's own setting" do
      products = [
        product(%{images: [%{thumbnail_url: "/uploads/shea.jpg", url: "/uploads/shea-full.jpg"}]})
      ]

      html =
        render(&Hero.render/1, %{store: @store, products: products, settings: defaults(Hero)})

      refute html =~ "<img"
      refute html =~ "shea"
      assert html =~ ~r/<h1[^>]*>\s*Stall Front\s*<\/h1>/
    end

    test "carries no monumental initial" do
      html = render(&Hero.render/1, %{store: @store, products: [], settings: defaults(Hero)})
      refute html =~ ~r/aria-hidden="true"[^>]*>\s*S\s*</s
    end
  end

  describe "placeholders" do
    test "a product card without a photo shows a pictogram, never the product's initial" do
      html = render(&Components.product_card/1, %{product: product(), store: @store})

      refute html =~ "<img"
      refute html =~ ~r/>\s*S\s*</
      assert html =~ ~s(data-placeholder="product")
      assert html =~ "line-clamp-2"
    end

    test "a featured card without a photo shows a pictogram, never the product's initial" do
      html = render(&Components.featured_card/1, %{product: product(), store: @store})

      refute html =~ ~r/>\s*S\s*</
      assert html =~ ~s(data-placeholder="product")
    end

    test "a category chip without a cover is a plain chip, not a lettered circle" do
      categories = [%{id: "c1", name: "Fresh Peppers", slug: "fresh-peppers"}]
      products = Enum.map(1..4, &product(%{id: "p#{&1}", slug: "p#{&1}"}))

      html =
        render(&CategoryStrip.render/1, %{
          store: @store,
          categories: categories,
          products: products,
          settings: %{}
        })

      assert html =~ "Fresh Peppers"
      refute html =~ ~r/>\s*F\s*</
    end
  end

  describe "about" do
    test "renders nothing without a description, and no monogram with one" do
      assert render(&Components.about_card/1, %{store: @store}) |> String.trim() == ""

      html =
        render(&Components.about_card/1, %{
          store: %{@store | description: "Family stall since 1998."}
        })

      assert html =~ "Family stall since 1998."
      refute html =~ ~r/>\s*S\s*</
    end
  end

  describe "home grows with the catalogue" do
    test "one product: hero, one featured card, trust — no grid, categories, about or newsletter" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})
      create_category!(store, %{name: "Fresh Peppers"})
      product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
      create_variant!(product, store, %{price: 12345, stock_quantity: 5})

      html = render_home(store)

      assert html =~ ~s(aria-label="Featured product")
      assert count(html, ~s(phx-value-product-id=)) == 1
      refute html =~ "Shop All"
      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "About the Shop"
      refute html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ "MTN MoMo"
    end

    test "two products: the featured one leaves the grid, so nothing is shown twice" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})

      for title <- ["Kente Tote Bag", "Shea Butter"] do
        product = create_product!(store, %{title: title, status: :active})
        create_variant!(product, store, %{price: 1000, stock_quantity: 5})
      end

      html = render_home(store)

      assert html =~ ~s(aria-label="Featured product")
      assert html =~ "Shop All"
      assert count(html, ~s(phx-value-product-id=)) == 2
      refute html =~ ~s(aria-label="Product categories")
      refute html =~ ~s(phx-submit="subscribe_newsletter")
    end

    test "a full stall with a description renders every section, in order" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "market"},
          description: "Hand-picked goods from Makola market."
        })

      create_category!(store, %{name: "Fresh Peppers"})

      for n <- 1..4 do
        product = create_product!(store, %{title: "Product #{n}", status: :active})
        create_variant!(product, store, %{price: 1000, stock_quantity: 5})
      end

      html = render_home(store)

      assert count(html, ~s(phx-value-product-id=)) == 4
      assert html =~ "Hand-picked goods from Makola market."

      assert String.match?(
               html,
               ~r/market-hero-heading.*Product categories.*Featured product.*Shop All.*About the Shop.*market-trust-heading.*market-newsletter-form/s
             )
    end
  end

  defp count(html, needle), do: length(String.split(html, needle)) - 1

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
