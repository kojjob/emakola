defmodule Emakola.Themes.AtelierSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Atelier, ThemeResolver}

  test "sections/0 lists the seven home sections in today's visual order" do
    keys = Enum.map(Atelier.sections(), & &1.key())

    assert keys == [
             "atelier/hero",
             "atelier/category_circles",
             "atelier/featured_products",
             "atelier/new_arrivals",
             "atelier/trust",
             "atelier/delivery_zones",
             "atelier/newsletter"
           ]
  end

  test "default render carries each section's landmark content" do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}})
    create_category!(store)
    # Six, not four: the featured bento takes five, and "More from the shop"
    # now shows only what is left over instead of repeating the catalogue.
    for _ <- 1..6, do: create_product!(store, %{status: :active})

    html = render_home(store)

    # Landmarks -- one distinctive literal per block, picked from the
    # CURRENT atelier/home.ex before extraction (Task 7 reuses these).
    # Hero -- the store speaks for itself: its own name is the h1. The theme
    # ships no invented headline for it to fall back to.
    assert html =~ store.name
    # Category Circles
    assert html =~ "Shop by Category"
    # Featured Products
    assert html =~ "Featured Masterpieces"
    # The overflow grid. It shows the OLDEST of the newest-first batch, so it
    # was never "New Arrivals" — it is simply more of the shop.
    assert html =~ "More from the shop"
    # Trust
    assert html =~ "We Accept"
    # Delivery Zones
    assert html =~ "Delivery across Ghana"
    # Newsletter -- falls back to the hardcoded literal because the theme's
    # newsletter map has no :heading key (only :title/:subtitle/:button_text)
    assert html =~ "Stay Updated."
  end

  describe "the hero speaks as the merchant, never for them" do
    test "a store that wrote nothing gets its own name as the h1 — no invented headline" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "atelier"},
          name: "Kwame Provisions"
        })

      create_product!(store, %{status: :active})

      html = render_home(store)

      assert html =~ ~r/<h1[^>]*>[^<]*Kwame Provisions/s

      # The copy Atelier used to ship in the merchant's voice. A shop selling
      # rice does not "craft trust" or curate a 2024 collection, and it never
      # said it did — this is the same lie as a fabricated review.
      refute html =~ "Crafting Trust"
      refute html =~ "Curating Excellence"
      refute html =~ "The 2024 Collection"
      refute html =~ "soul of West African craftsmanship"
      refute html =~ "Explore Masterpieces"
      refute html =~ "Meet the Artisans"
    end

    test "a store with no description gets no invented one" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}, description: nil})

      html = render_home(store)

      refute html =~ "Every piece tells a story"
    end

    test "the merchant's own words always win" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "atelier",
            "hero" => %{
              "title" => "Fresh stock, every Friday",
              "subtitle" => "Since 2011",
              "description" => "We sell rice, oil and shito."
            }
          }
        })

      html = render_home(store)

      assert html =~ "Fresh stock, every Friday"
      assert html =~ "Since 2011"
      assert html =~ "We sell rice, oil and shito."
    end
  end

  describe "the home grows with the catalogue" do
    test "one product: the featured card carries it alone" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}})
      create_category!(store)
      create_product!(store, %{title: "Kente Tote Bag", status: :active})

      html = render_home(store)

      assert html =~ "Featured Masterpieces"
      assert count(html, "Kente Tote Bag") == 1
      refute html =~ "More from the shop"
      refute html =~ "Shop by Category"
      refute html =~ ~s(phx-submit="subscribe_newsletter")
    end

    test "six products: the overflow grid shows only what the bento did not take" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}})

      products =
        for n <- 1..6, do: create_product!(store, %{title: "Product #{n}", status: :active})

      html = render_home(store)

      assert html =~ "More from the shop"
      # The featured card has no add-to-cart button; the five other products
      # get one card each, and no product id is on more than one card.
      assert count(html, ~s(phx-value-product-id=)) == 5

      for product <- products do
        assert count(html, ~s(phx-value-product-id="#{product.id}")) <= 1,
               "#{product.title} is on more than one card"
      end
    end

    test "the hero never borrows a product photo" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "atelier"}})
      product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
      image = create_image!(product, store, %{url: "https://s3.example.com/kente-tote.jpg"})

      html = render_home(store)

      assert count(html, image.url) == 1
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
    |> Atelier.render_home()
    |> rendered_to_string()
  end
end
