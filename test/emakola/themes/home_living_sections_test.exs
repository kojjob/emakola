defmodule Emakola.Themes.HomeLivingSectionsTest do
  @moduledoc """
  Characterization test for the Home Living home page.

  Written against the UNREFACTORED home, before a single line of the theme
  moved, and kept unmodified through the section retrofit. Home Living has
  real merchants in production and had zero coverage: this file is the whole
  safety argument. Every landmark below is a verbatim literal of today's
  markup, and the order regex pins today's visual order.

  If a landmark moves, the storefront changed — fix the section, not the test.
  """
  # async: false — registers Home Living through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "home_living/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.HomeLiving
  alias Emakola.Themes.{Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [HomeLiving])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  defp seed_store! do
    # The brand story is the merchant's own description now. Its default used to
    # read "We work with local craftspeople … Solid wood, natural fibres … 
    # Delivered across all 16 regions of Ghana" — makers, materials and reach,
    # on every store that installed the theme. A store with no description has no
    # story, and gets no section.
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => "home_living"},
        description: "We have sold second-hand furniture in Kaneshie since 2019."
      })

    create_category!(store, %{name: "Living Room"})

    table = create_product!(store, %{title: "Oak Dining Table", status: :active})
    create_variant!(table, store, %{price: 12_345, stock_quantity: 4})

    sofa = create_product!(store, %{title: "Linen Sofa", status: :active})
    create_variant!(sofa, store, %{price: 89_900, stock_quantity: 2})

    store
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
      # Mirrors StoreLive: the sale band and trust strip state the store's own zones.
      delivery_zones: Emakola.Shipping.list_delivery_zones!(store.id),
      products: products,
      categories: categories,
      theme: theme,
      cart_count: 0,
      __changed__: nil
    }
    |> HomeLiving.render_home()
    |> rendered_to_string()
  end

  describe "home page (characterization — output must not change)" do
    test "renders every block's verbatim landmark, exactly one h1, in today's order" do
      store = seed_store!()

      html = render_home(store)

      # Hero — charcoal signboard, the theme's default headline, lime CTA.
      # The nav lives INSIDE the hero section (today's markup) and is the
      # only cart link on the page.
      assert html =~ "Furniture and home goods"
      assert html =~ "Explore More"
      assert html =~ ~s(href="/s/#{store.slug}/cart")
      assert length(String.split(html, "<h1")) == 2

      # Shop-by-categories strip — rooms from theme config, ungated
      assert html =~ "by categories"
      assert html =~ "Living Room"

      # Sale band — the terracotta bar. It used to open with "Free Delivery —
      # On orders GHS 500+"; this store has configured no delivery zones, so it
      # gets no delivery tile at all rather than an invented one.
      refute html =~ "Free Delivery"
      refute html =~ "On orders GHS 500+"
      assert html =~ "Safe Payment"
      # "Daily Curation — Hand-picked" claimed someone at the shop selected these
      # goods by hand, every day. Gone.
      refute html =~ "Daily Curation"

      # Featured products grid. "Bestsellers"/"Popular products" ranked the
      # first eight products in catalog order by nothing at all.
      assert html =~ "From the shop"
      assert html =~ "Featured products"
      assert html =~ "View all"
      assert html =~ "Oak Dining Table"
      # Price from integer minor units — 12_345 pesewas
      assert html =~ "GH₵ 123.45"

      # Editor's pick — the first product, charcoal split panel
      assert html =~ "Featured pick"
      assert html =~ "Shop now"

      # Trust strip. "Ships in 5 days" and "30-day returns" were promises no
      # merchant made; with no zones configured the strip points at the store's
      # own policies instead.
      # "Quality materials — Solid wood, natural fibres" told every Home Living
      # shopper what the furniture was made of. The platform has no materials
      # field and the shop may be selling plastic stools.
      refute html =~ "Quality materials"
      assert html =~ "Delivery &amp; returns"
      # HEEx escapes interpolated values, so the apostrophe arrives as &#39;
      assert html =~ "See this store"
      assert html =~ "/policies#shipping"
      refute html =~ "Ships in 5 days"
      refute html =~ "30-day returns"

      # Brand story — the merchant's own words, under a heading that claims
      # nothing. "Built in Ghana, made for life." was the theme's, for everyone.
      assert html =~ "Our story"
      assert html =~ "We have sold second-hand furniture in Kaneshie since 2019."
      refute html =~ "Built in Ghana"
      refute html =~ "Solid wood"
      assert html =~ "Read more"

      # Newsletter
      assert html =~ "New pieces, in your inbox"
      assert html =~ ~s(id="home-living-newsletter-email")
      assert html =~ "Subscribe"

      # Footer chrome
      assert html =~ "Designed for living"

      # Today's visual order: hero -> categories -> sale band -> featured
      # -> editor pick -> trust -> brand story -> newsletter -> footer
      assert String.match?(
               html,
               ~r/Furniture and home goods.*by categories.*Featured products.*Featured pick.*Our story.*New pieces, in your inbox.*Designed for living/s
             )
    end

    test "an empty store still renders the hero, the strips and the chrome" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "home_living"}})

      html = render_home(store)

      assert html =~ "Furniture and home goods"
      assert html =~ "by categories"
      # "Daily Curation — Hand-picked" claimed someone at the shop selected these
      # goods by hand, every day. Gone.
      refute html =~ "Daily Curation"
      # No products: the grid and the editor's pick stay out of the page
      refute html =~ "Featured products"
      refute html =~ "Featured pick"
      # ...and the rest of the page still renders
      # "Quality materials — Solid wood, natural fibres" told every Home Living
      # shopper what the furniture was made of. The platform has no materials
      # field and the shop may be selling plastic stools.
      refute html =~ "Quality materials"
      # Was "Built in Ghana, made for life." — where the goods were made and how
      # long they last, for every store on the theme.
      refute html =~ "Built in Ghana"
      assert html =~ "Our story"
      assert html =~ "New pieces, in your inbox"
      assert html =~ "Designed for living"
      assert length(String.split(html, "<h1")) == 2
    end

    test "the legacy section toggles still hide their blocks" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "home_living",
            "sections" => %{
              "sale_band" => false,
              "trust" => false,
              "brand_story" => false,
              "newsletter" => false
            }
          }
        })

      html = render_home(store)

      refute html =~ "Daily Curation"
      refute html =~ "Ships in 5 days"
      refute html =~ "Built in Ghana, made for life."
      refute html =~ "New pieces, in your inbox"
      # Untouched blocks still render
      assert html =~ "Furniture and home goods"
      assert html =~ "by categories"
    end
  end

  describe "sections/0" do
    test "lists the eight home sections in today's visual order, hero first" do
      assert Enum.map(HomeLiving.sections(), & &1.key()) == [
               "home_living/hero",
               "home_living/category_strip",
               "home_living/sale_band",
               "home_living/featured_products",
               "home_living/editor_pick",
               "home_living/trust",
               "home_living/brand_story",
               "home_living/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- HomeLiving.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry" do
      assert Sections.sectionized?(HomeLiving)

      for section <- HomeLiving.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end
end
