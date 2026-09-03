defmodule Emakola.Themes.BeautySectionsTest do
  @moduledoc """
  Characterization + contract tests for the Beauty theme's section retrofit.

  The `home render` block was written against the pre-retrofit `Beauty.Home`
  and must keep passing byte-for-byte afterwards: the retrofit moves markup
  into `Emakola.Themes.Beauty.Sections.*` without changing a single rendered
  landmark for a store that never touched the section editor.
  """

  # async: false — registers Beauty through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "beauty/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Beauty
  alias Emakola.Themes.{HomeSections, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Beauty])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  defp render_section(section, store, overrides) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    %{
      store: store,
      products: [],
      categories: [],
      testimonials: [],
      review_photos: [],
      theme: ThemeResolver.resolve(store.theme_config || %{}, store),
      settings: Map.merge(defaults, overrides),
      section_meta: %{},
      cart_count: 0,
      __changed__: nil
    }
    |> section.render()
    |> rendered_to_string()
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
    |> Beauty.render_home()
    |> rendered_to_string()
  end

  # The why-us cards are the merchant's own now. They used to ship "Proven
  # Effectiveness — dermatologist-tested formulas", "Eco-friendly Packaging —
  # recyclable glass and biodegradable inserts" and "Sourced from West African
  # shea, cocoa, and baobab": an efficacy claim, a packaging claim and a sourcing
  # claim, on every store that installed the theme. A store that writes none gets
  # no block, so the tests that expect one have to write something.
  @merchant_why_us %{
    "why_us" => %{
      "title" => "Why buy from us",
      "items" => [
        %{
          icon: "spa",
          title: "Small-batch shea",
          description: "Whipped in Tamale, 40 jars a week."
        }
      ]
    }
  }

  # The FAQ is the merchant's questions now. "Do you ship across Ghana?" and
  # "What is your return policy?" shipped as theme defaults, so every Beauty
  # store asked and answered them; a store that writes none gets no FAQ.
  @merchant_faq %{
    "faq" => %{
      "items" => [
        %{
          question: "Which courier do you use?",
          answer: "Yango within Accra; Ghana Post everywhere else."
        }
      ]
    }
  }

  # Four products: the newsletter joins the page at a full stall, so the
  # characterization store carries one.
  defp seeded_store(config \\ %{}) do
    theme_config = Map.merge(%{"theme" => "beauty"}, config)
    {_merchant, store} = create_merchant_with_store!(%{theme_config: theme_config})
    create_category!(store, %{name: "Shea Butters"})
    stock!(store)
    store
  end

  defp stock!(store) do
    for title <- ["Baobab Face Oil", "Shea Whip", "Cocoa Balm", "Baobab Hair Oil"] do
      product = create_product!(store, %{title: title, status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    end
  end

  # ── characterization: today's rendered home, landmark by landmark ──

  describe "home render" do
    test "every visual block renders its own copy, verbatim" do
      store = seeded_store(Map.merge(@merchant_why_us, @merchant_faq))
      html = render_home(store)

      # Nav (chrome, inside the hero band)
      assert html =~ "Book Now"
      # Hero — the store's name, never "Elevate Your Essence". The "Botanical
      # Beauty" badge and the "Beauty, Personalized Care" card spoke for jars
      # the theme had never seen.
      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
      refute html =~ "Elevate Your Essence"
      refute html =~ "Botanical Beauty"
      refute html =~ "Beauty, Personalized Care"
      assert html =~ "Shop the Collection"
      assert html =~ "Our Story"
      # Featured products
      assert html =~ "Our Products"
      assert html =~ "Curated for your routine"
      assert html =~ "Baobab Face Oil"
      assert html =~ "GH₵ 123.45"
      assert html =~ "See all products"
      # Why us — the merchant's cards, never the theme's
      assert html =~ "Why buy from us"
      assert html =~ "Small-batch shea"
      refute html =~ "Proven Effectiveness"
      refute html =~ "Eco-friendly Packaging"
      # Testimonials — the invented ones ("Akua M., Accra") are GONE. With no
      # real reviews on this store the section does not render at all, so the
      # landmark here is their absence.
      refute html =~ "Akua M."
      refute html =~ "What buyers say"
      # FAQ — the merchant's question; "Do you ship across Ghana?" was the theme's
      assert html =~ "Frequently Asked Questions"
      assert html =~ "Which courier do you use?"
      refute html =~ "Do you ship across Ghana?"
      # Closing CTA
      assert html =~ "Ready when you are."
      assert html =~ "Shop Now"
      # Newsletter
      assert html =~ "Join the list"
      assert html =~ "Subscribe"
      # Footer (chrome)
      # "Crafted with care" sat in the footer of every Beauty store — who made
      # the products, asserted by the theme. Gone; the merchant's tagline shows
      # there instead when they have written one.
      refute html =~ "Crafted with care"
    end

    test "the hero owns the page's single h1" do
      store = seeded_store()
      html = render_home(store)

      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
    end

    test "the blocks keep today's visual order" do
      store = seeded_store(Map.merge(@merchant_why_us, @merchant_faq))
      html = render_home(store)

      assert String.match?(
               html,
               ~r/Book Now.*<h1.*#{Regex.escape(store.name)}.*Curated for your routine.*Why buy from us.*Frequently Asked Questions.*Ready when you are.*Join the list/s
             )
    end

    test "the brand strip stays off — its section default is disabled" do
      html = render_home(seeded_store())

      refute html =~ "As featured in"
    end

    test "a section switched off in theme_config disappears, as it does today" do
      store =
        seeded_store(
          Map.merge(@merchant_faq, %{"sections" => %{"testimonials" => false, "faq" => false}})
        )

      html = render_home(store)

      refute html =~ "What buyers say"
      refute html =~ "Frequently Asked Questions"
      refute html =~ "Which courier do you use?"
      # The rest of the page is untouched
      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
      assert html =~ "Join the list"
    end

    # Switching the strip on used to be enough to put five italic "As featured
    # in" placeholders on the page — press coverage this shop had never had.
    # The toggle alone buys nothing now: the strip lists the publications the
    # merchant names, and a merchant who has named none has no strip.
    test "switching the brand strip on does not conjure press coverage" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "beauty", "sections" => %{"featured_in" => true}}
        })

      html = render_home(store)

      refute html =~ "As featured in"
      # ...and the rest of the page is untouched
      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
    end

    test "the brand strip names the publications the merchant named" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "beauty", "sections" => %{"featured_in" => true}}
        })

      html =
        render_section(Beauty.Sections.FeaturedIn, store, %{
          "publications" => "Vogue Ghana, Citi FM"
        })

      assert html =~ "As featured in"
      assert html =~ "Vogue Ghana"
      assert html =~ "Citi FM"
    end

    test "a store with no products renders the page without the products block" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "beauty"}})

      html = render_home(store)

      refute html =~ "Curated for your routine"
      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
      # A shop with nothing to sell has no news; the list opens at four products.
      refute html =~ ~s(phx-submit="subscribe_newsletter")
      # The why-us block is gone with the products: its three cards were claims
      # about formulation, packaging and sourcing that no merchant had written.
      refute html =~ "Why buy from us"
    end

    test "merchant hero and closing copy override the theme defaults" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "beauty",
            "hero" => %{"title" => "Glow, softly"},
            "closing_cta" => %{"title" => "Ready when you are"}
          }
        })

      html = render_home(store)

      assert html =~ ~r/<h1[^>]*>\s*Glow, softly\s*<\/h1>/
      assert html =~ "Ready when you are"
      refute html =~ "Elevate Your Essence"
      refute html =~ "Ready when you are."
    end

    test "a store with no description says nothing about itself" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "beauty"}})

      html = render_home(store)

      refute html =~ "Botanical skincare"
      refute html =~ "Each formula is thoughtfully designed"
      refute html =~ "Do you ship across Ghana?"
      refute html =~ "Frequently Asked Questions"
    end

    test "the merchant's description and tagline are the hero's and footer's words" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "beauty"},
          description: "Whipped shea from Tamale, forty jars a week.",
          tagline: "Small batches, every Friday."
        })

      html = render_home(store)

      assert html =~ "Whipped shea from Tamale, forty jars a week."
      assert html =~ "Small batches, every Friday."
    end
  end

  # ── section contract ────────────────────────────────────────────

  describe "sections/0" do
    test "lists the eight home sections in today's visual order, hero first" do
      assert Enum.map(Beauty.sections(), & &1.key()) == [
               "beauty/hero",
               "beauty/featured_in",
               "beauty/featured_products",
               "beauty/why_us",
               "beauty/testimonials",
               "beauty/faq",
               "beauty/closing_cta",
               "beauty/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Beauty.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      assert Sections.sectionized?(Beauty)

      for section <- Beauty.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  # ── merchant edits reach the extracted sections ─────────────────

  describe "a published layout" do
    test "its settings override the theme copy" do
      {merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "beauty"}})
      stock!(store)

      layout =
        Beauty
        |> HomeSections.default_layout()
        |> Enum.map(fn
          %{"type" => "beauty/hero"} = entry ->
            %{entry | "settings" => %{"headline" => "Softness, bottled"}}

          %{"type" => "beauty/newsletter"} = entry ->
            %{entry | "settings" => %{"heading" => "The ritual letter"}}

          entry ->
            entry
        end)

      {:ok, store} = HomeSections.put_layout(merchant, store, "beauty", layout)

      html = render_home(store)

      assert html =~ ~r/<h1[^>]*>\s*Softness, bottled\s*<\/h1>/
      assert html =~ "The ritual letter"
      refute html =~ "Elevate Your Essence"
      refute html =~ "Join the list"
    end

    test "a disabled entry drops its block, and reordering moves one" do
      {merchant, store} =
        create_merchant_with_store!(%{
          theme_config: Map.merge(%{"theme" => "beauty"}, @merchant_why_us)
        })

      [hero, featured_in, products, why_us | rest] = HomeSections.default_layout(Beauty)

      layout =
        [why_us, hero, featured_in, products | rest]
        |> Enum.map(fn
          %{"type" => "beauty/testimonials"} = entry -> %{entry | "enabled" => false}
          entry -> entry
        end)

      {:ok, store} = HomeSections.put_layout(merchant, store, "beauty", layout)

      html = render_home(store)

      refute html =~ "What buyers say"
      # why_us now stands before the hero
      assert String.match?(html, ~r/Why buy from us.*<h1[^>]*>\s*#{Regex.escape(store.name)}/s)
    end
  end
end
