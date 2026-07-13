defmodule Emakola.Themes.PharmacySectionsTest do
  @moduledoc """
  Characterization + contract tests for the Pharmacy theme's home.

  The "home render" block was written against the pre-section home and must
  keep passing verbatim after the sectionization: it pins today's copy, the
  single h1, and the visual order of every block. A landmark that moves is a
  storefront regression, not a stale test.
  """

  # async: false — registers Pharmacy through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "pharmacy/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{HomeSections, Pharmacy, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Pharmacy])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  # ── helpers ─────────────────────────────────────────────────────

  # Stat items only ever reach the markup as atom-keyed maps (the theme's
  # `stats.items` default is [] — see Pharmacy.defaults/0), so the fixture
  # supplies them the way the markup reads them.
  @stat_items [
    %{icon: "verified_user", value: "12", label: "Years serving Accra"}
  ]

  defp seed_store! do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "pharmacy"}})

    create_category!(store, %{name: "Cough Syrups"})

    for {title, price} <- [
          {"Paracetamol 500mg", 1200},
          {"Vitamin C Chewables", 2500},
          {"Digital Thermometer", 8900},
          {"Antiseptic Wipes", 1500},
          {"Blood Pressure Monitor", 45_000},
          {"Herbal Throat Lozenges", 900}
        ] do
      product = create_product!(store, %{title: title, status: :active})
      create_variant!(product, store, %{price: price, stock_quantity: 5})
    end

    store
  end

  defp load_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.read!(authorize?: false)
  end

  defp render_home(store, config_overrides \\ %{}, opts \\ []) do
    theme =
      %{"theme" => "pharmacy"}
      |> Map.merge(config_overrides)
      |> ThemeResolver.resolve(store)

    store =
      case Keyword.fetch(opts, :layout) do
        {:ok, entries} -> %{store | theme_config: saved_layout_config(store, entries)}
        :error -> store
      end

    %{
      store: store,
      products: load_products(store),
      categories: Emakola.Catalog.list_root_categories!(store.id),
      theme: theme,
      cart_count: 0,
      __changed__: nil
    }
    |> Pharmacy.render_home()
    |> rendered_to_string()
  end

  # ── characterization: today's home, block by block ──────────────

  describe "home render" do
    test "renders every block with today's copy, in today's order, under one h1" do
      store = seed_store!()
      # The grid renders the products the trending strip dropped
      # (Enum.drop(products, 4)), so the fifth product's title is the grid's
      # own landmark.
      grid_title = store |> load_products() |> Enum.at(4) |> Map.fetch!(:title)

      html = render_home(store, %{"stats" => %{"items" => @stat_items}})

      # Hero — the page's single h1
      assert html =~ "Pharmacy you can trust"
      assert html =~ "Professional Pharmacy Services You Can Trust"
      assert length(String.split(html, "<h1")) == 2

      # Stats strip (renders only because the fixture supplies real numbers)
      assert html =~ "Your Trusted Healthcare Service"
      assert html =~ "Years serving Accra"

      # Trending products
      assert html =~ "Trending now"
      assert html =~ "Trending products for you"
      assert html =~ "See all"

      # Highlight feature cards
      assert html =~ "Shop now"

      # Category pill strip
      assert html =~ "Cough Syrups"

      # Product grid (the "more" products the trending strip dropped)
      assert html =~ grid_title

      # Trust strip
      assert html =~ "Licensed &amp; Trusted"
      assert html =~ "Verified pharmacy. Genuine medicines. Discreet delivery."

      # Newsletter
      assert html =~ "Stay healthy, stay informed"
      assert html =~ "Enter your email"

      # Visual order: hero -> stats -> trending -> highlights -> categories
      # -> grid -> trust -> newsletter
      assert String.match?(
               html,
               ~r/Pharmacy you can trust.*Your Trusted Healthcare Service.*Trending products for you.*Shop now.*Cough Syrups.*#{Regex.escape(grid_title)}.*Licensed &amp; Trusted.*Stay healthy, stay informed/s
             )
    end

    test "prices render from integer minor units" do
      store = seed_store!()

      html = render_home(store)

      # 1200 pesewas -> GH₵ 12
      assert html =~ "GH₵ 12"
    end

    test "the stats strip stays hidden when the merchant supplies no numbers" do
      store = seed_store!()

      html = render_home(store)

      refute html =~ "Your Trusted Healthcare Service"
      # …while the rest of the page is untouched
      assert html =~ "Trending products for you"
    end

    test "a section switched off the legacy way stays off" do
      store = seed_store!()

      html = render_home(store, %{"sections" => %{"newsletter" => false}})

      refute html =~ "Stay healthy, stay informed"
      assert html =~ "Licensed &amp; Trusted"
    end

    test "an empty store renders the chrome without the product blocks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "pharmacy"}})

      html = render_home(store)

      refute html =~ "Trending products for you"
      refute html =~ "Shop now"
      # Hero, trust, newsletter and the chrome still stand
      assert html =~ "Professional Pharmacy Services You Can Trust"
      assert html =~ "Licensed &amp; Trusted"
      assert html =~ "Stay healthy, stay informed"
    end

    test "carries Pharmacy's own chrome: nav and forest-green footer" do
      store = seed_store!()

      html = render_home(store)

      assert html =~ ~s(href="/s/#{store.slug}/cart")
      assert html =~ "Shop Now"
      assert html =~ "pharmacy-body"
      assert html =~ ~r/<footer[^>]*bg-\[#14543E\]/
      assert html =~ "Designed by Makola"
    end
  end

  # ── section contract ────────────────────────────────────────────

  describe "sections/0" do
    test "lists the eight home sections in today's visual order, hero first" do
      assert Enum.map(Pharmacy.sections(), & &1.key()) == [
               "pharmacy/hero",
               "pharmacy/stats",
               "pharmacy/trending",
               "pharmacy/highlight_cards",
               "pharmacy/category_strip",
               "pharmacy/product_grid",
               "pharmacy/trust",
               "pharmacy/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Pharmacy.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry" do
      assert Sections.sectionized?(Pharmacy)

      for section <- Pharmacy.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  # ── editor settings ─────────────────────────────────────────────

  describe "merchant settings" do
    test "a merchant's section settings replace the theme copy they override" do
      store = seed_store!()
      [hero, stats, trending, highlights, categories, grid, trust, newsletter] = layout()

      html =
        render_home(store, %{"stats" => %{"items" => @stat_items}},
          layout: [
            put_settings(hero, %{"title" => "Your neighbourhood chemist"}),
            put_settings(stats, %{"heading" => "By the numbers"}),
            put_settings(trending, %{"heading" => "In demand this week"}),
            highlights,
            categories,
            grid,
            put_settings(trust, %{"title" => "Regulated and registered"}),
            put_settings(newsletter, %{"button_text" => "Join"})
          ]
        )

      assert html =~ "Your neighbourhood chemist"
      refute html =~ "Professional Pharmacy Services You Can Trust"
      assert html =~ "By the numbers"
      assert html =~ "In demand this week"
      assert html =~ "Regulated and registered"
      assert html =~ "Join"
    end

    test "a merchant can reorder and switch off sections" do
      store = seed_store!()
      [hero, _stats, trending, _highlights, _categories, _grid, trust, newsletter] = layout()

      html =
        render_home(store, %{},
          layout: [trust, hero, trending, Map.put(newsletter, "enabled", false)]
        )

      assert String.match?(
               html,
               ~r/Licensed &amp; Trusted.*Pharmacy you can trust.*Trending products for you/s
             )

      refute html =~ "Stay healthy, stay informed"
    end
  end

  defp layout, do: HomeSections.default_layout(Pharmacy)

  defp put_settings(entry, settings), do: Map.put(entry, "settings", settings)

  defp saved_layout_config(store, entries) do
    Map.put(store.theme_config || %{}, "home_sections", %{"v" => 1, "pharmacy" => entries})
  end
end
