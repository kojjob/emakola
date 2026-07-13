defmodule Emakola.Themes.ElectronicsSectionsTest do
  # async: false — registers Electronics through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "electronics/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Electronics, Sections, ThemeResolver}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Electronics])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  # ── helpers ─────────────────────────────────────────────────────

  # Bestsellers takes products 5..7 (drop 4, take 3), so a store needs at
  # least five products before every block on the page renders.
  defp stocked_store do
    {_merchant, store} =
      create_merchant_with_store!(%{theme_config: %{"theme" => "electronics"}})

    create_category!(store, %{name: "Headphones"})

    for n <- 1..7 do
      product = create_product!(store, %{title: "Gadget #{n}", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    end

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
      # Mirrors StoreLive: the trust statement states the store's own zones.
      delivery_zones: Emakola.Shipping.list_delivery_zones!(store.id),
      cart_count: 0,
      __changed__: nil
    }
    |> Electronics.render_home()
    |> rendered_to_string()
  end

  # ── characterization: today's home, block by block ──────────────
  #
  # Written against the pre-section Electronics home and re-run unchanged
  # after the retrofit. Every literal below is the theme's own copy as it
  # ships today — if one of these moves, the storefront moved.

  describe "home render" do
    test "renders every block with its own copy, in today's order, under one h1" do
      html = render_home(stocked_store())

      # Hero — the only h1 on the page
      assert html =~ "Upgrade Your Gear"
      assert html =~ "New Arrivals"
      assert html =~ "40hrs · BT 5.3"
      assert html =~ "Learn more"
      assert length(String.split(html, "<h1")) == 2

      # The nav is welded into the teal hero band — it is the hero section's
      # first child, not free-standing chrome above it.
      assert html =~ ~r/<section class="bg-\[#134E4A\]">\s*<header/
      assert html =~ ~s(aria-label="Cart, 0 items")

      # Category pill strip
      assert html =~ "Noise Cancellation"
      assert html =~ "See all"

      # Immersive split
      assert html =~ "Immersive Sound,"
      assert html =~ "Unmatched Comfort"
      assert html =~ "Premium audio gear"
      assert html =~ "Hand-picked for clarity, comfort, and battery life."

      # Popular products + featured deal card
      assert html =~ "Popular product"
      assert html =~ "Gadget 1"
      assert html =~ "Add to Cart"
      # Price formatted from integer minor units
      assert html =~ "GH₵ 123.45"

      # Trust statement. Its default subheading used to read "Genuine products.
      # 1-year warranty. Free shipping over GHS 500." — a warranty and a shipping
      # threshold this merchant never set. With no delivery zones configured it
      # states only what is true and links the store's own policies.
      assert html =~ "Why thousands trust us"
      assert html =~ "Secure checkout with mobile money and card."
      assert html =~ "See this store"
      assert html =~ "/policies#shipping"
      refute html =~ "1-year warranty"
      refute html =~ "Free shipping"

      # Best sellers
      assert html =~ "Best selling product"

      # Dark CTA band
      assert html =~ "Explore our latest collection"
      assert html =~ "Shop the Collection"

      # Newsletter
      assert html =~ "Subscribe to our newsletter"
      assert html =~ "New launches and exclusive offers"

      # Footer chrome closes the page
      assert html =~ "All rights reserved"

      # Today's visual order, top to bottom
      assert String.match?(
               html,
               ~r/Upgrade Your Gear.*Noise Cancellation.*Immersive Sound,.*Popular product.*Why thousands trust us.*Best selling product.*Explore our latest collection.*Subscribe to our newsletter.*All rights reserved/s
             )
    end

    test "an empty store keeps hero, strip, trust, CTA band and newsletter" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "electronics"}})

      html = render_home(store)

      assert html =~ "Upgrade Your Gear"
      assert html =~ "Noise Cancellation"
      assert html =~ "Why thousands trust us"
      assert html =~ "Explore our latest collection"
      assert html =~ "Subscribe to our newsletter"

      # The product-backed blocks stand down rather than render empty grids
      refute html =~ "Immersive Sound,"
      refute html =~ "Popular product"
      refute html =~ "Best selling product"
    end

    test "the legacy @theme.sections toggles still hide their blocks" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "electronics",
            "sections" => %{"trust" => false, "newsletter" => false}
          }
        })

      html = render_home(store)

      refute html =~ "Why thousands trust us"
      refute html =~ "Subscribe to our newsletter"
      assert html =~ "Upgrade Your Gear"
    end

    test "merchant theme copy still reaches the page" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "electronics",
            "hero" => %{"title" => "Sound, Perfected", "cta_text" => "Browse gear"},
            "trust" => %{"title" => "Bought by engineers"},
            "cta_band" => %{"title" => "The new drop"},
            "newsletter" => %{"title" => "Get the drops first"}
          }
        })

      html = render_home(store)

      # The comma splits the headline into its two-line treatment
      assert html =~ "Sound"
      assert html =~ "Perfected"
      assert html =~ "Browse gear"
      assert html =~ "Bought by engineers"
      assert html =~ "The new drop"
      assert html =~ "Get the drops first"
      refute html =~ "Upgrade Your Gear"
      refute html =~ "Why thousands trust us"
    end
  end

  # ── section contract (post-retrofit) ────────────────────────────

  describe "sections/0" do
    test "lists the eight home sections in visual order, hero first" do
      assert Enum.map(Electronics.sections(), & &1.key()) == [
               "electronics/hero",
               "electronics/category_strip",
               "electronics/immersive",
               "electronics/featured",
               "electronics/trust",
               "electronics/bestsellers",
               "electronics/cta_band",
               "electronics/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Electronics.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      assert Sections.sectionized?(Electronics)

      for section <- Electronics.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end
end
