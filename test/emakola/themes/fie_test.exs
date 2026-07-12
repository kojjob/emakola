defmodule Emakola.Themes.FieTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test-only seam that lets Fie's section keys resolve through
  # Sections.resolve/1 before central registration) — must not run async
  # with other tests touching it.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Fie
  alias Emakola.Themes.Fie.Components
  alias Emakola.Themes.Fie.Sections.{Catalogue, CollectionIndex, Hero, Newsletter, Story, Trust}
  alias Emakola.Themes.Fie.Shared
  alias Emakola.Themes.Sections

  @invented_sla ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i

  @component_store %{
    slug: "adom",
    name: "Adom Home",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Fie])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Bolga Basket",
        slug: "bolga-basket",
        description: nil,
        min_price: 18_050,
        max_price: 18_050,
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

  defp section_defaults(section) do
    for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}
  end

  defp render_section(section, assigns) do
    settings = Map.merge(section_defaults(section), assigns[:settings] || %{})

    render_component(
      &section.render/1,
      assigns |> Map.new() |> Map.put(:settings, settings)
    )
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
      theme: Fie.defaults(),
      cart_count: 0,
      __changed__: nil
    }
    |> Fie.render_home()
    |> rendered_to_string()
  end

  defp list_assigns(attrs) do
    Map.merge(
      %{
        store: @component_store,
        products: [component_product()],
        categories: [],
        theme: Fie.defaults(),
        cart_count: 0,
        selected_category: nil,
        search_query: "",
        has_more: false
      },
      Map.new(attrs)
    )
  end

  defp detail_assigns(attrs) do
    Map.merge(
      %{
        store: @component_store,
        product:
          component_product(%{
            avg_rating: nil,
            review_count: 0
          }),
        theme: Fie.defaults(),
        related_products: [],
        categories: [],
        cart_count: 0,
        selected_variant: %{
          price: 18_050,
          compare_at_price: nil,
          track_inventory: true,
          stock_quantity: 8,
          sku: nil
        },
        option_types: [],
        selected_options: %{},
        quantity: 1,
        current_image_index: 0
      },
      Map.new(attrs)
    )
  end

  defp render_list(attrs \\ %{}) do
    render_component(&Fie.render_product_list/1, list_assigns(attrs))
  end

  defp render_detail(attrs \\ %{}) do
    render_component(&Fie.render_product_detail/1, detail_assigns(attrs))
  end

  # The shared mobile bar is `sm:hidden` — a cart link only inside it still
  # strands every desktop shopper (the exact Market/Vibrant incident).
  defp cart_reachable_on_desktop?(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(~s(a[href$="/cart"])) |> Enum.count()

    mobile_only =
      doc
      |> LazyHTML.query(~s(nav[class~="sm:hidden"] a[href$="/cart"]))
      |> Enum.count()

    total > mobile_only
  end

  describe "theme contract" do
    test "exposes id, name, fonts, and the behaviour callbacks" do
      assert Fie.id() == "fie"
      assert Fie.name() == "Fie"

      assert [font_url] = Fie.fonts()
      assert font_url =~ "fonts.googleapis.com"
      assert font_url =~ "display=swap"

      Code.ensure_loaded!(Fie)

      for {fun, arity} <- [
            render_home: 1,
            render_product_list: 1,
            render_product_detail: 1,
            css_variables: 0,
            name: 0,
            storefront_nav: 1,
            storefront_footer: 1
          ] do
        assert function_exported?(Fie, fun, arity), "missing #{fun}/#{arity}"
      end
    end

    test "defaults carry the standard config shape" do
      defaults = Fie.defaults()

      for key <- [:colors, :fonts, :hero, :nav, :sections, :trust, :newsletter, :footer] do
        assert is_map(defaults[key]), "defaults missing #{key}"
      end

      for key <- [:primary, :accent, :background, :text, :text_secondary, :border] do
        assert is_binary(defaults.colors[key]), "defaults.colors missing #{key}"
      end

      assert defaults.fonts.heading == "Space Grotesk"
      assert Fie.css_variables()["--theme-primary"] == defaults.colors.primary
    end

    test "renderer/1 maps each page to its module" do
      assert Fie.renderer(:home) == Emakola.Themes.Fie.Home
      assert Fie.renderer(:product_list) == Emakola.Themes.Fie.ProductList
      assert Fie.renderer(:product_detail) == Emakola.Themes.Fie.ProductDetail
      assert Fie.renderer(:shared) == Emakola.Themes.Fie.Shared
    end

    test "sections/0 lists the six home sections in visual order" do
      keys = Enum.map(Fie.sections(), & &1.key())

      assert keys == [
               "fie/hero",
               "fie/collections",
               "fie/catalogue",
               "fie/story",
               "fie/trust",
               "fie/newsletter"
             ]
    end

    test "every settings_schema entry declares a default" do
      for section <- Fie.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      for section <- Fie.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "home render through SectionRenderer" do
    test "renders all six sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!()
      create_category!(store, %{name: "Baskets"})
      product = create_product!(store, %{title: "Kente Cushion", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="fie-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Collection index — numbered, labelled
      assert html =~ ~s(id="fie-collections-heading")
      assert html =~ "Baskets"
      # Catalogue grid with the plate + price from integer minor units
      assert html =~ ~s(id="fie-catalogue-heading")
      assert html =~ "Kente Cushion"
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # Story
      assert html =~ ~s(id="fie-story-heading")
      # Trust names the real rails; newsletter owns capture — exactly one form
      assert html =~ "MTN MoMo"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> collections -> catalogue -> story ->
      # trust -> newsletter
      assert String.match?(
               html,
               ~r/fie-hero-heading.*fie-collections-heading.*fie-catalogue-heading.*fie-story-heading.*fie-trust-heading.*fie-newsletter-form/s
             )
    end

    test "an empty store renders an intentional composed state, never a blank page" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      # No categories: the collection index withdraws entirely
      refute html =~ ~s(id="fie-collections-heading")
      # The catalogue renders its being-prepared state instead of vanishing
      assert html =~ "The catalogue is being prepared"
      assert html =~ "hasn't listed any pieces yet"
      # The hero still opens the page with the store name as its h1
      assert html =~ ~r/<h1[^>]*id="fie-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert html =~ ~s(id="fie-story-heading")
    end

    test "the home page carries Fie's own chrome: skip link, banner nav, footer, bottom nav" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      assert html =~ ~s(href="#fie-content")
      assert html =~ ~s(id="fie-content")
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ ~s(href="/s/#{store.slug}/wishlist")
      assert cart_reachable_on_desktop?(html)
    end

    test "a store description renders in the story section" do
      {_merchant, store} =
        create_merchant_with_store!(%{description: "Handwoven pieces from Bolgatanga."})

      html = render_home(store)

      assert html =~ "Handwoven pieces from Bolgatanga."
    end
  end

  describe "hero section" do
    test "carries the page h1, defaulting to the store name" do
      html = render_section(Hero, %{store: @component_store, products: [], categories: []})

      assert html =~ ~r/<h1[^>]*id="fie-hero-heading"[^>]*>\s*Adom Home\s*<\/h1>/
    end

    test "a merchant headline replaces the store name in the h1" do
      html =
        render_section(Hero, %{
          store: @component_store,
          products: [],
          categories: [],
          settings: %{"headline" => "The August pages"}
        })

      assert html =~ ~r/<h1[^>]*id="fie-hero-heading"[^>]*>\s*The August pages\s*<\/h1>/
      # The store name stays present as the kicker
      assert html =~ "Adom Home"
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Clay, cane and cloth."}

      html = render_section(Hero, %{store: store, products: [], categories: []})

      assert html =~ "Clay, cane and cloth."
    end

    test "the index line states only true counts, and withdraws for an empty store" do
      categories = [%{name: "Baskets", slug: "baskets"}, %{name: "Ceramics", slug: "ceramics"}]

      html =
        render_section(Hero, %{
          store: @component_store,
          products: [component_product()],
          categories: categories
        })

      assert html =~ "2 collections"
      # The home page loads a capped product preview, so a piece count
      # here could lie for larger stores — the hero must never show one.
      refute html =~ ~r/\d+ pieces?/

      empty = render_section(Hero, %{store: @component_store, products: [], categories: []})

      refute empty =~ "0 collections"
    end

    test "photo-optional: no image still renders a composed cover plate, not grey boxes" do
      html = render_section(Hero, %{store: @component_store, products: [], categories: []})

      refute html =~ "<img"
      refute html =~ "animate-pulse"
      # The typographic plate: blush ground carrying the store initial
      assert html =~ "bg-[#F7ECE7]"
      assert html =~ ~r/aria-hidden="true"[^>]*>\s*A\s*</s
      assert html =~ "Browse the catalogue"
    end

    test "renders a local upload as the cover with alt text" do
      html =
        render_section(Hero, %{
          store: @component_store,
          products: [],
          categories: [],
          settings: %{"image_url" => "/uploads/cover.jpg"}
        })

      assert html =~ ~s(src="/uploads/cover.jpg")
      assert html =~ ~s(alt="Adom Home catalogue cover")
    end

    test "non-local image URLs never reach the src position" do
      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html =
          render_section(Hero, %{
            store: @component_store,
            products: [],
            categories: [],
            settings: %{"image_url" => url}
          })

        refute html =~ "<img"
        refute html =~ url
      end
    end

    test "the CTA links to the server-generated products path" do
      html = render_section(Hero, %{store: @component_store, products: [], categories: []})

      assert html =~ ~s(href="/s/adom/products")
    end
  end

  describe "collection index section" do
    test "numbers collections by their real position in browse order" do
      categories = [
        %{name: "Chairs", slug: "chairs"},
        %{name: "Ceramics", slug: "ceramics"},
        %{name: "Textiles", slug: "textiles"}
      ]

      html =
        render_section(CollectionIndex, %{store: @component_store, categories: categories})

      assert String.match?(html, ~r/01.*Chairs.*02.*Ceramics.*03.*Textiles/s)
      assert html =~ ~s(href="/s/adom/category/chairs")
      assert html =~ ~s(href="/s/adom/category/ceramics")
    end

    test "withdraws entirely when the store has no collections" do
      html = render_section(CollectionIndex, %{store: @component_store, categories: []})

      refute html =~ "<section"
      refute html =~ "01"
    end
  end

  describe "catalogue section" do
    test "numbers plates by their real position in the product order" do
      products = [
        component_product(%{id: "p1", title: "Bolga Basket", slug: "p1"}),
        component_product(%{id: "p2", title: "Clay Pot", slug: "p2"}),
        component_product(%{id: "p3", title: "Kente Throw", slug: "p3"})
      ]

      html = render_section(Catalogue, %{store: @component_store, products: products})

      assert String.match?(html, ~r/01.*Bolga Basket.*02.*Clay Pot.*03.*Kente Throw/s)
    end

    test "links to the full catalogue instead of claiming a piece count" do
      html =
        render_section(Catalogue, %{
          store: @component_store,
          products: [component_product()]
        })

      # The home preview is capped upstream, so a count here could lie.
      refute html =~ ~r/\d+ pieces?/
      assert html =~ ~s(href="/s/adom/products")
      assert html =~ "Full catalogue"
    end

    test "zero products render the being-prepared plate, not nothing" do
      html = render_section(Catalogue, %{store: @component_store, products: []})

      assert html =~ "The catalogue is being prepared"
      assert html =~ "Adom Home hasn't listed any pieces yet"
      refute html =~ "animate-pulse"
    end

    test "a merchant heading replaces the default" do
      html =
        render_section(Catalogue, %{
          store: @component_store,
          products: [component_product()],
          settings: %{"heading" => "The dry-season pages"}
        })

      assert html =~ "The dry-season pages"
      refute html =~ "The Catalogue"
    end
  end

  describe "catalogue_plate/1" do
    test "is composed before any image bytes: index, initial, price — no <img>" do
      html =
        render_component(&Components.catalogue_plate/1, %{
          product: component_product(),
          store: @component_store,
          index: 4
        })

      refute html =~ "<img"
      assert html =~ "04"
      # The plate carries the product initial as its typographic ground
      assert html =~ ~r/aria-hidden="true"[^>]*>\s*B\s*</s
      assert html =~ "GH₵ 180.50"
      assert html =~ "Bolga Basket"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "keeps the plate beneath the photo when one exists" do
      html =
        render_component(&Components.catalogue_plate/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/basket.jpg"}]}),
          store: @component_store,
          index: 1
        })

      assert html =~ ~s(src="/uploads/basket.jpg")
      assert html =~ ~s(alt="Bolga Basket")
      assert html =~ ~s(loading="lazy")
      assert html =~ "bg-[#F7ECE7]"
    end

    test "shows the strikethrough compare-at when the product is on sale" do
      product =
        component_product(%{
          variants: [
            %{price: 18_050, compare_at_price: 22_000, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.catalogue_plate/1, %{
          product: product,
          store: @component_store,
          index: 1
        })

      assert html =~ "GH₵ 180.50"
      assert html =~ "GH₵ 220"
      assert html =~ "line-through"
    end

    test "a sold-out piece shows the badge and disables add to cart" do
      product =
        component_product(%{
          variants: [
            %{price: 18_050, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.catalogue_plate/1, %{
          product: product,
          store: @component_store,
          index: 1
        })

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "an untracked variant keeps the piece purchasable at zero stock" do
      product =
        component_product(%{
          variants: [
            %{price: 18_050, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Components.catalogue_plate/1, %{
          product: product,
          store: @component_store,
          index: 1
        })

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "renders without an index number when none is given" do
      html =
        render_component(&Components.catalogue_plate/1, %{
          product: component_product(),
          store: @component_store,
          index: nil
        })

      refute html =~ ">01<"
      assert html =~ "GH₵ 180.50"
    end
  end

  describe "story section" do
    test "falls back to neutral welcome copy without a description" do
      html = render_section(Story, %{store: @component_store})

      assert html =~ ~s(id="fie-story-heading")
      assert html =~ "Welcome to Adom Home"
      refute html =~ "Chat on WhatsApp"
    end

    test "renders the description and WhatsApp CTA when present" do
      store = %{
        @component_store
        | description: "A family workshop since 2004.",
          whatsapp_number: "233200000000"
      }

      html = render_section(Story, %{store: store})

      assert html =~ "A family workshop since 2004."
      assert html =~ "Chat on WhatsApp"
      assert html =~ "wa.me/233200000000"
    end
  end

  describe "trust section" do
    test "names only the payment rails the platform really supports" do
      html = render_section(Trust, %{store: @component_store})

      assert html =~ "We accept"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery and returns point at the store's own policies, with no invented SLA" do
      html = render_section(Trust, %{store: @component_store})

      assert html =~ ~s(href="/s/adom/policies)
      refute html =~ @invented_sla
    end

    test "support links to WhatsApp when the store has a number, contact page otherwise" do
      html = render_section(Trust, %{store: @component_store})

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/adom/contact")

      with_whatsapp = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_section(Trust, %{store: with_whatsapp})

      assert html =~ "wa.me/233200000000"
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, %{store: @component_store})

      assert html =~ ~s(id="fie-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Subscribe"
    end

    test "copy is honest — no fake incentive" do
      html = render_section(Newsletter, %{store: @component_store})

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end
  end

  describe "fie_nav/1" do
    defp render_nav(attrs \\ %{}) do
      render_component(
        &Shared.fie_nav/1,
        Map.merge(%{store: @component_store, categories: [], cart_count: 0}, Map.new(attrs))
      )
    end

    test "renders a sticky banner header with the store name linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky top-0"
      assert html =~ ~r/<a[^>]*href="\/s\/adom"[^>]*>/
      assert html =~ "Adom Home"
    end

    test "search is reachable as a plain link to the products path" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/adom\/products"[^>]*aria-label="Search the catalogue"/
    end

    test "the cart link points at the store cart route and carries the live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<a[^>]*href="\/s\/adom\/cart"/
      assert html =~ "Shopping cart, 3 items"
      assert html =~ ~r/>\s*3\s*</
    end

    test "no count badge renders for an empty cart" do
      html = render_nav(%{cart_count: 0})

      assert html =~ "Shopping cart, 0 items"
      refute html =~ ~r/text-white[^>]*>\s*0\s*</
    end

    test "collection links render for desktop navigation with visible focus" do
      html =
        render_nav(%{
          categories: [%{name: "Ceramics", slug: "ceramics"}, %{name: "Cane", slug: "cane"}]
        })

      assert html =~ ~s(href="/s/adom/category/ceramics")
      assert html =~ "Ceramics"
      assert html =~ "focus-visible:"
    end
  end

  describe "fie_bottom_nav/1" do
    test "is mobile-only chrome with the four store routes" do
      html =
        render_component(&Shared.fie_bottom_nav/1, %{
          store: @component_store,
          cart_count: 5,
          active: :home
        })

      assert html =~ "sm:hidden"
      assert html =~ ~r/<a[^>]*href="\/s\/adom"[^>]*>/
      assert html =~ ~s(href="/s/adom/products")
      assert html =~ ~s(href="/s/adom/wishlist")
      assert html =~ ~s(href="/s/adom/cart")
      assert html =~ ~s(aria-current="page")
      assert html =~ ~r/>\s*5\s*</
    end
  end

  describe "footer/1" do
    defp render_footer(attrs \\ %{}) do
      render_component(
        &Shared.footer/1,
        Map.merge(%{store: @component_store, categories: [], theme: %{}}, Map.new(attrs))
      )
    end

    test "declares the contentinfo landmark on the blush ground" do
      html = render_footer()

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "bg-[#F7ECE7]"
    end

    test "keeps the shop and company links" do
      html = render_footer(%{categories: [%{name: "Ceramics", slug: "ceramics"}]})

      assert html =~ "All Products"
      assert html =~ ~s(href="/s/adom/products")
      assert html =~ "Ceramics"
      assert html =~ ~s(href="/s/adom/category/ceramics")
      assert html =~ ~s(href="/s/adom/about")
      assert html =~ ~s(href="/s/adom/faq")
      assert html =~ ~s(href="/s/adom/policies#privacy")
    end

    test "carries no newsletter band — the fie/newsletter section owns capture" do
      html = render_footer()

      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end

    test "keeps the payment badges, trust mark, and identity" do
      html = render_footer()

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      assert html =~ "Secure checkout"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year} Adom Home"
    end

    test "contact links render only when the store has them" do
      html = render_footer()

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "hello@adom.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(%{store: store})

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:hello@adom.example"
      assert html =~ "tel:+233200000000"
    end
  end

  describe "product list page" do
    test "renders the catalogue heading, plates, and Fie's own chrome" do
      html = render_list()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ "The Catalogue"
      assert html =~ "Bolga Basket"
      assert html =~ "GH₵ 180.50"
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert cart_reachable_on_desktop?(html)
    end

    test "search and category filters use the real ProductListLive events" do
      html =
        render_list(%{
          categories: [%{id: "cat-1", name: "Ceramics", slug: "ceramics"}],
          selected_category: "cat-1"
        })

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-value-category_id="cat-1")
    end

    test "plates are link-only — ProductListLive has no add_to_cart handler" do
      refute render_list(%{}) =~ ~s(phx-click="add_to_cart")
    end

    test "numbers continue across the whole visible catalogue" do
      products = [
        component_product(%{id: "p1", title: "One", slug: "p1"}),
        component_product(%{id: "p2", title: "Two", slug: "p2"}),
        component_product(%{id: "p3", title: "Three", slug: "p3"})
      ]

      html = render_list(%{products: products})

      assert String.match?(html, ~r/01.*One.*02.*Two.*03.*Three/s)
    end

    test "load more renders only when there is more" do
      refute render_list(%{has_more: false}) =~ ~s(phx-click="load_more")
      assert render_list(%{has_more: true}) =~ ~s(phx-click="load_more")
    end

    test "an empty result renders the composed empty state with a clear-filters action" do
      html = render_list(%{products: [], search_query: "gold throne"})

      assert html =~ "Nothing on this page"
      assert html =~ ~s(phx-click="filter_category")
      refute html =~ "animate-pulse"
    end
  end

  describe "product detail page" do
    test "renders the piece: single h1 title, price from minor units, add to cart" do
      html = render_detail()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ "Bolga Basket"
      assert html =~ "GH₵ 180.50"
      assert html =~ ~s(phx-click="add_to_cart")
      assert cart_reachable_on_desktop?(html)
    end

    test "no photos still composes the plate — initial on blush, no <img>" do
      html = render_detail()

      refute html =~ "<img"
      assert html =~ "bg-[#F7ECE7]"
      assert html =~ ~r/aria-hidden="true"[^>]*>\s*B\s*</s
    end

    test "gallery thumbnails drive select_image" do
      product =
        component_product(%{
          avg_rating: nil,
          review_count: 0,
          images: [
            %{
              url: "/uploads/a.jpg",
              medium_url: "/uploads/a-m.jpg",
              thumbnail_url: "/uploads/a-t.jpg"
            },
            %{
              url: "/uploads/b.jpg",
              medium_url: "/uploads/b-m.jpg",
              thumbnail_url: "/uploads/b-t.jpg"
            }
          ]
        })

      html = render_detail(%{product: product})

      assert html =~ ~s(src="/uploads/a-m.jpg")
      assert html =~ ~s(phx-click="select_image")
      assert html =~ ~s(phx-value-index="1")
    end

    test "variant options render as a radiogroup driving select_option" do
      option_types = [
        %{
          id: "ot1",
          name: "Size",
          option_values: [%{id: "ov1", value: "Small"}, %{id: "ov2", value: "Large"}]
        }
      ]

      html =
        render_detail(%{option_types: option_types, selected_options: %{"ot1" => "ov2"}})

      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id="ot1")
      assert html =~ ~s(phx-value-value="ov1")
      assert html =~ ~s(role="radio")
      assert html =~ ~s(aria-checked="true")
    end

    test "the quantity stepper drives the real events with bounds" do
      html = render_detail(%{quantity: 1})

      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
      assert html =~ ~r/phx-click="decrement_quantity"[^>]*\sdisabled/s
    end

    test "an out-of-stock variant disables the buy button" do
      html =
        render_detail(%{
          selected_variant: %{
            price: 18_050,
            compare_at_price: nil,
            track_inventory: true,
            stock_quantity: 0,
            sku: nil
          }
        })

      assert html =~ "Out of stock"
      assert html =~ ~r/<button[^>]*id="fie-add-to-cart"[^>]*\sdisabled/s
    end

    test "shows the compare-at saving when the variant is on sale" do
      html =
        render_detail(%{
          selected_variant: %{
            price: 15_000,
            compare_at_price: 20_000,
            track_inventory: false,
            stock_quantity: 0,
            sku: nil
          }
        })

      assert html =~ "GH₵ 150"
      assert html =~ "GH₵ 200"
      assert html =~ "line-through"
    end

    test "WhatsApp ask renders only with a store number" do
      refute render_detail() =~ "wa.me/"

      store = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_detail(%{store: store})

      assert html =~ "wa.me/233200000000"
    end

    test "delivery and returns defer to the store's policies — no invented SLA" do
      html = render_detail()

      assert html =~ ~s(href="/s/adom/policies)
      refute html =~ @invented_sla
    end

    test "tolerates absent review assigns and renders reviews when present" do
      assert is_binary(render_detail())

      html =
        render_detail(%{
          reviews: [],
          can_review: false,
          already_reviewed: false,
          review_form_rating: 0,
          review_form_title: "",
          review_form_body: "",
          review_submitting: false,
          uploads: nil
        })

      assert html =~ "Customer Reviews"
    end

    test "related pieces render as link-only plates — the page's add_to_cart ignores product-id" do
      related = [component_product(%{id: "r1", title: "Clay Pot", slug: "clay-pot"})]

      html = render_detail(%{related_products: related})

      assert html =~ "Clay Pot"
      assert html =~ ~s(href="/s/adom/products/clay-pot")
      # ProductDetailLive's add_to_cart adds the CURRENT product's selected
      # variant regardless of payload — a product-id button on a related
      # plate would silently add the wrong piece to the cart.
      refute html =~ ~s(phx-value-product-id=)
    end
  end

  describe "shared helpers" do
    test "whatsapp_link builds a wa.me url with digits only and encoded text" do
      store = Map.put(@component_store, :whatsapp_number, "+233 20 000 0000")

      link = Shared.whatsapp_link(store, "Salt & Pepper Pots")

      assert link =~ "https://wa.me/233200000000"
      text_param = link |> String.split("?text=") |> List.last()
      refute String.contains?(text_param, "&")
    end

    test "whatsapp_link is nil without a usable number" do
      assert Shared.whatsapp_link(@component_store, "Basket") == nil
      assert Shared.whatsapp_link(Map.put(@component_store, :whatsapp_number, "  "), "B") == nil
    end

    test "first_image prefers thumbnail then url, and survives missing images" do
      assert Shared.first_image(%{images: [%{thumbnail_url: "t.jpg", url: "u.jpg"}]}) == "t.jpg"
      assert Shared.first_image(%{images: [%{thumbnail_url: nil, url: "u.jpg"}]}) == "u.jpg"
      assert Shared.first_image(%{images: []}) == nil
    end

    test "current_image walks the gallery with fallbacks" do
      product = %{
        images: [
          %{medium_url: "m0.jpg", url: "u0.jpg", thumbnail_url: nil},
          %{medium_url: nil, url: "u1.jpg", thumbnail_url: nil}
        ]
      }

      assert Shared.current_image(product, 0) == "m0.jpg"
      assert Shared.current_image(product, 1) == "u1.jpg"
    end
  end
end
