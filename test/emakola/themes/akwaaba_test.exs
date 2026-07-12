defmodule Emakola.Themes.AkwaabaTest do
  @moduledoc """
  Akwaaba is the photo-led theme, so most of what can go wrong here is about
  data the merchant does not have yet: no photos, no reviews, no description.
  These tests hold the line on the two rules that matter most —

  * the hero must never open on an empty slab (it falls back through merchant
    upload → first product photo → type), and
  * the theme must never invent social proof it does not have.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Akwaaba
  alias Emakola.Themes.Akwaaba.Sections.{Categories, Hero, Testimonials}
  alias Emakola.Themes.Akwaaba.Shared

  @store %{
    slug: "akwaaba",
    name: "Adjoa Atelier",
    currency: "GHS",
    description: nil,
    whatsapp_number: nil
  }

  defp product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Ankara Wrap Dress",
        slug: "ankara-wrap-dress",
        description: nil,
        min_price: 5800,
        max_price: 5800,
        images: [],
        variants: [],
        avg_rating: nil,
        review_count: 0,
        category_id: "cat-1"
      },
      attrs
    )
  end

  defp render_section(section, assigns, overrides \\ %{}) do
    defaults = for s <- section.settings_schema(), into: %{}, do: {s.key, s.default}

    assigns
    |> Map.put(:settings, Map.merge(defaults, overrides))
    |> Map.put(:__changed__, nil)
    |> section.render()
    |> rendered_to_string()
  end

  describe "theme module" do
    test "identity and renderers" do
      assert Akwaaba.id() == "akwaaba"
      assert Akwaaba.name() == "Akwaaba"
      assert Akwaaba.renderer(:home) == Emakola.Themes.Akwaaba.Home
      assert Akwaaba.renderer(:product_list) == Emakola.Themes.Akwaaba.ProductList
      assert Akwaaba.renderer(:product_detail) == Emakola.Themes.Akwaaba.ProductDetail

      assert [fonts] = Akwaaba.fonts()
      assert fonts =~ "Playfair+Display"
      assert fonts =~ "display=swap"
    end

    test "sections are listed in visual order, hero first" do
      assert Enum.map(Akwaaba.sections(), & &1.key()) == [
               "akwaaba/hero",
               "akwaaba/usp",
               "akwaaba/categories",
               "akwaaba/collection",
               "akwaaba/wordmark",
               "akwaaba/editorial",
               "akwaaba/testimonials",
               "akwaaba/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce against" do
      for section <- Akwaaba.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end
  end

  describe "hero — photo-fallback, never an empty slab" do
    test "with a catalogue it carries the first product's photograph and its price" do
      html =
        render_section(Hero, %{
          store: @store,
          products: [product(%{images: [%{url: "/uploads/dress.jpg"}]})],
          categories: []
        })

      assert html =~ "/uploads/dress.jpg"
      assert html =~ "Ankara Wrap Dress"
      assert html =~ "GH₵ 58"
      assert html =~ ~s(id="akwaaba-hero-heading")
    end

    test "with no catalogue at all it still renders the store name as the h1" do
      html = render_section(Hero, %{store: @store, products: [], categories: []})

      assert html =~ "Adjoa Atelier"
      assert html =~ ~s(id="akwaaba-hero-heading")
      refute html =~ "<img"
    end

    test "a merchant's remote hero URL is refused — a src from settings is an XSS sink" do
      html =
        render_section(
          Hero,
          %{store: @store, products: [], categories: []},
          %{"image_url" => "https://evil.example/x.jpg"}
        )

      refute html =~ "evil.example"
    end
  end

  describe "the honesty gate — no invented social proof" do
    test "a store with no reviews shows real payment rails, not a fabricated rating" do
      html = render_section(Hero, %{store: @store, products: [product()], categories: []})

      assert html =~ "MTN MoMo"
      refute html =~ "from 0 reviews"
      # No stars, no invented averages, no "27K happy customers".
      refute html =~ ~r/\d+\.\d+\s*<\/span>\s*<span[^>]*>\s*from/
    end

    test "a store with real reviews shows the real average and count" do
      html =
        render_section(Hero, %{
          store: @store,
          products: [product(%{avg_rating: 4.5, review_count: 2})],
          categories: []
        })

      assert html =~ "4.5"
      assert html =~ "from 2 reviews"
    end

    test "testimonials render only from real reviews — no reviews, no section" do
      empty = render_section(Testimonials, %{store: @store, products: [product()]})
      assert empty == "" or not (empty =~ "What shoppers say")

      real =
        render_section(Testimonials, %{
          store: @store,
          products: [product(%{avg_rating: 5.0, review_count: 3})]
        })

      assert real =~ "What shoppers say"
      assert real =~ "from 3 reviews"
    end
  end

  describe "category tiles" do
    test "a category with no photograph still renders a designed tile, not a hole" do
      category = %{id: "cat-9", name: "Jewellery", slug: "jewellery"}

      html =
        render_section(Categories, %{
          store: @store,
          products: [],
          categories: [category]
        })

      assert html =~ "Jewellery"
      assert html =~ "View collection"
      # the designed fallback ground, not an empty box
      assert html =~ "from-[#F3D3C0]"
    end

    test "no categories at all → no section" do
      html = render_section(Categories, %{store: @store, products: [], categories: []})
      refute html =~ "Shop by category"
    end

    test "a tile wears the store's real category cover, even when no product on the page is in it" do
      # The page only ever loads a capped product preview; the cover comes from
      # the catalogue itself, so a category outside that preview is still shown.
      category = %{id: "cat-9", name: "Jewellery", slug: "jewellery"}

      html =
        render_section(Categories, %{
          store: @store,
          products: [],
          categories: [category],
          category_photos: %{"cat-9" => "/uploads/pendant.jpg"}
        })

      assert html =~ "/uploads/pendant.jpg"
      refute html =~ "from-[#F3D3C0]"
    end

    test "a tile never wears a cover belonging to a different category" do
      category = %{id: "cat-food", name: "Food", slug: "food"}

      html =
        render_section(Categories, %{
          store: @store,
          products: [],
          categories: [category],
          category_photos: %{"cat-apparel" => "/uploads/dress.jpg"}
        })

      refute html =~ "/uploads/dress.jpg"
      assert html =~ "from-[#F3D3C0]"
    end
  end

  describe "product card" do
    test "browse-only on the list page — that LiveView has no add_to_cart handler" do
      html =
        %{product: product(), store: @store, show_add: false, __changed__: nil}
        |> Shared.product_card()
        |> rendered_to_string()

      refute html =~ "phx-click"
      assert html =~ "Ankara Wrap Dress"
    end

    test "a sale badge appears only when a real compare_at_price backs it" do
      honest =
        %{
          product:
            product(%{
              variants: [
                %{price: 5800, compare_at_price: 7000, track_inventory: false, stock_quantity: 5}
              ]
            }),
          store: @store,
          __changed__: nil
        }
        |> Shared.product_card()
        |> rendered_to_string()

      assert honest =~ "Sale"
      assert honest =~ "GH₵ 70"

      plain =
        %{
          product:
            product(%{
              variants: [
                %{price: 5800, compare_at_price: nil, track_inventory: false, stock_quantity: 5}
              ]
            }),
          store: @store,
          __changed__: nil
        }
        |> Shared.product_card()
        |> rendered_to_string()

      refute plain =~ "Sale"
    end
  end

  describe "home renders through the section renderer" do
    setup do
      Application.put_env(:emakola, :extra_sectionized_themes, [Akwaaba])
      on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
      :ok
    end

    test "the whole page composes: one h1, its own nav with a desktop cart, its own footer" do
      {_merchant, store} = create_merchant_with_store!()
      create_category!(store, %{name: "Apparel"})
      item = create_product!(store, %{title: "Kente Kaftan", status: :active})
      create_variant!(item, store, %{price: 12_345, stock_quantity: 5})

      html =
        Emakola.Themes.Akwaaba.Home.render(%{
          __changed__: nil,
          store: store,
          theme: Akwaaba.defaults(),
          products:
            Emakola.Catalog.Product
            |> Ash.read!(authorize?: false, tenant: store.id)
            |> Ash.load!(
              [:variants, :images, :min_price, :max_price, :avg_rating, :review_count],
              authorize?: false,
              tenant: store.id
            ),
          categories: Emakola.Catalog.Category |> Ash.read!(authorize?: false, tenant: store.id),
          cart_count: 0
        })
        |> rendered_to_string()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~s(aria-label="Search products")
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "GH₵ 123.45"
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(href="#akwaaba-content")
    end
  end
end
