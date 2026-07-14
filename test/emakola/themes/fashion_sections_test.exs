defmodule Emakola.Themes.FashionSectionsTest do
  @moduledoc """
  Fashion carries real merchants, so the retrofit to theme-native sections is
  guarded by a characterization test written against the PRE-retrofit home and
  left unchanged afterwards: same copy, same order, same single `<h1>`. If a
  landmark below moves, a live storefront moved with it.
  """

  # async: false — registers Fashion through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "fashion/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Fashion, Sections, ThemeResolver}

  @section_keys [
    "fashion/hero",
    "fashion/editorial_intro",
    "fashion/lookbook",
    "fashion/featured_products",
    "fashion/new_arrivals_band",
    "fashion/ugc",
    "fashion/brand_story",
    "fashion/newsletter"
  ]

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Fashion])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  # The new-arrivals band takes products 5..8, so a store needs more than four
  # products before the whole page is on screen.
  # The editorial intro and the brand story are the merchant's own words now.
  # They used to be theme defaults that credited two workshops which do not
  # exist ("the Mensah collective", "the Kwame house") and told every shopper the
  # clothes were "sewn in small batches by tailors and artisans across Accra".
  # A store that writes nothing gets neither section, so the tests that expect
  # them on the page have to write something.
  @merchant_story %{
    "editorial_intro" => %{
      "eyebrow" => "Volume IV · Drop No. 12",
      "title" => "Curated drops, made by hand.",
      "body" => "Every piece is cut and sewn by the four tailors in our Osu workshop."
    }
  }

  defp seeded_store!(config \\ %{}) do
    theme_config = Map.merge(%{"theme" => "fashion"}, config)
    {_merchant, store} = create_merchant_with_store!(%{theme_config: theme_config})
    create_category!(store, %{name: "Ankara"})

    for n <- 1..6 do
      product = create_product!(store, %{title: "Kente Wrap #{n}", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    end

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
      products: products,
      categories: categories,
      theme: theme,
      cart_count: 0,
      __changed__: nil
    }
    |> Fashion.render_home()
    |> rendered_to_string()
  end

  # ── characterization: today's storefront, landmark by landmark ──

  describe "home render (characterization)" do
    test "every visual block keeps its own copy, in today's order, under one h1" do
      html = render_home(seeded_store!(@merchant_story))

      # Magazine-cover hero — the page's only h1
      assert html =~ "The Spring Edit"
      assert html =~ "The new collection"
      assert html =~ "Shop the Drop"
      assert length(String.split(html, "<h1")) == 2

      # Editorial intro
      assert html =~ "Volume IV · Drop No. 12"
      assert html =~ "Curated drops, made by hand."

      # Lookbook 2x2 grid
      assert html =~ "Editor's picks."
      assert html =~ "Cover Look"
      assert html =~ "See all"

      # Featured products
      assert html =~ "The Edit"
      assert html =~ "Just dropped."
      assert html =~ "Kente Wrap 1"

      # New arrivals band
      assert html =~ "Back in stock, briefly."
      assert html =~ "Shop the Restock"

      # Brand story — the merchant's own, or absent. This store's description is
      # its story; "Sewn in Accra. Worn worldwide." was the theme's, for everyone.
      refute html =~ "Sewn in Accra."

      # Newsletter
      assert html =~ "First access. No noise."
      assert html =~ "Join the List"

      # Masthead footer
      # "Made in Ghana" sat in the footer of every Fashion store — a
      # country-of-origin claim for shops importing from anywhere.
      refute html =~ "Made in Ghana"

      # Prices are formatted from integer minor units
      assert html =~ "GH₵ 123.45"

      # The UGC strip is off by default — placeholder tiles, not real photos
      refute html =~ "Worn by you."

      # Flat visual order: hero -> editorial -> lookbook -> featured ->
      # new arrivals -> brand story -> newsletter -> footer
      assert String.match?(
               html,
               ~r/The Spring Edit.*Curated drops, made by hand\..*Editor's picks\..*Just dropped\..*Back in stock, briefly\..*First access\. No noise\./s
             )
    end

    test "the nav, cart and footer chrome survive the render" do
      store = seeded_store!()

      html = render_home(store)

      assert html =~ ~s(href="/s/#{store.slug}/cart")
      assert html =~ ~s(href="/s/#{store.slug}/products")
      assert html =~ store.name
      assert html =~ "Volume IV · #{DateTime.utc_now().year}"
    end

    test "an empty store keeps the hero and newsletter, and claims nothing" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fashion"}})

      html = render_home(store)

      assert html =~ "The new collection"
      assert html =~ "First access. No noise."
      # The editorial intro and brand story are gone: both were claims about who
      # made the clothes, and this merchant has made none.
      refute html =~ "Curated drops, made by hand."
      refute html =~ "Sewn in Accra."
      refute html =~ "small batches"
      # The product-fed blocks vanish rather than render empty frames
      refute html =~ "Editor's picks."
      refute html =~ "Just dropped."
      refute html =~ "Back in stock, briefly."
      assert length(String.split(html, "<h1")) == 2
    end

    test "a store description replaces the brand-story fallback prose" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "fashion"},
          description: "Ankara, cut and sewn in Osu."
        })

      html = render_home(store)

      assert html =~ "Ankara, cut and sewn in Osu."
      refute html =~ "We work with tailors and weavers across Ghana"
    end

    test "merchant theme copy overrides the defaults" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "fashion",
            "hero" => %{"title" => "Cloth with a name", "cta_text" => "See the drop"},
            "newsletter" => %{"title" => "The dispatch"}
          }
        })

      html = render_home(store)

      assert html =~ "Cloth with a name"
      assert html =~ "See the drop"
      assert html =~ "The dispatch"
      refute html =~ "Made by Tailors. Worn by You."
    end
  end

  # ── section contract ────────────────────────────────────────────

  describe "sections/0" do
    test "lists the eight home sections in today's visual order, hero first" do
      assert Enum.map(Fashion.sections(), & &1.key()) == @section_keys
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Fashion.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      assert Sections.sectionized?(Fashion)

      for section <- Fashion.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "section settings" do
    test "a merchant's per-section copy overrides the theme's" do
      store = seeded_store!()

      layout =
        Enum.map(Fashion.sections(), fn section ->
          settings =
            case section.key() do
              "fashion/hero" -> %{"heading" => "Cloth, cut close"}
              "fashion/newsletter" -> %{"heading" => "The dispatch"}
              _other -> %{}
            end

          %{
            "id" => section.key(),
            "type" => section.key(),
            "enabled" => true,
            "settings" => settings,
            "style" => %{}
          }
        end)

      store = put_layout!(store, layout)

      html = render_home(store)

      assert html =~ "Cloth, cut close"
      assert html =~ "The dispatch"
      refute html =~ "Made by Tailors. Worn by You."
      refute html =~ "First access. No noise."
    end

    test "a disabled section leaves the page, and the rest keep their order" do
      store = seeded_store!(@merchant_story)

      layout =
        for section <- Fashion.sections() do
          %{
            "id" => section.key(),
            "type" => section.key(),
            "enabled" => section.key() != "fashion/lookbook",
            "settings" => %{},
            "style" => %{}
          }
        end

      html = store |> put_layout!(layout) |> render_home()

      refute html =~ "Editor's picks."
      assert html =~ "The new collection"
      assert html =~ "Just dropped."

      assert String.match?(
               html,
               ~r/The Spring Edit.*Curated drops, made by hand\..*Just dropped\./s
             )
    end
  end

  defp put_layout!(store, layout) do
    config = Map.put(store.theme_config, "home_sections", %{"v" => 1, "fashion" => layout})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: config})
    |> Ash.update!(authorize?: false)
  end
end
