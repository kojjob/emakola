defmodule Emakola.Themes.VibrantSectionsTest do
  # async: false — registers Vibrant through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "vibrant/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{Sections, ThemeResolver, Vibrant}

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Vibrant])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  defp seed_store do
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => "vibrant"},
        description: "Woven in Kumasi, sold from a stall in Makola.",
        whatsapp_number: "233200000000"
      })

    create_category!(store, %{name: "Kente Cloth"})

    for {title, price} <- [{"Adinkra Wrapper", 12_345}, {"Bolga Basket", 6_500}] do
      product = create_product!(store, %{title: title, status: :active})
      create_variant!(product, store, %{price: price, stock_quantity: 4})
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
      # Mirrors StoreLive: the delivery strip states the store's own zones.
      delivery_zones: Emakola.Shipping.list_delivery_zones!(store.id),
      cart_count: 0,
      __changed__: nil
    }
    |> Vibrant.render_home()
    |> rendered_to_string()
  end

  # ── characterization: today's home, block by block ───────────────
  #
  # Written against the pre-section home and re-run unchanged after the
  # retrofit. Every literal below is verbatim from the rendered page: if
  # one of these moves, the storefront moved.

  describe "home render" do
    test "the editorial hero opens the page with the theme's headline and dual CTA" do
      html = render_home(seed_store())

      # Gradient hero (no merchant hero image configured)
      assert html =~ ~s(id="vibrant-pattern")
      assert html =~ ~r/<h1[^>]*>\s*Discover Unique Finds\s*<\/h1>/
      # Was "Handcrafted with Love" — how every product in every Vibrant store
      # was made, in the hero subtitle.
      assert html =~ "Shop the collection"
      refute html =~ "Handcrafted"
      assert html =~ "Shop the collection"
      assert html =~ "Chat with us"
      assert html =~ "wa.me/233200000000"
    end

    test "exactly one h1 on the page" do
      html = render_home(seed_store())

      assert length(String.split(html, "<h1")) == 2
    end

    test "the trust badges strip sits under the hero" do
      html = render_home(seed_store())

      assert html =~ ~s(aria-label="Why shop with us")
      assert html =~ "Locally crafted"
      assert html =~ "Authenticated"
      assert html =~ "Mobile Money"
    end

    test "editor's picks pairs the first two products" do
      html = render_home(seed_store())

      assert html =~ ~s(id="vibrant-editors-picks")
      assert html =~ "This Week"
      assert html =~ "Editor's picks"
      assert html =~ "Editor's Pick"
      assert html =~ "Adinkra Wrapper"
      assert html =~ "Bolga Basket"
      assert html =~ "Shop now"
    end

    test "occasion edits render the store's root categories" do
      html = render_home(seed_store())

      assert html =~ ~s(id="vibrant-occasions")
      assert html =~ "Curated Edits"
      assert html =~ "Shop the moments"
      assert html =~ "Kente Cloth"
      assert html =~ "Shop the edit"
    end

    test "the featured card carries the first product, its price and the bag CTA" do
      html = render_home(seed_store())

      assert html =~ "Featured"
      assert html =~ "Add to bag"
      # 12_345 pesewas, formatted in the presentation layer
      assert html =~ "GH₵ 123.45"
    end

    test "the product grid lists every product behind its own heading" do
      html = render_home(seed_store())

      assert html =~ ~s(id="vibrant-shop-all")
      assert html =~ "Just Landed"
      assert html =~ "Picked for you"
      assert html =~ "View all"
      assert html =~ "Adinkra Wrapper"
      assert html =~ "Bolga Basket"
    end

    test "the artisan signature surfaces the maker and the store description" do
      html = render_home(seed_store())

      assert html =~ "Meet the Maker"
      assert html =~ "Woven in Kumasi, sold from a stall in Makola."
    end

    test "the newsletter callout renders its capture form" do
      html = render_home(seed_store())

      assert html =~ "Stay in the loop"
      assert html =~ "First dibs on new arrivals"
      assert html =~ "Get notified when fresh pieces drop and exclusive offers go live."
      assert html =~ ~s(type="email")
      assert html =~ "Subscribe"

      # Two capture forms today: this section's, and the one baked into the
      # borrowed Atelier footer. Pinned as-is — the retrofit must not quietly
      # drop (or duplicate) either.
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 3
    end

    # The strip used to close every Vibrant page with "Free delivery — Orders
    # over GH₵200", "Reply within an hour" and "Easy returns — 14-day window".
    # This store has configured no delivery zones, so it has promised none of
    # that, and the strip now says so.
    test "the service strip promises nothing a store with no zones hasn't promised" do
      html = render_home(seed_store())

      assert html =~ "Delivery &amp; returns"
      # HEEx escapes interpolated values, so the apostrophe arrives as &#39;
      assert html =~ "See this store"
      assert html =~ "/policies#shipping"

      # What the platform really does support
      assert html =~ "Mobile money"
      assert html =~ "MTN MoMo, Telecel Cash, AirtelTigo, card"
      assert html =~ "Secure checkout"

      refute html =~ "Free delivery"
      refute html =~ "Orders over GH₵200"
      refute html =~ "Reply within an hour"
      refute html =~ "14-day window"
      # Vodafone Cash has been Telecel Cash since 2024
      refute html =~ "Vodafone"
    end

    test "a store that configured a free-delivery zone says so, in its own numbers" do
      store = seed_store()

      create_delivery_zone!(store, %{
        name: "Accra",
        fee: 1500,
        estimated_days: 1,
        free_above_pesewas: 20_000
      })

      html = render_home(store)

      assert html =~ "Free delivery"
      assert html =~ "Over GH₵ 200 · Accra"
      refute html =~ "See this store"
    end

    test "three pattern dividers give the page its rhythm" do
      html = render_home(seed_store())

      dividers = length(String.split(html, "w-full flex items-center justify-center py-6")) - 1

      assert dividers == 3
    end

    test "chrome: Vibrant's own nav and Atelier's footer bracket the content" do
      store = seed_store()
      html = render_home(store)

      assert html =~ ~s(aria-label="Search products")
      assert html =~ ~s(href="/s/#{store.slug}/cart")
      assert html =~ ~r/<footer/
      assert html =~ "min-h-screen bg-[#FFFBEB]"
    end

    test "the blocks render in today's visual order" do
      html = render_home(seed_store())

      assert String.match?(
               html,
               ~r/vibrant-pattern.*Why shop with us.*vibrant-editors-picks.*vibrant-occasions.*Add to bag.*vibrant-shop-all.*Meet the Maker.*First dibs on new arrivals.*Secure checkout/s
             )
    end

    test "an empty store still renders hero, trust, artisan, newsletter and service strip" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "vibrant"}})

      html = render_home(store)

      assert html =~ ~r/<h1[^>]*>\s*Discover Unique Finds\s*<\/h1>/
      assert html =~ "Locally crafted"
      assert html =~ "Meet the Maker"
      assert html =~ "First dibs on new arrivals"
      assert html =~ "Secure checkout"
      # Product- and category-gated blocks stay away
      refute html =~ ~s(id="vibrant-editors-picks")
      refute html =~ ~s(id="vibrant-occasions")
      refute html =~ ~s(id="vibrant-shop-all")
      refute html =~ "Add to bag"
    end
  end

  # ── section contract ─────────────────────────────────────────────

  describe "sections/0" do
    test "lists the nine home sections in today's visual order, hero first" do
      assert Enum.map(Vibrant.sections(), & &1.key()) == [
               "vibrant/hero",
               "vibrant/trust_badges",
               "vibrant/editors_picks",
               "vibrant/occasions",
               "vibrant/featured",
               "vibrant/product_grid",
               "vibrant/artisan",
               "vibrant/newsletter",
               "vibrant/service_strip"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Vibrant.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry" do
      assert Sections.sectionized?(Vibrant)

      for section <- Vibrant.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end
end
