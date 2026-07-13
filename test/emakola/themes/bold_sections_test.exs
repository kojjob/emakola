defmodule Emakola.Themes.BoldSectionsTest do
  # async: false — registers Bold through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "bold/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Bold, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Bold])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
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
    |> Bold.render_home()
    |> rendered_to_string()
  end

  defp seeded_store do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "bold"}})
    create_category!(store, %{name: "Fresh Peppers"})
    product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
    create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    store
  end

  # ── characterization: today's home output, block by block ────────
  #
  # Written against the pre-section Bold home and re-run unchanged after the
  # retrofit. Every literal below is verbatim from bold/home.ex — if one of
  # these moves, the storefront moved.

  describe "home render" do
    test "renders every visual block with today's exact copy, in today's order" do
      store = seeded_store()

      html = render_home(store)

      # Hero — the store name eyebrow, the theme's headline, the CTA
      assert html =~ store.name
      assert html =~ "The Edit"
      assert html =~ "Curated goods for the discerning eye"
      assert html =~ "Shop the Collection"
      assert html =~ ~s(id="bold-grid")

      # Category text links (editorial navigation)
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Fresh Peppers"

      # Featured — asymmetric bento grid
      assert html =~ "Featured"
      assert html =~ "Kente Tote Bag"

      # Editorial banner — full-width amber bar carrying the fallback line
      assert html =~ "Curated for those who appreciate the art of well-made things."
      assert html =~ ~s(class="bg-[#F59E0B]")

      # Products grid
      assert html =~ ~s(id="bold-shop-all")
      assert html =~ "The Collection"
      assert html =~ "View All"
      # Price: formatted from integer minor units
      assert html =~ "GH₵ 123.45"

      # Newsletter — dark band, amber CTA
      assert html =~ "Stay in the Know"
      assert html =~ "New drops, editorial picks, and exclusive access delivered to your inbox."

      # Exactly one h1 on the page — the hero's
      assert length(String.split(html, "<h1")) == 2

      # Today's visual order, as flat siblings
      assert String.match?(
               html,
               ~r/The Edit.*Product categories.*Featured.*art of well-made things.*The Collection.*Stay in the Know/s
             )
    end

    test "the home page keeps Bold's own chrome: nav, then sections, then footer" do
      store = seeded_store()

      html = render_home(store)

      # Dark editorial nav
      assert html =~ ~s(<header class="sticky top-0 z-50">)
      assert html =~ ~s(aria-label="Main navigation")
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      # Dark editorial footer
      assert html =~ "Quick Links"
      assert html =~ "All rights reserved."
      # Chrome order: nav -> hero -> footer
      assert String.match?(
               html,
               ~r/Main navigation.*The Edit.*All rights reserved/s
             )
    end

    test "the store description replaces the editorial banner's fallback line" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "bold"},
          description: "Hand-picked goods from Makola market."
        })

      html = render_home(store)

      assert html =~ "Hand-picked goods from Makola market."
      refute html =~ "Curated for those who appreciate the art of well-made things."
    end

    test "an empty store drops the category, featured and grid blocks, keeping the rest" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "bold"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ ~s(id="bold-shop-all")
      # Hero, banner and newsletter still stand
      assert html =~ "The Edit"
      assert html =~ "Curated for those who appreciate the art of well-made things."
      assert html =~ "Stay in the Know"
    end

    test "the home carries two subscribe forms — the newsletter band and the footer's" do
      store = seeded_store()

      html = render_home(store)

      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 3
    end
  end

  # ── section contract ────────────────────────────────────────────

  describe "sections/0" do
    test "lists the six home sections in today's visual order, hero first" do
      assert Enum.map(Bold.sections(), & &1.key()) == [
               "bold/hero",
               "bold/categories",
               "bold/featured",
               "bold/editorial_banner",
               "bold/product_grid",
               "bold/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Bold.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      assert Sections.sectionized?(Bold)

      for section <- Bold.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end
end
