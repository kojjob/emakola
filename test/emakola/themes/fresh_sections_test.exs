defmodule Emakola.Themes.FreshSectionsTest do
  # async: false — registers Fresh through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "fresh/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  require Ash.Query

  alias Emakola.Themes.{Fresh, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Fresh])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  defp seed_store! do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}})
    create_category!(store, %{name: "Fresh Peppers"})
    product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
    create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

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
    |> Fresh.render_home()
    |> rendered_to_string()
  end

  # ── Characterization: today's home output, block by block ────────

  describe "home render" do
    test "renders every visual block with its own copy" do
      html = render_home(seed_store!())

      # Hero — the theme's own headline and CTA
      assert html =~ "Fresh to Your Door"
      assert html =~ "Start Shopping"
      # Category circles
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Shop by Category"
      assert html =~ "Fresh Peppers"
      # Featured picks
      assert html =~ "Today's Picks"
      # Delivery banner
      assert html =~ "Same-Day Delivery in Accra"
      assert html =~ "Order before noon and get your fresh produce delivered the same day."
      # Product grid
      assert html =~ ~s(id="fresh-shop-all")
      assert html =~ "Shop All Products"
      assert html =~ "Kente Tote Bag"
      # Price from integer minor units
      assert html =~ "GH₵ 123.45"
      # Newsletter — the only capture form on the page
      assert html =~ "Get Weekly Deals"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2
    end

    test "the hero owns the page's only h1" do
      html = render_home(seed_store!())

      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<h1[^>]*>\s*Fresh to Your Door\s*<\/h1>/
    end

    test "blocks render in today's visual order" do
      html = render_home(seed_store!())

      assert String.match?(
               html,
               ~r/Fresh to Your Door.*Shop by Category.*Today's Picks.*Same-Day Delivery in Accra.*fresh-shop-all.*Get Weekly Deals/s
             )
    end

    test "the chrome wraps the blocks: nav above, footer below" do
      html = render_home(seed_store!())

      assert html =~ ~s(aria-label="Search products")
      assert html =~ ~r/<a[^>]*href="\/s\/[^"]+\/cart"/
      assert html =~ "Farm fresh to your door."

      assert String.match?(
               html,
               ~r/Search products.*Fresh to Your Door.*Get Weekly Deals.*<footer/s
             )
    end

    test "an empty catalogue drops the category, featured and grid blocks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "Today's Picks"
      refute html =~ "Shop All Products"
      # Hero, delivery banner and newsletter still stand
      assert html =~ "Fresh to Your Door"
      assert html =~ "Same-Day Delivery in Accra"
      assert html =~ "Get Weekly Deals"
    end

    test "a store description replaces the hero subtitle" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "fresh"},
          description: "Farm produce from Kumasi, picked this morning."
        })

      html = render_home(store)

      assert html =~ "Farm produce from Kumasi, picked this morning."
    end
  end

  # ── Legacy section toggles keep working ─────────────────────────

  describe "legacy @theme.sections toggles" do
    test "a disabled block stays out of the rendered home" do
      store = seed_store!()

      theme_config = %{
        "theme" => "fresh",
        "sections" => %{"newsletter" => false, "promo" => false}
      }

      store =
        store
        |> Ash.Changeset.for_update(:update, %{theme_config: theme_config})
        |> Ash.update!(authorize?: false)

      html = render_home(store)

      refute html =~ "Get Weekly Deals"
      refute html =~ "Same-Day Delivery in Accra"
      assert html =~ "Fresh to Your Door"
      assert html =~ "Shop All Products"
    end
  end

  # ── Contract: the section system ────────────────────────────────

  describe "sections/0" do
    test "lists the six home sections in today's visual order, hero first" do
      keys = Enum.map(Fresh.sections(), & &1.key())

      assert keys == [
               "fresh/hero",
               "fresh/category_circles",
               "fresh/featured",
               "fresh/delivery_banner",
               "fresh/product_grid",
               "fresh/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce against" do
      for section <- Fresh.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section declares a label" do
      for section <- Fresh.sections() do
        assert is_binary(section.label()) and section.label() != ""
      end
    end
  end

  describe "registry" do
    test "Fresh is sectionized and every section key resolves to its module" do
      assert Sections.sectionized?(Fresh)

      for section <- Fresh.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "settings overrides" do
    test "merchant hero and newsletter copy replaces the theme defaults" do
      store = seed_store!()

      layout = [
        %{
          "id" => "fresh/hero",
          "type" => "fresh/hero",
          "enabled" => true,
          "settings" => %{
            "heading" => "Kumasi Greens",
            "subheading" => "Picked at dawn.",
            "cta_label" => "Fill your basket"
          },
          "style" => %{}
        },
        %{
          "id" => "fresh/newsletter",
          "type" => "fresh/newsletter",
          "enabled" => true,
          "settings" => %{"heading" => "Market mornings", "button_label" => "Join"},
          "style" => %{}
        }
      ]

      store = put_layout!(store, layout)

      html = render_home(store)

      assert html =~ "Kumasi Greens"
      assert html =~ "Picked at dawn."
      assert html =~ "Fill your basket"
      assert html =~ "Market mornings"
      assert html =~ "Join"
      refute html =~ "Fresh to Your Door"
      refute html =~ "Get Weekly Deals"
      # Sections left out of the saved layout stay out
      refute html =~ "Shop All Products"
    end

    test "a disabled entry drops its section from the home" do
      store = seed_store!()

      layout =
        for section <- Fresh.sections() do
          %{
            "id" => section.key(),
            "type" => section.key(),
            "enabled" => section.key() != "fresh/product_grid",
            "settings" => %{},
            "style" => %{}
          }
        end

      store = put_layout!(store, layout)

      html = render_home(store)

      refute html =~ "Shop All Products"
      assert html =~ "Today's Picks"
      assert html =~ "Fresh to Your Door"
    end
  end

  defp put_layout!(store, entries) do
    theme_config =
      Map.put(store.theme_config, "home_sections", %{"v" => 1, "fresh" => entries})

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: theme_config})
    |> Ash.update!(authorize?: false)
  end
end
