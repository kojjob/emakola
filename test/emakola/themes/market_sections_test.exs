defmodule Emakola.Themes.MarketSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Market.Components
  alias Emakola.Themes.Market.Sections.{CategoryStrip, Hero, Newsletter, ProductGrid, Trust}
  alias Emakola.Themes.Market.Shared
  alias Emakola.Themes.{Market, Sections, ThemeResolver}

  @component_store %{
    slug: "stall",
    name: "Stall Front",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Shea Butter",
        slug: "shea-butter",
        description: nil,
        min_price: 4550,
        max_price: 4550,
        images: []
      },
      attrs
    )
  end

  defp render_component(fun, assigns) do
    assigns
    |> Map.put(:__changed__, nil)
    |> fun.()
    |> rendered_to_string()
  end

  defp render_category_strip(assigns) do
    defaults =
      for setting <- CategoryStrip.settings_schema(),
          into: %{},
          do: {setting.key, setting.default}

    render_component(&CategoryStrip.render/1, Map.put(assigns, :settings, defaults))
  end

  describe "category strip covers" do
    test "a category circle wears the store's real cover photograph" do
      html =
        render_category_strip(%{
          store: @component_store,
          categories: [%{id: "cat-1", name: "Spices", slug: "spices"}],
          category_photos: %{"cat-1" => "/uploads/spices.jpg"}
        })

      assert html =~ "/uploads/spices.jpg"
    end

    test "a circle never wears a cover belonging to a different category" do
      html =
        render_category_strip(%{
          store: @component_store,
          categories: [%{id: "cat-food", name: "Food", slug: "food"}],
          category_photos: %{"cat-other" => "/uploads/dress.jpg"}
        })

      refute html =~ "/uploads/dress.jpg"
      # the designed initial circle stands in
      assert html =~ "F"
    end

    test "renders with no covers assign at all" do
      html =
        render_category_strip(%{
          store: @component_store,
          categories: [%{id: "cat-1", name: "Spices", slug: "spices"}]
        })

      assert html =~ "Spices"
    end
  end

  defp render_hero(store, settings_overrides \\ %{}) do
    defaults =
      for setting <- Hero.settings_schema(), into: %{}, do: {setting.key, setting.default}

    render_component(&Hero.render/1, %{
      store: store,
      settings: Map.merge(defaults, settings_overrides)
    })
  end

  defp render_footer(store, attrs \\ %{}) do
    render_component(
      &Shared.footer/1,
      Map.merge(%{store: store, categories: [], theme: %{}}, attrs)
    )
  end

  describe "sections/0" do
    test "lists the seven home sections in visual order, hero first" do
      keys = Enum.map(Market.sections(), & &1.key())

      assert keys == [
               "market/hero",
               "market/category_strip",
               "market/featured",
               "market/product_grid",
               "market/about",
               "market/trust",
               "market/newsletter"
             ]
    end

    test "every settings_schema entry declares a default" do
      for section <- Market.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end
  end

  describe "registry" do
    test "Market is sectionized and every section key resolves" do
      assert Sections.sectionized?(Market)

      for section <- Market.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "home render through SectionRenderer" do
    test "renders all five sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})
      create_category!(store, %{name: "Fresh Peppers"})
      product = create_product!(store, %{title: "Kente Tote Bag", status: :active})
      create_variant!(product, store, %{price: 12345, stock_quantity: 5})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="market-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Category strip (nav must be labelled for screen readers)
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Fresh Peppers"
      # Featured stall-front card
      assert html =~ ~s(aria-label="Featured product")
      # Product grid
      assert html =~ "Shop All"
      assert html =~ "Kente Tote Bag"
      # Price chip: formatted from integer minor units, tabular numerals
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # About
      assert html =~ "About the Shop"
      # Trust names the real rails; newsletter owns capture — exactly one form
      assert html =~ "MTN MoMo"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> categories -> featured -> grid -> about
      # -> trust -> newsletter
      assert String.match?(
               html,
               ~r/market-hero-heading.*Product categories.*Featured product.*Shop All.*About the Shop.*We Accept.*market-newsletter-form/s
             )
    end

    test "empty products and categories render an intentional empty state, not a blank page" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "Shop All"
      # The grid renders its setting-up state instead of vanishing
      assert html =~ "The stall is being set up"
      assert html =~ "added any products yet"
      # The hero still opens the page with the store name as its h1
      assert html =~ ~r/<h1[^>]*id="market-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert html =~ "About the Shop"
    end

    test "a store description renders in the about section" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "market"},
          description: "Hand-picked goods from Makola market."
        })

      html = render_home(store)

      assert html =~ "Hand-picked goods from Makola market."
    end

    test "the home page carries Market's own chrome: skip link, banner nav, bottom nav" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})

      html = render_home(store)

      # Skip link lands on the section content
      assert html =~ ~s(href="#market-content")
      assert html =~ ~s(id="market-content")
      # Banner header with cart + search, before the sections
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~r/aria-label="Search products"/
      # Mobile bottom nav
      assert html =~ ~s(href="/s/#{store.slug}/wishlist")
      # Chrome order: header -> sections -> footer
      assert String.match?(
               html,
               ~r/role="banner".*market-hero-heading.*bg-stone-900/s
             )
    end

    test "the home footer is Market's own warm chrome, not Atelier's" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "market"}})

      html = render_home(store)

      assert html =~ "bg-stone-900"
      refute html =~ "#111111"
    end
  end

  describe "footer/1" do
    test "renders in Market's warm stone palette, with no cold classes" do
      html = render_footer(@component_store)

      assert html =~ "bg-stone-900"
      refute html =~ "#111111"
      refute html =~ ~r/(?<![a-zA-Z])slate-\d/
      refute html =~ ~r/(?<![a-zA-Z])gray-\d/
    end

    test "declares the contentinfo landmark explicitly" do
      # The layout renders theme content inside <main>, which strips
      # <footer>'s implicit contentinfo role — declare it, like the
      # banner header does.
      html = render_footer(@component_store)

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "keeps the shop and company links" do
      html =
        render_footer(@component_store, %{
          categories: [%{name: "Fresh Peppers", slug: "fresh-peppers"}]
        })

      assert html =~ "All Products"
      assert html =~ ~s(href="/s/stall/products")
      assert html =~ "Fresh Peppers"
      assert html =~ ~s(href="/s/stall/category/fresh-peppers")
      assert html =~ "Our Story"
      assert html =~ "FAQ"
      assert html =~ ~s(href="/s/stall/policies#privacy")
    end

    test "no longer carries a newsletter band — the market/newsletter section owns capture" do
      html = render_footer(@component_store)

      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end

    test "keeps the payment and trust badges and the store's identity" do
      html = render_footer(@component_store)

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      assert html =~ "Secure Checkout"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year} Stall Front"
    end

    test "contact links render only when the store has them" do
      html = render_footer(@component_store)

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "hi@stall.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(store)

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:hi@stall.example"
      assert html =~ "tel:+233200000000"
    end
  end

  defp render_nav(attrs \\ %{}) do
    render_component(
      &Shared.market_nav/1,
      Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
    )
  end

  defp render_bottom_nav(attrs \\ %{}) do
    render_component(
      &Shared.market_bottom_nav/1,
      Map.merge(%{store: @component_store, cart_count: 0}, attrs)
    )
  end

  describe "market_nav/1" do
    test "renders a sticky banner header with the store name linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky top-0"
      assert html =~ ~r/<a[^>]*href="\/s\/stall"[^>]*>/
      assert html =~ "Stall Front"
    end

    test "search is reachable as a plain link to the products path" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/stall\/products"[^>]*aria-label="Search products"/
    end

    test "the cart link points at the store cart route and carries the live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<a[^>]*href="\/s\/stall\/cart"/
      assert html =~ "Shopping cart, 3 items"
      assert html =~ ~r/>\s*3\s*</
    end

    test "no count badge renders for an empty cart" do
      html = render_nav(%{cart_count: 0})

      assert html =~ "Shopping cart, 0 items"
      refute html =~ ~r/rounded-full[^>]*>\s*0\s*</
    end

    test "category links render for desktop navigation" do
      html =
        render_nav(%{
          categories: [
            %{name: "Fresh Peppers", slug: "fresh-peppers"},
            %{name: "Shea", slug: "shea"}
          ]
        })

      assert html =~ ~s(href="/s/stall/category/fresh-peppers")
      assert html =~ "Fresh Peppers"
      assert html =~ ~s(href="/s/stall/category/shea")
    end

    test "stays in the warm stone palette with visible keyboard focus" do
      html = render_nav()

      assert html =~ "stone-"
      assert html =~ "focus-visible:"
      refute html =~ ~r/(?<![a-zA-Z])slate-\d/
      refute html =~ ~r/(?<![a-zA-Z])gray-\d/
    end
  end

  describe "market_bottom_nav/1" do
    test "renders Home, Search, Saved and Cart links to the real routes" do
      html = render_bottom_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/stall"[^>]*>/
      assert html =~ "Home"
      assert html =~ ~s(href="/s/stall/products")
      assert html =~ "Search"
      assert html =~ ~s(href="/s/stall/wishlist")
      assert html =~ "Saved"
      assert html =~ ~s(href="/s/stall/cart")
      assert html =~ "Cart"
    end

    test "is mobile-only chrome with the cart count badge" do
      html = render_bottom_nav(%{cart_count: 5})

      assert html =~ "sm:hidden"
      assert html =~ ~r/>\s*5\s*</
    end

    test "marks the home tab current and keeps the warm palette" do
      html = render_bottom_nav()

      assert html =~ ~s(aria-current="page")
      refute html =~ ~r/(?<![a-zA-Z])slate-\d/
    end
  end

  describe "hero/1" do
    test "carries the page's h1, defaulting to the store name" do
      html = render_hero(@component_store)

      assert html =~ ~r/<h1[^>]*id="market-hero-heading"[^>]*>\s*Stall Front\s*<\/h1>/
    end

    test "a merchant headline replaces the store name in the h1" do
      html = render_hero(@component_store, %{"headline" => "Fresh from the stall"})

      assert html =~ ~r/<h1[^>]*id="market-hero-heading"[^>]*>\s*Fresh from the stall\s*<\/h1>/
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Everything fresh, every morning."}

      html = render_hero(store)

      assert html =~ "Everything fresh, every morning."
    end

    test "a merchant subheadline replaces the store description" do
      store = %{@component_store | description: "Everything fresh, every morning."}

      html = render_hero(store, %{"subheadline" => "Same-day delivery in Accra."})

      assert html =~ "Same-day delivery in Accra."
      refute html =~ "Everything fresh, every morning."
    end

    test "photo-optional: no image renders a finished typographic composition" do
      html = render_hero(@component_store)

      refute html =~ "<img"
      # Monumental store-initial watermark (decorative, hidden from AT)
      assert html =~ ~r/aria-hidden="true"[^>]*>\s*S\s*</s
      assert html =~ ~r/<h1[^>]*>\s*Stall Front\s*<\/h1>/
      assert html =~ "Shop all"
    end

    test "renders a local upload as the stall-front image with alt text" do
      html = render_hero(@component_store, %{"image_url" => "/uploads/stall-front.jpg"})

      assert html =~ ~s(src="/uploads/stall-front.jpg")
      assert html =~ ~s(alt="Stall Front storefront")
    end

    test "non-local image URLs never reach the src position" do
      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_hero(@component_store, %{"image_url" => url})

        refute html =~ "<img"
        refute html =~ url
      end
    end

    test "the CTA links to the server-generated products path" do
      html = render_hero(@component_store)

      assert html =~ ~s(href="/s/stall/products")
      assert html =~ "Shop all"
    end

    test "a merchant CTA label replaces the default" do
      html = render_hero(@component_store, %{"cta_label" => "See the goods"})

      assert html =~ "See the goods"
      refute html =~ "Shop all"
    end

    test "every setting declares a default the editor can coerce against" do
      keys = Enum.map(Hero.settings_schema(), & &1.key)

      assert keys == ["headline", "subheadline", "cta_label", "image_url"]

      for setting <- Hero.settings_schema() do
        assert Map.has_key?(setting, :default)
      end
    end
  end

  defp render_trust(store, settings_overrides \\ %{}) do
    defaults =
      for setting <- Trust.settings_schema(),
          into: %{},
          do: {setting.key, setting.default}

    render_component(&Trust.render/1, %{
      store: store,
      settings: Map.merge(defaults, settings_overrides)
    })
  end

  defp render_newsletter(store, settings_overrides \\ %{}) do
    defaults =
      for setting <- Newsletter.settings_schema(),
          into: %{},
          do: {setting.key, setting.default}

    render_component(&Newsletter.render/1, %{
      store: store,
      settings: Map.merge(defaults, settings_overrides)
    })
  end

  describe "trust section" do
    test "names only the payment rails the platform really supports" do
      html = render_trust(@component_store)

      assert html =~ "We Accept"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery and returns point at the store's own policies, with no invented SLA" do
      html = render_trust(@component_store)

      assert html =~ ~s(href="/s/stall/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "support links to WhatsApp when the store has a number, contact page otherwise" do
      html = render_trust(@component_store)

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/stall/contact")

      with_whatsapp = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_trust(with_whatsapp)

      assert html =~ "wa.me/233200000000"
    end

    test "a merchant heading replaces the default" do
      html = render_trust(@component_store, %{"heading" => "Buy with your phone"})

      assert html =~ "Buy with your phone"
      refute html =~ "Shop with confidence"
    end

    test "keeps the warm stone palette" do
      html = render_trust(@component_store)

      refute html =~ ~r/(?<![a-zA-Z])slate-\d/
      refute html =~ ~r/(?<![a-zA-Z])gray-\d/
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_newsletter(@component_store)

      assert html =~ ~s(id="market-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Subscribe"
    end

    test "copy is honest — no fake incentive" do
      html = render_newsletter(@component_store)

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html = render_newsletter(@component_store, %{"heading" => "Market mornings"})

      assert html =~ "Market mornings"
      refute html =~ "Stay in the loop"
    end
  end

  describe "price_chip/1" do
    test "renders the formatted price with tabular numerals" do
      html =
        render_component(&Components.price_chip/1, %{
          product: component_product(),
          store: @component_store
        })

      assert html =~ "GH₵ 45.50"
      assert html =~ "tabular-nums"
    end

    test "renders a range when min and max differ" do
      html =
        render_component(&Components.price_chip/1, %{
          product: component_product(%{min_price: 1000, max_price: 2500}),
          store: @component_store
        })

      assert html =~ "GH₵ 10 - GH₵ 25"
    end

    test "shows the strikethrough compare-at when the product is on sale" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: 6075, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.price_chip/1, %{product: product, store: @component_store})

      assert html =~ "GH₵ 45.50"
      assert html =~ "GH₵ 60.75"
      assert html =~ "line-through"
    end

    test "no compare-at treatment on a price range or when variants aren't loaded" do
      ranged =
        component_product(%{
          min_price: 1000,
          max_price: 2500,
          variants: [
            %{price: 1000, compare_at_price: 3000, track_inventory: false, stock_quantity: 0},
            %{price: 2500, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      refute render_component(&Components.price_chip/1, %{
               product: ranged,
               store: @component_store
             }) =~ "line-through"

      refute render_component(&Components.price_chip/1, %{
               product: component_product(),
               store: @component_store
             }) =~ "line-through"
    end
  end

  describe "product_card/1" do
    test "looks finished with no image: initial, price chip, add to cart — no <img>" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      refute html =~ "<img"
      # Placeholder panel carries the product's initial
      assert html =~ ~r/>\s*S\s*</
      assert html =~ "GH₵ 45.50"
      assert html =~ "Shea Butter"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "keeps the placeholder panel beneath the image when one exists" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/shea.jpg"}]}),
          store: @component_store
        })

      assert html =~ ~s(src="/uploads/shea.jpg")
      assert html =~ ~s(alt="Shea Butter")
      assert html =~ ~s(loading="lazy")
      # The placeholder-first panel still renders underneath
      assert html =~ ~s(aria-hidden="true")
    end

    test "a sold-out product shows the badge and disables add to cart" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.product_card/1, %{
          product: product,
          store: @component_store
        })

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "an untracked variant keeps the product purchasable at zero stock" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.product_card/1, %{
          product: product,
          store: @component_store
        })

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end
  end

  describe "featured_card/1" do
    test "renders the stall front: oversized chip, title, and CTA" do
      html =
        render_component(&Components.featured_card/1, %{
          product: component_product(%{description: "Raw and unrefined."}),
          store: @component_store
        })

      assert html =~ "Featured"
      assert html =~ "Shea Butter"
      assert html =~ "Raw and unrefined."
      assert html =~ "GH₵ 45.50"
      assert html =~ "Add to Cart"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "a sold-out featured product swaps the CTA for a disabled sold-out state" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.featured_card/1, %{
          product: product,
          store: @component_store
        })

      assert html =~ "Sold out"
      refute html =~ "Add to Cart"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end
  end

  describe "product grid section" do
    test "zero products render an intentional empty state, not nothing" do
      html =
        render_component(&ProductGrid.render/1, %{
          store: @component_store,
          products: [],
          settings: %{"heading" => "Shop All"}
        })

      assert html =~ "The stall is being set up"
      assert html =~ "added any products yet"
      refute html =~ "Shop All"
    end
  end

  describe "about_card/1" do
    test "falls back to the neutral welcome copy without a description" do
      html = render_component(&Components.about_card/1, %{store: @component_store})

      assert html =~ "About the Shop"
      assert html =~ "Welcome to Stall Front."
      refute html =~ "Chat on WhatsApp"
    end

    test "renders the description and WhatsApp CTA when present" do
      store = %{
        @component_store
        | description: "Family stall since 1998.",
          whatsapp_number: "233200000000"
      }

      html = render_component(&Components.about_card/1, %{store: store})

      assert html =~ "Family stall since 1998."
      assert html =~ "Chat on WhatsApp"
      assert html =~ "wa.me/233200000000"
    end
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
    |> Market.render_home()
    |> rendered_to_string()
  end
end
