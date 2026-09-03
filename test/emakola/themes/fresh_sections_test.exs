defmodule Emakola.Themes.FreshSectionsTest do
  # async: false — registers Fresh through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "fresh/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Fresh, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Fresh])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  # A full stall with overflow: "Today's Picks" takes four products, "Shop
  # All Products" takes the fifth, and the category circles and newsletter
  # join the page at four or more.
  defp seed_store! do
    {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}})
    create_category!(store, %{name: "Fresh Peppers"})
    product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
    create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

    for n <- 2..5 do
      product = create_product!(store, %{title: "Product #{n}", status: :active})
      create_variant!(product, store, %{price: 1000, stock_quantity: 5})
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
      # Mirrors StoreLive: the delivery banner states the store's own zones.
      delivery_zones: Emakola.Shipping.list_delivery_zones!(store.id),
      cart_count: 0,
      __changed__: nil
    }
    |> Fresh.render_home()
    |> rendered_to_string()
  end

  # ── Characterization: today's home output, block by block ────────

  describe "home render" do
    test "renders every visual block with its own copy" do
      store = seed_store!()
      html = render_home(store)

      # Hero — the store's own name is the headline; the theme ships no
      # invented one. The CTA label is the theme's.
      assert html =~ ~r/<h1[^>]*id="fresh-hero-heading"[^>]*>\s*#{Regex.escape(store.name)}/
      assert html =~ "Start Shopping"
      # Category circles
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Shop by Category"
      assert html =~ "Fresh Peppers"
      # Featured picks
      assert html =~ "Today's Picks"
      # Delivery banner
      # The banner used to headline "Same-Day Delivery in Accra" and promise a
      # noon cutoff on every Fresh store. This one has configured no delivery
      # zones, so it promises nothing and points at its policies instead.
      assert html =~ "Delivery &amp; returns"
      assert html =~ "This store sets its own delivery times and returns terms."
      refute html =~ "Same-Day Delivery in Accra"
      refute html =~ "Order before noon"
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
      store = seed_store!()
      html = render_home(store)

      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<h1[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/
    end

    test "one product: Today's Picks carries it alone" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}})
      create_category!(store, %{name: "Fresh Peppers"})
      create_product!(store, %{title: "Kente Tote Bag", status: :active})

      html = render_home(store)

      assert html =~ "Today's Picks"
      assert html =~ "Kente Tote Bag"
      refute html =~ "Shop All Products"
      refute html =~ ~s(aria-label="Product categories")
      refute html =~ ~s(phx-submit="subscribe_newsletter")
    end

    test "a category without a cover is a plain chip, not a lettered circle" do
      html = render_home(seed_store!())

      assert html =~ "Fresh Peppers"
      refute html =~ ~r/>\s*F\s*</
    end

    test "a store with no description gets no invented headline or standfirst" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}, description: nil})

      html = render_home(store)

      refute html =~ "Fresh to Your Door"
      refute html =~ "picked for you"
      refute html =~ "Fresh produce and groceries"
    end

    test "blocks render in today's visual order" do
      html = render_home(seed_store!())

      assert String.match?(
               html,
               ~r/fresh-hero-heading.*Shop by Category.*Today's Picks.*Delivery &amp; returns.*fresh-shop-all.*Get Weekly Deals/s
             )
    end

    test "the chrome wraps the blocks: nav above, footer below" do
      html = render_home(seed_store!())

      assert html =~ ~s(aria-label="Search products")
      assert html =~ ~r/<a[^>]*href="\/s\/[^"]+\/cart"/
      # The footer's invented "Farm fresh to your door. Quality produce ...
      # delivered with care." blurb and its "Fresh Guarantee" / "Same Day
      # Delivery" badges are gone — the store speaks for itself.
      refute html =~ "Farm fresh to your door."
      refute html =~ "Fresh Guarantee"
      refute html =~ "Same Day Delivery"

      assert String.match?(
               html,
               ~r/Search products.*fresh-hero-heading.*Get Weekly Deals.*<footer/s
             )
    end

    test "a store that really does deliver same-day in Accra still says so" do
      store = seed_store!()
      create_delivery_zone!(store, %{name: "Accra", fee: 1000, estimated_days: 0})

      html = render_home(store)

      # Same-day reaches the page only because the merchant configured a zone
      # with estimated_days: 0 — the same row the checkout charges from.
      assert html =~ "Same day"
      assert html =~ "We deliver to Accra"
      refute html =~ "This store sets its own delivery times"
    end

    test "an empty catalogue drops the category, featured, grid and newsletter blocks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "fresh"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "Today's Picks"
      refute html =~ "Shop All Products"
      # A bare store has no news to sign up for.
      refute html =~ "Get Weekly Deals"
      # Hero and delivery banner still stand
      assert html =~ ~s(id="fresh-hero-heading")
      assert html =~ "Delivery &amp; returns"
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
      refute html =~ "Delivery &amp; returns"
      assert html =~ ~s(id="fresh-hero-heading")
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
      assert html =~ ~r/<h1[^>]*>\s*Kumasi Greens\s*<\/h1>/
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
      assert html =~ ~s(id="fresh-hero-heading")
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
