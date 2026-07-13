defmodule Emakola.Themes.SpotlightSectionsTest do
  # async: false — registers Spotlight through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "spotlight/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Sections, Spotlight, ThemeResolver}

  @section_keys [
    "spotlight/hero",
    "spotlight/benefits",
    "spotlight/ingredients",
    "spotlight/testimonials",
    "spotlight/closing_cta",
    "spotlight/newsletter"
  ]

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Spotlight])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  defp seeded_store do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "spotlight"}})
    create_category!(store, %{name: "Drinks"})
    product = create_product!(store, %{title: "Lively Drink", status: :active})
    create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    store
  end

  defp render_home(store) do
    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.read!(authorize?: false)

    categories = Emakola.Catalog.list_root_categories!(store.id)

    %{
      store: store,
      products: products,
      categories: categories,
      theme: ThemeResolver.resolve(store.theme_config || %{}, store),
      cart_count: 0,
      __changed__: nil
    }
    |> Spotlight.render_home()
    |> rendered_to_string()
  end

  # ── characterization: today's home, block by block ──────────────
  #
  # Pins the storefront output the merchant sees now. Every literal below
  # is lifted verbatim from the pre-section markup, so the sectionized home
  # must reproduce it exactly — landmark for landmark, in visual order.

  describe "home render" do
    test "renders every block's landmark copy, one h1, in today's visual order" do
      html = render_home(seeded_store())

      # Hero — the overline, the hero product as the page's h1, tagline, CTA
      assert html =~ "The one you reach for"
      assert html =~ ~r/<h1[^>]*>\s*Lively Drink\s*<\/h1>/
      assert html =~ "Clean, honest, and made to be part of your everyday rhythm."
      assert html =~ "Choose yours"

      # Benefits (theme.trust)
      assert html =~ ~s(id="benefits")
      assert html =~ "What makes it different"
      assert html =~ "Radical transparency"
      assert html =~ "Clear components, clearly listed — nothing hidden."

      # Ingredients — the count is derived from Spotlight.ingredients/0
      assert html =~ ~s(id="ingredients")
      assert html =~ "#{length(Spotlight.ingredients())} reasons it works"
      assert html =~ "Made simply"
      assert html =~ "Fairly priced"

      # Testimonials — the invented ones ("Ama D., Accra") are GONE. This store
      # has no real reviews, so the section does not render at all.
      refute html =~ ~s(id="testimonials")
      refute html =~ "What buyers say"
      refute html =~ "Ama D."
      refute html =~ "Exactly what I was looking for. Simple, reliable, and it just works."

      # Closing CTA (theme.closing_cta)
      assert html =~ "One product, done properly."
      assert html =~ "If you only make one thing, make it count."
      assert html =~ "Get yours"

      # Newsletter (theme.newsletter)
      assert html =~ "Stay in the loop"
      assert html =~ "New drops and members-only offers, straight to your inbox."
      assert html =~ "Subscribe"

      # The hero owns the page's only h1
      assert length(String.split(html, "<h1")) == 2

      # Visual order: hero -> benefits -> ingredients -> testimonials
      #            -> closing CTA -> newsletter
      assert String.match?(
               html,
               ~r/The one you reach for.*What makes it different.*reasons it works.*One product, done properly\..*Stay in the loop/s
             )
    end

    test "the hero funnels to the hero product's page" do
      store = seeded_store()

      html = render_home(store)

      assert html =~ ~s(href="/s/#{store.slug}/products/lively-drink")
    end

    test "an empty store keeps its composure — coming-soon hero, no h1 loss" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "spotlight"}})

      html = render_home(store)

      assert html =~ "Our product launches soon — check back shortly."
      # With no product the hero falls back to the theme's own title
      assert html =~ ~r/<h1[^>]*>\s*One product\.\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # The rest of the page still stands
      assert html =~ "What makes it different"
      assert html =~ "Stay in the loop"
    end

    test "keeps Spotlight's chrome: theme styles, nav, footer" do
      store = seeded_store()

      html = render_home(store)

      assert html =~ "spot-body"
      assert html =~ ~s(href="/s/#{store.slug}/cart")
      assert html =~ "Benefits"
      assert html =~ "Ingredients"
      assert html =~ ~r/<footer/
      assert html =~ "All rights reserved."
    end

    test "the theme's section toggles still hide their blocks" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "spotlight",
            "sections" => %{
              "why_us" => false,
              "testimonials" => false,
              "closing_cta" => false,
              "newsletter" => false
            }
          }
        })

      html = render_home(store)

      refute html =~ "What makes it different"
      refute html =~ "What buyers say"
      refute html =~ "One product, done properly."
      refute html =~ "Stay in the loop"
      # Ingredients has no toggle today — it always renders
      assert html =~ "reasons it works"
    end
  end

  # ── section contract ────────────────────────────────────────────

  describe "sections/0" do
    test "lists the six home sections in visual order, hero first" do
      assert Enum.map(Spotlight.sections(), & &1.key()) == @section_keys
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Spotlight.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section declares a human label" do
      for section <- Spotlight.sections() do
        assert is_binary(section.label()) and section.label() != ""
      end
    end
  end

  describe "registry" do
    test "Spotlight is sectionized and every section key resolves" do
      assert Sections.sectionized?(Spotlight)

      for section <- Spotlight.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  # ── merchant settings override the theme-config copy ────────────

  describe "settings" do
    test "a merchant heading replaces the theme-config copy, block by block" do
      store = seeded_store()
      theme = ThemeResolver.resolve(store.theme_config || %{}, store)

      overrides = [
        {Spotlight.Sections.Benefits, "heading", "Why it wins", "What makes it different"},
        {Spotlight.Sections.Newsletter, "heading", "Get the drops", "Stay in the loop"},
        {Spotlight.Sections.ClosingCta, "heading", "Make it count", "One product, done properly."}
      ]

      for {section, key, custom, default_copy} <- overrides do
        html = render_section(section, store, theme, %{key => custom})

        assert html =~ custom, "#{inspect(section)} ignored its #{key} setting"
        refute html =~ default_copy
      end
    end

    test "blank settings fall back to today's theme-config copy" do
      store = seeded_store()
      theme = ThemeResolver.resolve(store.theme_config || %{}, store)

      assert render_section(Spotlight.Sections.Benefits, store, theme) =~
               "What makes it different"

      assert render_section(Spotlight.Sections.Newsletter, store, theme) =~ "Stay in the loop"
    end
  end

  defp render_section(section, store, theme, overrides \\ %{}) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    %{
      store: store,
      products: [],
      categories: [],
      theme: theme,
      cart_count: 0,
      settings: Map.merge(defaults, overrides),
      section_meta: %{},
      __changed__: nil
    }
    |> section.render()
    |> rendered_to_string()
  end
end
