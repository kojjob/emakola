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

  # No product is shown twice: the deal card takes one, the featured grid four,
  # the immersive grid four and "more from the shop" three (Helpers.slots/1),
  # so a store needs twelve products before every block on the page renders.
  defp stocked_store do
    {_merchant, store} =
      create_merchant_with_store!(%{theme_config: %{"theme" => "electronics"}})

    create_category!(store, %{name: "Headphones"})

    for n <- 1..12 do
      product = create_product!(store, %{title: "Gadget #{n}", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
    end

    store
  end

  # Writes settings onto the hero entry of the store's saved layout, the same
  # shape the section editor persists.
  defp set_hero_settings(store, settings) do
    entries =
      Emakola.Themes.HomeSections.effective_layout(store, Electronics)
      |> Enum.map(fn entry ->
        if entry["type"] == "electronics/hero",
          do: Map.put(entry, "settings", settings),
          else: entry
      end)

    Ash.Seed.update!(store, %{
      theme_config:
        Map.put(store.theme_config || %{}, "home_sections", %{"v" => 1, "electronics" => entries})
    })
  end

  defp h1_of(store),
    do: ~r/<h1[^>]*>\s*#{Regex.escape(Plug.HTML.html_escape(store.name))}\s*<\/h1>/

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

  describe "the hero spec card" do
    test "does not render when the merchant has written nothing" do
      html = render_home(stocked_store())

      refute html =~ "absolute bottom-6 left-6 sm:bottom-8 sm:left-8"
    end

    test "renders the merchant's own words when they write them" do
      store =
        stocked_store()
        |> set_hero_settings(%{"spec_label" => "Warranty", "spec_value" => "2 years, in Accra"})

      html = render_home(store)

      assert html =~ "Warranty"
      assert html =~ "2 years, in Accra"
    end

    test "a label with no detail behind it does not render a card" do
      store = stocked_store() |> set_hero_settings(%{"spec_label" => "Battery"})

      html = render_home(store)

      refute html =~ "absolute bottom-6 left-6 sm:bottom-8 sm:left-8"
    end
  end

  describe "the hero picture" do
    # Updated with the finish-at-one-product rules: the hero used to borrow
    # the shop's first product photo, which then appeared twice on the page.
    test "never borrows a product photo: the deal card carries it, once" do
      store = stocked_store()

      [product | _] =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
        |> Ash.read!(authorize?: false)

      create_image!(product, store, %{url: "/uploads/#{store.slug}/gadget.jpg"})

      html = render_home(store)
      [hero | _] = String.split(html, "</section>")

      refute hero =~ "<img"
      assert length(String.split(html, "/uploads/#{store.slug}/gadget.jpg")) == 2
    end

    test "a page link in a picture field cannot become the hero" do
      store =
        stocked_store()
        |> Ash.Seed.update!(%{cover_image_url: "https://www.instagram.com/someone"})

      html = render_home(store)

      refute html =~ "instagram.com"
    end

    test "product cards fill their frame rather than sitting letterboxed" do
      store = stocked_store()

      [product | _] =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
        |> Ash.read!(authorize?: false)

      create_image!(product, store, %{url: "/uploads/#{store.slug}/gadget.jpg"})

      html = render_home(store)

      refute html =~ "object-contain"
    end
  end

  # ── characterization: today's home, block by block ──────────────
  #
  # Written against the pre-section Electronics home and re-run unchanged
  # after the retrofit. Every literal below is the theme's own copy as it
  # ships today — if one of these moves, the storefront moved.

  describe "home render" do
    test "renders every block with its own copy, in today's order, under one h1" do
      store = stocked_store()
      html = render_home(store)

      # Hero — the only h1 on the page, carrying the store's own name. It used
      # to read "Shop the latest" under a "New Arrivals" pill on every shop.
      assert html =~ h1_of(store)
      refute html =~ "Shop the latest"
      refute html =~ "New Arrivals"
      assert html =~ "Learn more"
      # The spec card used to ship "Battery / 40hrs · BT 5.3" to every shop
      # that installed this theme — a fact about goods the platform knows
      # nothing about. It is the merchant's to write now, or absent.
      refute html =~ "40hrs · BT 5.3"
      assert length(String.split(html, "<h1")) == 2

      # The nav is welded into the teal hero band — it is the hero section's
      # first child, not free-standing chrome above it.
      assert html =~ ~r/<section class="bg-\[#134E4A\]">\s*<header/
      assert html =~ ~s(aria-label="Cart, 0 items")

      # The category strip shows the store's real categories; this store has
      # none, so the strip stays off the page instead of inventing some.
      refute html =~ "Noise Cancellation"
      refute html =~ "Wireless"

      # Immersive split
      assert html =~ "More from"
      assert html =~ "See the whole range"
      # Was "Hand-picked for clarity, comfort, and battery life." — an assertion
      # that someone at this shop auditioned the gear on three criteria. Nobody did.
      refute html =~ "Hand-picked"

      # Featured products + featured deal card
      assert html =~ "Featured products"
      assert html =~ "Gadget 1"
      assert html =~ "Add to Cart"
      # Price formatted from integer minor units
      assert html =~ "GH₵ 123.45"

      # Trust statement. Its default subheading used to read "Genuine products.
      # 1-year warranty. Free shipping over GHS 500." — a warranty and a shipping
      # threshold this merchant never set. With no delivery zones configured it
      # states only what is true and links the store's own policies.
      assert html =~ "Why shop here"
      assert html =~ "Secure checkout with mobile money and card."
      assert html =~ "See this store"
      assert html =~ "/policies#shipping"
      refute html =~ "1-year warranty"
      refute html =~ "Free shipping"

      # Best sellers
      assert html =~ "More from the shop"

      # Dark CTA band — the merchant's own pitch or nothing. "Explore our
      # latest collection of electronics" used to speak for every shop.
      refute html =~ "Explore our latest collection"
      refute html =~ "Shop the Collection"

      # Newsletter — no "exclusive offers" promised on the merchant's behalf
      assert html =~ "Subscribe to our newsletter"
      refute html =~ "New launches and exclusive offers"
      assert html =~ "New products and updates from #{Plug.HTML.html_escape(store.name)}"

      # Footer chrome closes the page
      assert html =~ "All rights reserved"

      # Today's visual order, top to bottom
      assert String.match?(
               html,
               ~r/<h1.*More from.*Featured products.*Why shop here.*More from the shop.*Subscribe to our newsletter.*All rights reserved/s
             )
    end

    # Updated with the finish-at-one-product rules: the newsletter joins the
    # page only on a full stall and the CTA band only over the merchant's own
    # heading — an empty store used to carry both, in the theme's words.
    test "an empty store keeps hero and trust; the rest stands down" do
      {_merchant, store} =
        create_merchant_with_store!(%{theme_config: %{"theme" => "electronics"}})

      html = render_home(store)

      assert html =~ h1_of(store)
      refute html =~ "Noise Cancellation"
      assert html =~ "Why shop here"
      refute html =~ "Explore our latest collection"
      refute html =~ "Subscribe to our newsletter"

      # The product-backed blocks stand down rather than render empty grids
      refute html =~ "More from,"
      refute html =~ "Featured products"
      refute html =~ "More from the shop"
    end

    test "the legacy @theme.sections toggles still hide their blocks" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{
            "theme" => "electronics",
            "sections" => %{"trust" => false, "newsletter" => false}
          }
        })

      # A full stall, so it is the toggle and not the bare catalogue that
      # hides the newsletter.
      for n <- 1..4 do
        product = create_product!(store, %{title: "Gadget #{n}", status: :active})
        create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
      end

      html = render_home(store)

      refute html =~ "Why shop here"
      refute html =~ "Subscribe to our newsletter"
      assert html =~ h1_of(store)
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

      # A full stall: the newsletter joins the page at four products.
      for n <- 1..4 do
        product = create_product!(store, %{title: "Gadget #{n}", status: :active})
        create_variant!(product, store, %{price: 12_345, stock_quantity: 5})
      end

      html = render_home(store)

      # The comma splits the headline into its two-line treatment
      assert html =~ "Sound"
      assert html =~ "Perfected"
      assert html =~ "Browse gear"
      assert html =~ "Bought by engineers"
      assert html =~ "The new drop"
      assert html =~ "Get the drops first"
      refute html =~ "Shop the latest"
      refute html =~ "Why shop here"
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
