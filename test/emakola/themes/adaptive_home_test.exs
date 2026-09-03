defmodule Emakola.Themes.AdaptiveHomeTest do
  @moduledoc """
  Every theme's home finishes at one product. The rules are the same for all
  22 themes, so they live in one place and run against each theme id:

    * a product's photo appears at most once on the home
    * a product without a photo gets exactly one pictogram placeholder, never a letter
    * a store with no description carries no invented copy about itself
    * a one-product shop shows no newsletter form; a full stall may
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.ThemeResolver

  @boilerplate [
    "Welcome to ",
    "Browse the collection",
    "Curated goods",
    "Elevate Your Essence",
    "Botanical skincare",
    "Do you ship",
    "handpicked",
    "hand-picked for you",
    "quality products"
  ]

  for theme_id <- ThemeResolver.theme_ids() do
    describe "#{theme_id}" do
      @describetag theme: theme_id

      test "a product's photo appears at most once, and a one-product shop has no newsletter form" do
        store = store!(unquote(theme_id))
        product = product!(store, "Kente Tote Bag")
        image = create_image!(product, store, %{url: "https://s3.example.com/kente-tote.jpg"})

        html = render_home(store)

        assert html =~ "Kente Tote Bag"

        assert count(html, image.url) <= 1,
               "#{unquote(theme_id)} shows the same photo more than once"

        refute html =~ ~s(phx-submit="subscribe_newsletter")
      end

      test "a product without a photo gets one pictogram placeholder, never a letter tile" do
        store = store!(unquote(theme_id))
        product!(store, "Xbox Game Pad")

        html = render_home(store)

        assert count(html, ~s(data-placeholder="product")) == 1,
               "#{unquote(theme_id)} should show exactly one placeholder for its one product"
      end

      test "a store with no description carries no invented copy about itself" do
        store = store!(unquote(theme_id))
        product!(store, "Shea Butter")

        html = render_home(store)

        for phrase <- @boilerplate do
          refute html =~ phrase, "#{unquote(theme_id)} invents: #{phrase}"
        end
      end

      test "a full stall with a description shows it, and still never repeats a photo" do
        store = store!(unquote(theme_id), "Hand-picked goods from Makola market.")

        images =
          for n <- 1..4 do
            product = product!(store, "Product #{n}")
            create_image!(product, store, %{url: "https://s3.example.com/product-#{n}.jpg"})
          end

        html = render_home(store)

        assert html =~ "Hand-picked goods from Makola market."

        for image <- images do
          assert count(html, image.url) <= 1, "#{unquote(theme_id)} repeats #{image.url}"
        end
      end
    end
  end

  defp store!(theme_id, description \\ nil) do
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => theme_id},
        description: description
      })

    store
  end

  defp product!(store, title) do
    product = create_product!(store, %{title: title, status: :active})
    create_variant!(product, store, %{price: 1000, stock_quantity: 5})
    product
  end

  defp count(html, needle), do: length(String.split(html, needle)) - 1

  defp render_home(store) do
    theme = ThemeResolver.resolve(store.theme_config || %{}, store)
    theme_module = ThemeResolver.theme_module(store.theme_config["theme"])

    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.Query.load([:variants, :images])
      |> Ash.read!(authorize?: false)

    categories = Emakola.Catalog.list_root_categories!(store.id)

    %{
      store: store,
      products: products,
      categories: categories,
      theme: theme,
      theme_module: theme_module,
      cart_count: 0,
      __changed__: nil
    }
    |> theme_module.render_home()
    |> rendered_to_string()
  end
end
