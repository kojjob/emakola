defmodule Emakola.Themes.PaceTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test-only seam Sections.resolve/1 reads) so Pace's section keys resolve
  # before central registration lands — must not run async with other tests
  # touching that env.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Pace
  alias Emakola.Themes.Pace.Components
  alias Emakola.Themes.Pace.Sections.{Hero, Newsletter, ProductGrid, Trust}
  alias Emakola.Themes.Pace.Shared
  alias Emakola.Themes.Sections

  @component_store %{
    slug: "stride",
    name: "Stride Lab",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Split Shorts",
        slug: "split-shorts",
        description: nil,
        min_price: 4550,
        max_price: 4550,
        images: [],
        avg_rating: nil,
        review_count: 0
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

  defp schema_defaults(section) do
    for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}
  end

  defp render_section(section, store, settings_overrides \\ %{}, extra \\ %{}) do
    render_component(
      &section.render/1,
      Map.merge(
        %{store: store, settings: Map.merge(schema_defaults(section), settings_overrides)},
        extra
      )
    )
  end

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Pace])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  describe "theme contract" do
    test "id, name and fonts" do
      assert Pace.id() == "pace"
      assert Pace.name() == "Pace"

      assert [font_url] = Pace.fonts()
      assert font_url =~ "Chakra+Petch"
      assert font_url =~ "display=swap"
    end

    test "defaults carry the starter shape: colors and typography keys" do
      defaults = Pace.defaults()

      for key <- [:primary, :accent, :background, :text, :text_secondary, :border] do
        assert Map.has_key?(defaults.colors, key)
      end

      assert defaults.fonts.heading == "Chakra Petch"
      assert is_binary(defaults.fonts.body)
      assert Map.has_key?(defaults, :hero)
      assert Map.has_key?(defaults, :newsletter)
      assert Map.has_key?(defaults, :footer)
    end

    test "renderer/1 maps each page to a Pace module" do
      assert Pace.renderer(:home) == Emakola.Themes.Pace.Home
      assert Pace.renderer(:product_list) == Emakola.Themes.Pace.ProductList
      assert Pace.renderer(:product_detail) == Emakola.Themes.Pace.ProductDetail
      assert Pace.renderer(:shared) == Emakola.Themes.Pace.Shared
    end
  end

  describe "sections/0" do
    test "lists the seven home sections in visual order, hero first" do
      keys = Enum.map(Pace.sections(), & &1.key())

      assert keys == [
               "pace/hero",
               "pace/category_rail",
               "pace/featured",
               "pace/product_grid",
               "pace/about",
               "pace/trust",
               "pace/newsletter"
             ]
    end

    test "every settings_schema entry declares a default" do
      for section <- Pace.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "Pace is sectionized and every section key resolves" do
      assert Sections.sectionized?(Pace)

      for section <- Pace.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "theme_styles/1" do
    test "emits theme CSS variables with Pace's ice-and-cobalt fallbacks" do
      html = render_component(&Shared.theme_styles/1, %{theme: %{}})

      assert html =~ "--theme-primary: #1D4ED8"
      assert html =~ "--theme-bg: #E6EFF6"
    end

    test "merchant colors override the fallbacks" do
      html =
        render_component(&Shared.theme_styles/1, %{
          theme: %{colors: %{primary: "#FF4400", background: "#FFFFFF"}}
        })

      assert html =~ "--theme-primary: #FF4400"
      assert html =~ "--theme-bg: #FFFFFF"
    end

    test "the marquee animation is defined and gated behind reduced-motion preference" do
      html = render_component(&Shared.theme_styles/1, %{theme: %{}})

      assert html =~ "@keyframes pace-marquee"
      assert html =~ "prefers-reduced-motion: no-preference"
      # The animation rule lives INSIDE the media guard: no motion is ever
      # applied to users who asked for none.
      assert String.match?(
               html,
               ~r/prefers-reduced-motion: no-preference[^}]*\{[^}]*\.pace-marquee\s*\{\s*animation:/s
             )
    end

    test "the display face falls back through the merchant's heading token" do
      html = render_component(&Shared.theme_styles/1, %{theme: %{}})

      assert html =~ "--dt-heading-font"
      assert html =~ "Chakra Petch"
    end
  end

  describe "home render through SectionRenderer" do
    test "renders all seven sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "pace"}})
      create_category!(store, %{name: "Running"})
      product = create_product!(store, %{title: "Tempo Tee", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="pace-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Ghost marquee is ambient, hidden from assistive tech
      assert html =~ "pace-marquee"
      # Category rail
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Running"
      # Featured night card
      assert html =~ ~s(aria-label="Featured product")
      # Product grid with the formatted minor-unit price
      assert html =~ "The Lineup"
      assert html =~ "Tempo Tee"
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # About
      assert html =~ "About the shop"
      # Trust names the real rails; newsletter owns capture — exactly one form
      assert html =~ "MTN MoMo"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> lanes -> featured -> grid -> about ->
      # trust -> newsletter
      assert String.match?(
               html,
               ~r/pace-hero-heading.*Product categories.*Featured product.*The Lineup.*About the shop.*We Accept.*pace-newsletter-form/s
             )
    end

    test "empty products and categories render an intentional empty state, not a blank page" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "pace"}})

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "The Lineup"
      # The grid renders its warming-up state instead of vanishing
      assert html =~ "The lineup is warming up"
      assert html =~ "added any products yet"
      # The hero still opens the page with the store name as its h1
      assert html =~ ~r/<h1[^>]*id="pace-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert html =~ "About the shop"
    end

    test "a store description renders in the about section" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          theme_config: %{"theme" => "pace"},
          description: "Run gear tested on Accra roads."
        })

      html = render_home(store)

      assert html =~ "Run gear tested on Accra roads."
    end

    test "the home page carries Pace's own chrome: skip link, banner nav, canvas, bottom nav" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "pace"}})

      html = render_home(store)

      # Skip link lands on the rounded canvas
      assert html =~ ~s(href="#pace-content")
      assert html =~ ~r/id="pace-content"[^>]*rounded-/
      # Banner header with cart + search, before the sections
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~r/aria-label="Search products"/
      # Mobile bottom nav
      assert html =~ ~s(href="/s/#{store.slug}/wishlist")
      # Chrome order: header -> sections -> footer (night slab, contentinfo)
      assert String.match?(
               html,
               ~r/role="banner".*pace-hero-heading.*role="contentinfo"/s
             )
    end
  end

  defp render_nav(attrs \\ %{}) do
    render_component(
      &Shared.pace_nav/1,
      Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
    )
  end

  defp render_bottom_nav(attrs \\ %{}) do
    render_component(
      &Shared.pace_bottom_nav/1,
      Map.merge(%{store: @component_store, cart_count: 0}, attrs)
    )
  end

  describe "pace_nav/1" do
    test "renders a sticky banner header with the store name linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky"
      assert html =~ ~r/<a[^>]*href="\/s\/stride"[^>]*>/
      assert html =~ "Stride Lab"
    end

    test "search is reachable as a plain link to the products path" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/stride\/products"[^>]*aria-label="Search products"/
    end

    test "the cart link points at the store cart route and carries the live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<a[^>]*href="\/s\/stride\/cart"/
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
            %{name: "Running", slug: "running"},
            %{name: "Gym", slug: "gym"}
          ]
        })

      assert html =~ ~s(href="/s/stride/category/running")
      assert html =~ "Running"
      assert html =~ ~s(href="/s/stride/category/gym")
    end

    test "keeps visible keyboard focus" do
      html = render_nav()

      assert html =~ "focus-visible:"
    end
  end

  describe "pace_bottom_nav/1" do
    test "renders Home, Search, Saved and Cart links to the real routes" do
      html = render_bottom_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/stride"[^>]*>/
      assert html =~ "Home"
      assert html =~ ~s(href="/s/stride/products")
      assert html =~ "Search"
      assert html =~ ~s(href="/s/stride/wishlist")
      assert html =~ "Saved"
      assert html =~ ~s(href="/s/stride/cart")
      assert html =~ "Cart"
    end

    test "is mobile-only chrome with the cart count badge" do
      html = render_bottom_nav(%{cart_count: 5})

      assert html =~ "sm:hidden"
      assert html =~ ~r/>\s*5\s*</
    end

    test "marks the home tab current" do
      html = render_bottom_nav()

      assert html =~ ~s(aria-current="page")
    end
  end

  describe "hero section" do
    test "carries the page's h1, defaulting to the store name" do
      html = render_section(Hero, @component_store)

      assert html =~ ~r/<h1[^>]*id="pace-hero-heading"[^>]*>\s*Stride Lab\s*<\/h1>/
    end

    test "a merchant headline replaces the store name in the h1" do
      html = render_section(Hero, @component_store, %{"headline" => "Move faster"})

      assert html =~ ~r/<h1[^>]*id="pace-hero-heading"[^>]*>\s*Move faster\s*<\/h1>/
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Gear for every session."}

      html = render_section(Hero, store)

      assert html =~ "Gear for every session."
    end

    test "a merchant subheadline replaces the store description" do
      store = %{@component_store | description: "Gear for every session."}

      html = render_section(Hero, store, %{"subheadline" => "Same-day delivery in Accra."})

      assert html =~ "Same-day delivery in Accra."
      refute html =~ "Gear for every session."
    end

    test "the ghost marquee repeats the wordmark as a decorative layer" do
      html = render_section(Hero, @component_store)

      assert html =~ "pace-marquee"
      # Decorative: hidden from assistive tech, unselectable
      assert String.match?(html, ~r/<div[^>]*aria-hidden="true"[^>]*>[^<]*<div[^>]*pace-marquee/s)
      assert html =~ "STRIDE LAB"
      assert html =~ "select-none"
    end

    test "photo-optional: no image still renders a finished composition" do
      html = render_section(Hero, @component_store)

      refute html =~ "<img"
      assert html =~ ~r/<h1[^>]*>\s*Stride Lab\s*<\/h1>/
      assert html =~ "Shop the lineup"
    end

    test "renders a local upload inside the night-gradient frame with alt text" do
      html = render_section(Hero, @component_store, %{"image_url" => "/uploads/track.jpg"})

      assert html =~ ~s(src="/uploads/track.jpg")
      assert html =~ ~s(alt="Stride Lab gear")
    end

    test "non-local image URLs never reach the src position" do
      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_section(Hero, @component_store, %{"image_url" => url})

        refute html =~ "<img"
        refute html =~ url
      end
    end

    test "the CTA links to the server-generated products path" do
      html = render_section(Hero, @component_store)

      assert html =~ ~s(href="/s/stride/products")
      assert html =~ "Shop the lineup"
    end

    test "a merchant CTA label replaces the default" do
      html = render_section(Hero, @component_store, %{"cta_label" => "See the drop"})

      assert html =~ "See the drop"
      refute html =~ "Shop the lineup"
    end

    test "the settings schema is the editor contract" do
      keys = Enum.map(Hero.settings_schema(), & &1.key)

      assert keys == ["headline", "subheadline", "cta_label", "image_url"]

      for setting <- Hero.settings_schema() do
        assert Map.has_key?(setting, :default)
      end
    end
  end

  describe "product_card/1" do
    test "looks finished with no image: night gradient, initial, price, add to cart" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      refute html =~ "<img"
      # Night-gradient base with the product's ghost initial
      assert html =~ "bg-gradient-to-b"
      assert html =~ ~r/>\s*S\s*</
      assert html =~ "GH₵ 45.50"
      assert html =~ "tabular-nums"
      assert html =~ "Split Shorts"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "layers the photo above the base and washes it with the dark gradient" do
      html =
        render_component(&Components.product_card/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/shorts.jpg"}]}),
          store: @component_store
        })

      assert html =~ ~s(src="/uploads/shorts.jpg")
      assert html =~ ~s(alt="Split Shorts")
      assert html =~ ~s(loading="lazy")
      # Gradient wash keeps the price legible over any photo
      assert html =~ "bg-gradient-to-t"
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

    test "shows the strikethrough compare-at price when the product is on sale" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: 6075, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.product_card/1, %{
          product: product,
          store: @component_store
        })

      assert html =~ "GH₵ 45.50"
      assert html =~ "GH₵ 60.75"
      assert html =~ "line-through"
    end

    test "no compare-at treatment on a price range" do
      ranged =
        component_product(%{
          min_price: 1000,
          max_price: 2500,
          variants: [
            %{price: 1000, compare_at_price: 3000, track_inventory: false, stock_quantity: 0},
            %{price: 2500, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.product_card/1, %{
          product: ranged,
          store: @component_store
        })

      assert html =~ "GH₵ 10 - GH₵ 25"
      refute html =~ "line-through"
    end
  end

  describe "featured_card/1" do
    test "renders the front-runner night card: price, title, and CTA" do
      html =
        render_component(&Components.featured_card/1, %{
          product: component_product(%{description: "Feather-light and fast-drying."}),
          store: @component_store
        })

      assert html =~ "Front runner"
      assert html =~ "Split Shorts"
      assert html =~ "Feather-light and fast-drying."
      assert html =~ "GH₵ 45.50"
      assert html =~ "Add to cart"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "a sold-out featured product swaps the CTA for a disabled state" do
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
      refute html =~ "Add to cart"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end
  end

  describe "product grid section" do
    test "zero products render an intentional warming-up state, not nothing" do
      html = render_section(ProductGrid, @component_store, %{}, %{products: []})

      assert html =~ "The lineup is warming up"
      assert html =~ "added any products yet"
      refute html =~ "The Lineup"
    end

    test "a merchant heading replaces the default" do
      html =
        render_section(ProductGrid, @component_store, %{"heading" => "Fresh drops"}, %{
          products: [component_product()]
        })

      assert html =~ "Fresh drops"
      refute html =~ "The Lineup"
    end
  end

  describe "trust section" do
    test "names only the payment rails the platform really supports" do
      html = render_section(Trust, @component_store)

      assert html =~ "We Accept"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery and returns point at the store's own policies, with no invented SLA" do
      html = render_section(Trust, @component_store)

      assert html =~ ~s(href="/s/stride/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
      refute html =~ ~r/free (delivery|shipping)/i
    end

    test "support links to WhatsApp when the store has a number, contact page otherwise" do
      html = render_section(Trust, @component_store)

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/stride/contact")

      with_whatsapp = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_section(Trust, with_whatsapp)

      assert html =~ "wa.me/233200000000"
    end

    test "a merchant heading replaces the default" do
      html = render_section(Trust, @component_store, %{"heading" => "Buy with your phone"})

      assert html =~ "Buy with your phone"
      refute html =~ "Pay your way"
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, @component_store)

      assert html =~ ~s(id="pace-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Subscribe"
    end

    test "copy is honest — no fake incentive" do
      html = render_section(Newsletter, @component_store)

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html = render_section(Newsletter, @component_store, %{"heading" => "Race updates"})

      assert html =~ "Race updates"
      refute html =~ "Stay on pace"
    end
  end

  describe "about section" do
    test "falls back to the neutral welcome copy without a description" do
      html = render_section(Emakola.Themes.Pace.Sections.About, @component_store)

      assert html =~ "About the shop"
      assert html =~ "Welcome to Stride Lab."
      refute html =~ "Chat on WhatsApp"
    end

    test "renders the description and WhatsApp CTA when present" do
      store = %{
        @component_store
        | description: "Kit for Accra runners since 2022.",
          whatsapp_number: "233200000000"
      }

      html = render_section(Emakola.Themes.Pace.Sections.About, store)

      assert html =~ "Kit for Accra runners since 2022."
      assert html =~ "Chat on WhatsApp"
      assert html =~ "wa.me/233200000000"
    end
  end

  defp render_footer(store, attrs \\ %{}) do
    render_component(
      &Shared.footer/1,
      Map.merge(%{store: store, categories: [], theme: %{}}, attrs)
    )
  end

  describe "footer/1" do
    test "declares the contentinfo landmark explicitly" do
      html = render_footer(@component_store)

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "keeps the shop and company links" do
      html =
        render_footer(@component_store, %{
          categories: [%{name: "Running", slug: "running"}]
        })

      assert html =~ "All Products"
      assert html =~ ~s(href="/s/stride/products")
      assert html =~ "Running"
      assert html =~ ~s(href="/s/stride/category/running")
      assert html =~ "Our Story"
      assert html =~ "FAQ"
      assert html =~ ~s(href="/s/stride/policies#privacy")
    end

    test "carries no newsletter band — the pace/newsletter section owns capture" do
      html = render_footer(@component_store)

      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end

    test "keeps the payment badges, secure checkout mark, and store identity" do
      html = render_footer(@component_store)

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      assert html =~ "Secure Checkout"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year} Stride Lab"
    end

    test "contact links render only when the store has them" do
      html = render_footer(@component_store)

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "hi@stride.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(store)

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:hi@stride.example"
      assert html =~ "tel:+233200000000"
    end
  end

  describe "product list page" do
    defp list_assigns(overrides) do
      Map.merge(
        %{
          store: @component_store,
          products: [component_product()],
          categories: [%{id: "cat-1", name: "Running", slug: "running"}],
          selected_category: nil,
          search_query: "",
          has_more: false,
          cart_count: 0,
          theme: %{},
          __changed__: nil
        },
        overrides
      )
    end

    defp render_list(overrides \\ %{}) do
      list_assigns(overrides)
      |> Emakola.Themes.Pace.ProductList.render()
      |> rendered_to_string()
    end

    test "renders chrome, one h1, and the product grid" do
      html = render_list()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/stride\/cart"/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ "Split Shorts"
      assert html =~ "GH₵ 45.50"
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "search and category filters use the LiveView's real handlers" do
      html = render_list()

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-value-category_id="cat-1")
    end

    test "load more renders only when there are more products" do
      refute render_list() =~ ~s(phx-click="load_more")
      assert render_list(%{has_more: true}) =~ ~s(phx-click="load_more")
    end

    test "an empty result renders an intentional state with a way back" do
      html = render_list(%{products: [], search_query: "xyz"})

      assert html =~ "No gear found"
      assert html =~ ~s(phx-click="filter_category")
    end
  end

  describe "product detail page" do
    defp detail_assigns(overrides) do
      variant = %{
        id: "var-1",
        price: 4550,
        compare_at_price: nil,
        sku: "SS-M",
        track_inventory: true,
        stock_quantity: 8
      }

      Map.merge(
        %{
          store: @component_store,
          product: component_product(%{description: "Feather-light.", variants: [variant]}),
          selected_variant: variant,
          selected_options: %{},
          option_types: [],
          quantity: 1,
          current_image_index: 0,
          related_products: [],
          categories: [],
          cart_count: 0,
          theme: %{},
          reviews: [],
          can_review: false,
          already_reviewed: false,
          review_form_rating: 0,
          review_form_title: "",
          review_form_body: "",
          review_submitting: false,
          __changed__: nil
        },
        overrides
      )
    end

    defp render_detail(overrides \\ %{}) do
      detail_assigns(overrides)
      |> Emakola.Themes.Pace.ProductDetail.render()
      |> rendered_to_string()
    end

    test "renders chrome, one h1 with the product title, and the minor-unit price" do
      html = render_detail()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/stride\/cart"/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<h1[^>]*>\s*Split Shorts\s*<\/h1>/
      assert html =~ "GH₵ 45.50"
      assert html =~ "Feather-light."
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "add to cart, quantity stepper, and option selectors use the real handlers" do
      html =
        render_detail(%{
          option_types: [
            %{id: "ot-1", name: "Size", option_values: [%{id: "ov-1", value: "M"}]}
          ],
          selected_options: %{"ot-1" => "ov-1"}
        })

      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id="ot-1")
      assert html =~ ~s(phx-value-option_value_id="ov-1")
    end

    test "an out-of-stock variant disables purchase" do
      html =
        render_detail(%{
          selected_variant: %{
            id: "var-1",
            price: 4550,
            compare_at_price: nil,
            sku: nil,
            track_inventory: true,
            stock_quantity: 0
          }
        })

      assert html =~ "Out of stock"
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "image thumbnails select via the real handler when multiple images exist" do
      html =
        render_detail(%{
          product:
            component_product(%{
              images: [
                %{url: "/uploads/a.jpg", thumbnail_url: "/uploads/a-thumb.jpg"},
                %{url: "/uploads/b.jpg", thumbnail_url: "/uploads/b-thumb.jpg"}
              ]
            })
        })

      assert html =~ ~s(phx-click="select_image")
      assert html =~ ~s(phx-value-index)
    end

    test "no photo still renders a deliberate night-gradient stage" do
      html = render_detail()

      refute html =~ "<img"
      # Ghost initial on the gradient stage
      assert html =~ ~r/>\s*S\s*</
    end

    test "shipping and returns defer to the store's policies — no invented SLA" do
      html = render_detail()

      assert html =~ ~s(href="/s/stride/policies")
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
      refute html =~ ~r/free (delivery|shipping)/i
    end

    test "WhatsApp ask link renders only when the store has a number" do
      refute render_detail() =~ "wa.me/"

      html =
        render_detail(%{store: Map.put(@component_store, :whatsapp_number, "233200000000")})

      assert html =~ "wa.me/233200000000"
      assert html =~ "Split Shorts"
    end

    test "related products render as a rail with formatted prices" do
      html =
        render_detail(%{
          related_products: [
            component_product(%{id: "prod-2", title: "Pace Cap", slug: "pace-cap"})
          ]
        })

      assert html =~ "Pace Cap"
      assert html =~ ~s(href="/s/stride/products/pace-cap")
    end

    test "the customer reviews section is present" do
      html = render_detail()

      assert html =~ "Customer Reviews"
    end
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
      theme: %{colors: Pace.defaults().colors},
      cart_count: 0,
      __changed__: nil
    }
    |> Pace.render_home()
    |> rendered_to_string()
  end
end
