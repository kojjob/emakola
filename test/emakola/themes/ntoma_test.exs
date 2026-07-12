defmodule Emakola.Themes.NtomaTest do
  # async: false — the SectionRenderer describe mutates the
  # `:emakola, :extra_sectionized_themes` application env (the same
  # test-only seam section_renderer_test.exs uses). Sync tests run after
  # all async tests, so the mutation can't leak into a concurrent run.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Ntoma

  alias Emakola.Themes.Ntoma.Sections.{
    CategoryTiles,
    Featured,
    Hero,
    Newsletter,
    ProductGrid,
    Trust,
    Wordmark
  }

  alias Emakola.Themes.Ntoma.Shared

  @component_store %{
    slug: "cloth",
    name: "Adjoa Atelier",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Ankara Wrap Dress",
        slug: "ankara-wrap-dress",
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

  defp settings_defaults(section) do
    for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}
  end

  defp render_section(section, assigns, settings_overrides \\ %{}) do
    assigns
    |> Map.put(:settings, Map.merge(settings_defaults(section), settings_overrides))
    |> Map.put(:__changed__, nil)
    |> section.render()
    |> rendered_to_string()
  end

  describe "theme module" do
    test "identity, renderers, and fonts" do
      assert Ntoma.id() == "ntoma"
      assert Ntoma.name() == "Ntoma"
      assert Ntoma.renderer(:home) == Emakola.Themes.Ntoma.Home
      assert Ntoma.renderer(:product_list) == Emakola.Themes.Ntoma.ProductList
      assert Ntoma.renderer(:product_detail) == Emakola.Themes.Ntoma.ProductDetail

      # The display serif is the theme — loaded with swap so text renders
      # before the webfont arrives on a slow connection.
      assert [fraunces] = Ntoma.fonts()
      assert fraunces =~ "Fraunces"
      assert fraunces =~ "display=swap"
    end

    test "defaults carry the starter shape: colors and typography keys" do
      defaults = Ntoma.defaults()

      for key <- [:primary, :accent, :background, :text, :text_secondary, :border] do
        assert is_binary(defaults.colors[key]), "colors.#{key} missing"
      end

      assert defaults.fonts.heading == "Fraunces"
      assert is_binary(defaults.fonts.body)
      assert defaults.hero.cta_url == "/products"
      assert is_map(defaults.nav)
      assert is_map(defaults.sections)
      assert is_map(defaults.trust)
      assert is_map(defaults.newsletter)
      assert is_map(defaults.footer)
      assert is_map(defaults.css_variables)
    end

    test "sections/0 lists the seven home sections in visual order, hero first" do
      keys = Enum.map(Ntoma.sections(), & &1.key())

      assert keys == [
               "ntoma/hero",
               "ntoma/trust",
               "ntoma/category_tiles",
               "ntoma/wordmark",
               "ntoma/featured",
               "ntoma/product_grid",
               "ntoma/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce against" do
      for section <- Ntoma.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end
  end

  describe "home render through SectionRenderer" do
    setup do
      Application.put_env(:emakola, :extra_sectionized_themes, [Ntoma])
      on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
      :ok
    end

    test "renders all seven sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!()
      create_category!(store, %{name: "Kaftans"})
      product = create_product!(store, %{title: "Kente Kaftan", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~
               ~r/<h1[^>]*id="ntoma-hero-heading"[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/

      assert length(String.split(html, "<h1")) == 2
      # Trust strip names the real rails
      assert html =~ "MTN MoMo"
      # Asymmetric category tiles
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Kaftans"
      # The gold wordmark band carries the store's own name at display scale
      assert html =~ ~r/id="ntoma-wordmark-heading"[^>]*>\s*#{Regex.escape(store.name)}\s*</
      # Featured piece
      assert html =~ ~s(aria-label="Featured piece")
      # Product grid, price formatted from integer minor units
      assert html =~ "Latest pieces"
      assert html =~ "Kente Kaftan"
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # Newsletter owns capture — exactly one subscribe form
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> trust -> tiles -> wordmark -> featured
      # -> grid -> newsletter
      assert String.match?(
               html,
               ~r/ntoma-hero-heading.*MTN MoMo.*Product categories.*ntoma-wordmark-heading.*Featured piece.*Latest pieces.*ntoma-newsletter-form/s
             )
    end

    test "empty products and categories render an intentional empty state, not a blank page" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ "Latest pieces"
      refute html =~ ~s(aria-label="Featured piece")
      # The grid renders its setting-up state instead of vanishing
      assert html =~ "The first collection is on its way"
      # The type still composes the page: h1 and the wordmark band
      assert html =~
               ~r/<h1[^>]*id="ntoma-hero-heading"[^>]*>\s*#{Regex.escape(store.name)}\s*<\/h1>/

      assert html =~ ~r/id="ntoma-wordmark-heading"[^>]*>\s*#{Regex.escape(store.name)}\s*</
      assert html =~ ~s(phx-submit="subscribe_newsletter")
    end

    test "the home page carries Ntoma's own chrome: skip link, banner nav, footer, bottom nav" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      assert html =~ ~s(href="#ntoma-content")
      assert html =~ ~s(id="ntoma-content")
      # Banner header with a desktop-reachable cart link — the shared
      # bottom bar is sm:hidden, so this is what keeps desktop shoppers
      # able to check out (the Market/Vibrant bug).
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~r/aria-label="Search products"/
      # Ntoma's own footer, not Atelier's
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      refute html =~ "#111111"
      # Mobile bottom nav
      assert html =~ "sm:hidden"
      assert html =~ ~s(href="/s/#{store.slug}/wishlist")
    end
  end

  defp render_nav(attrs \\ %{}) do
    render_component(
      &Shared.ntoma_nav/1,
      Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
    )
  end

  describe "ntoma_nav/1" do
    test "renders a sticky banner header with the store name linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky top-0"
      assert html =~ ~r/<a[^>]*href="\/s\/cloth"[^>]*>/
      assert html =~ "Adjoa Atelier"
    end

    test "search is reachable as a plain link to the products path" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/cloth\/products"[^>]*aria-label="Search products"/
    end

    test "the cart link points at the store cart route and carries the live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<a[^>]*href="\/s\/cloth\/cart"/
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
            %{name: "Kaftans", slug: "kaftans"},
            %{name: "Ankara", slug: "ankara"}
          ]
        })

      assert html =~ ~s(href="/s/cloth/category/kaftans")
      assert html =~ "Kaftans"
      assert html =~ ~s(href="/s/cloth/category/ankara")
    end

    test "keeps visible keyboard focus styles" do
      html = render_nav()

      assert html =~ "focus-visible:"
    end
  end

  describe "footer/1" do
    defp render_footer(attrs \\ %{}) do
      render_component(
        &Shared.footer/1,
        Map.merge(%{store: @component_store, categories: [], theme: %{}}, attrs)
      )
    end

    test "declares the contentinfo landmark and keeps the shop links" do
      html =
        render_footer(%{categories: [%{name: "Kaftans", slug: "kaftans"}]})

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "All Products"
      assert html =~ ~s(href="/s/cloth/products")
      assert html =~ ~s(href="/s/cloth/category/kaftans")
      assert html =~ "FAQ"
      assert html =~ ~s(href="/s/cloth/policies#privacy")
    end

    test "keeps the payment badges and the store's identity" do
      html = render_footer()

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      assert html =~ "Secure Checkout"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year} Adjoa Atelier"
    end

    test "carries no subscribe form — the newsletter section owns capture" do
      html = render_footer()

      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end

    test "contact links render only when the store has them" do
      html = render_footer()

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "hi@cloth.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(%{store: store})

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:hi@cloth.example"
      assert html =~ "tel:+233200000000"
    end
  end

  describe "hero section" do
    test "carries the page's h1, defaulting to the store name in display capitals" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ ~r/<h1[^>]*id="ntoma-hero-heading"[^>]*>\s*Adjoa Atelier\s*<\/h1>/
      assert html =~ "uppercase"
    end

    test "a merchant headline replaces the store name in the h1" do
      html = render_section(Hero, %{store: @component_store}, %{"headline" => "The new cloth"})

      assert html =~ ~r/<h1[^>]*id="ntoma-hero-heading"[^>]*>\s*The new cloth\s*<\/h1>/
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Hand-sewn in Accra since 2015."}

      html = render_section(Hero, %{store: store})

      assert html =~ "Hand-sewn in Accra since 2015."

      html =
        render_section(Hero, %{store: store}, %{"subheadline" => "Made to measure, made to last."})

      assert html =~ "Made to measure, made to last."
      refute html =~ "Hand-sewn in Accra since 2015."
    end

    test "photo-optional: no image renders a finished typographic composition" do
      html = render_section(Hero, %{store: @component_store})

      refute html =~ "<img"
      assert html =~ "Shop the collection"
      assert html =~ ~s(href="/s/cloth/products")
    end

    test "renders a local upload as the hero image with alt text" do
      html =
        render_section(Hero, %{store: @component_store}, %{
          "image_url" => "/uploads/print-shoot.jpg"
        })

      assert html =~ ~s(src="/uploads/print-shoot.jpg")
      assert html =~ ~s(alt="Adjoa Atelier collection")
    end

    test "non-local image URLs never reach the src position" do
      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_section(Hero, %{store: @component_store}, %{"image_url" => url})

        refute html =~ "<img"
        refute html =~ url
      end
    end

    test "a merchant CTA label replaces the default" do
      html = render_section(Hero, %{store: @component_store}, %{"cta_label" => "See the pieces"})

      assert html =~ "See the pieces"
      refute html =~ "Shop the collection"
    end
  end

  describe "trust section" do
    test "names only the payment rails the platform really supports" do
      html = render_section(Trust, %{store: @component_store})

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery and returns point at the store's own policies, with no invented SLA" do
      html = render_section(Trust, %{store: @component_store})

      assert html =~ ~s(href="/s/cloth/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "support links to WhatsApp when the store has a number, contact page otherwise" do
      html = render_section(Trust, %{store: @component_store})

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/cloth/contact")

      with_whatsapp = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_section(Trust, %{store: with_whatsapp})

      assert html =~ "wa.me/233200000000"
    end

    test "a merchant heading replaces the default" do
      html = render_section(Trust, %{store: @component_store}, %{"heading" => "Buy with MoMo"})

      assert html =~ "Buy with MoMo"
      refute html =~ "Shop with confidence"
    end
  end

  describe "category tiles section" do
    defp four_categories do
      for {name, slug} <- [
            {"Kaftans", "kaftans"},
            {"Ankara", "ankara"},
            {"Ready to Wear", "ready-to-wear"},
            {"Accessories", "accessories"}
          ],
          do: %{name: name, slug: slug}
    end

    test "renders every category as a linked tile" do
      html =
        render_section(CategoryTiles, %{store: @component_store, categories: four_categories()})

      assert html =~ ~s(aria-label="Product categories")

      for %{name: name, slug: slug} <- four_categories() do
        assert html =~ name
        assert html =~ ~s(href="/s/cloth/category/#{slug}")
      end
    end

    test "the composition is asymmetric — mixed tile spans, not a uniform grid" do
      html =
        render_section(CategoryTiles, %{store: @component_store, categories: four_categories()})

      assert html =~ "md:row-span-2"
      # At least two different column widths in play
      assert html =~ "md:col-span-4"
      assert html =~ "md:col-span-2"
    end

    test "renders nothing when the store has no categories yet" do
      html = render_section(CategoryTiles, %{store: @component_store, categories: []})

      refute html =~ "Product categories"
      refute html =~ "<a"
    end

    test "a tile with no image of its own borrows a photograph from a product in that category" do
      categories = [%{id: "cat-1", name: "Ankara", slug: "ankara"}]

      products = [
        component_product(%{
          id: "p1",
          category_id: "cat-1",
          images: [%{thumbnail_url: "/uploads/ankara.jpg", url: "/uploads/ankara-full.jpg"}]
        })
      ]

      html =
        render_section(CategoryTiles, %{
          store: @component_store,
          categories: categories,
          products: products
        })

      assert html =~ "/uploads/ankara.jpg"
    end

    test "a tile never borrows a photograph from a DIFFERENT category" do
      # A Food tile wearing a photo of a dress is a lie the shopper acts on.
      categories = [%{id: "cat-food", name: "Food", slug: "food"}]

      products = [
        component_product(%{
          id: "p1",
          category_id: "cat-apparel",
          images: [%{thumbnail_url: "/uploads/dress.jpg", url: "/uploads/dress-full.jpg"}]
        })
      ]

      html =
        render_section(CategoryTiles, %{
          store: @component_store,
          categories: categories,
          products: products
        })

      refute html =~ "/uploads/dress.jpg"
      # The finished calico-and-initial state stands in instead.
      assert html =~ "Food"
    end

    test "renders with no :products assign at all" do
      html =
        render_section(CategoryTiles, %{store: @component_store, categories: four_categories()})

      assert html =~ "Kaftans"
    end
  end

  describe "wordmark band section" do
    test "sets the store's own name at display scale in serif capitals" do
      html = render_section(Wordmark, %{store: @component_store})

      assert html =~ ~r/id="ntoma-wordmark-heading"[^>]*>\s*Adjoa Atelier\s*</
      assert html =~ "uppercase"
      assert html =~ "Fraunces"
    end

    test "links into the collection" do
      html = render_section(Wordmark, %{store: @component_store})

      assert html =~ ~s(href="/s/cloth/products")
      assert html =~ "Shop all"
    end

    test "a merchant tagline renders under the wordmark when set" do
      refute render_section(Wordmark, %{store: @component_store}) =~ "ntoma-wordmark-tagline"

      html =
        render_section(Wordmark, %{store: @component_store}, %{
          "tagline" => "Cloth with a story"
        })

      assert html =~ "Cloth with a story"
    end

    test "the band does not flood the page with the accent" do
      # A full-bleed ochre slab shouts louder than any buy button on the page.
      # The accent survives on the woven strip; the ground is the theme's paper.
      html = render_section(Wordmark, %{store: @component_store})

      refute html =~ ~r/<section[^>]*class="[^"]*bg-\[#E0A32E\]/
      assert html =~ "bg-[#FFFBF2]"
    end
  end

  describe "featured section" do
    test "features the first product with price, CTA, and add to cart" do
      html =
        render_section(Featured, %{
          store: @component_store,
          products: [component_product(%{description: "Cut from hand-waxed Ankara."})]
        })

      assert html =~ ~s(aria-label="Featured piece")
      assert html =~ "Ankara Wrap Dress"
      assert html =~ "Cut from hand-waxed Ankara."
      assert html =~ "GH₵ 45.50"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "renders nothing with no products" do
      html = render_section(Featured, %{store: @component_store, products: []})

      refute html =~ "Featured piece"
    end

    test "a sold-out featured piece swaps the CTA for a disabled state" do
      product =
        component_product(%{
          variants: [
            %{price: 4550, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html = render_section(Featured, %{store: @component_store, products: [product]})

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end
  end

  describe "product grid section" do
    test "renders the grid with a merchant-overridable heading" do
      html =
        render_section(ProductGrid, %{
          store: @component_store,
          products: [component_product()]
        })

      assert html =~ "Latest pieces"
      assert html =~ "Ankara Wrap Dress"
      assert html =~ "GH₵ 45.50"

      html =
        render_section(
          ProductGrid,
          %{store: @component_store, products: [component_product()]},
          %{"heading" => "New in"}
        )

      assert html =~ "New in"
      refute html =~ "Latest pieces"
    end

    test "zero products render an intentional empty state, not nothing" do
      html = render_section(ProductGrid, %{store: @component_store, products: []})

      assert html =~ "The first collection is on its way"
      assert html =~ "Adjoa Atelier"
      refute html =~ "Latest pieces"
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, %{store: @component_store})

      assert html =~ ~s(id="ntoma-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Subscribe"
    end

    test "copy is honest — no fake incentive" do
      html = render_section(Newsletter, %{store: @component_store})

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html = render_section(Newsletter, %{store: @component_store}, %{"heading" => "The list"})

      assert html =~ "The list"
      refute html =~ "Join the list"
    end
  end

  describe "price_tag/1" do
    test "renders the formatted price from integer minor units with tabular numerals" do
      html =
        render_component(&Shared.price_tag/1, %{
          product: component_product(),
          store: @component_store
        })

      assert html =~ "GH₵ 45.50"
      assert html =~ "tabular-nums"
    end

    test "renders a range when min and max differ" do
      html =
        render_component(&Shared.price_tag/1, %{
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

      html = render_component(&Shared.price_tag/1, %{product: product, store: @component_store})

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

      refute render_component(&Shared.price_tag/1, %{product: ranged, store: @component_store}) =~
               "line-through"

      refute render_component(&Shared.price_tag/1, %{
               product: component_product(),
               store: @component_store
             }) =~ "line-through"
    end
  end

  describe "woven placeholder (no-image empty state)" do
    # Ntoma is the textile theme, so a product with no photo gets a woven ground
    # rather than a blank swatch: warp (vertical) and weft (horizontal) hairlines
    # over a tonal gradient. A brand-new store has no images yet, and this is the
    # first thing its merchant sees — "designed" and "broken" must not look alike.
    test "product_card weaves the empty state instead of leaving it blank" do
      html =
        render_component(&Shared.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      refute html =~ "<img"
      assert html =~ "bg-gradient-to-br", "the ground should be tonal, not one flat fill"
      assert html =~ "repeating-linear-gradient(90deg", "missing the warp (vertical threads)"
      assert html =~ "repeating-linear-gradient(0deg", "missing the weft (horizontal threads)"
      assert html =~ ~r/>\s*A\s*</, "the product's initial should still sit on the weave"
    end

    test "featured_card weaves too — the two sit on the same page and must not disagree" do
      html =
        render_component(&Shared.featured_card/1, %{
          product: component_product(),
          store: @component_store
        })

      assert html =~ "repeating-linear-gradient(90deg"
      assert html =~ "repeating-linear-gradient(0deg"
    end

    test "the weave is decorative — hidden from assistive tech, and covered by a real photo" do
      woven =
        render_component(&Shared.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      assert woven =~ ~s(aria-hidden="true")

      photographed =
        render_component(&Shared.product_card/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/dress.jpg"}]}),
          store: @component_store
        })

      # The weave is a floor, not a branch: the image simply covers it.
      assert photographed =~ ~s(src="/uploads/dress.jpg")
      assert photographed =~ "repeating-linear-gradient(90deg"
    end
  end

  describe "product_card/1" do
    test "looks finished with no image: serif initial, price tag, add to cart — no <img>" do
      html =
        render_component(&Shared.product_card/1, %{
          product: component_product(),
          store: @component_store
        })

      refute html =~ "<img"
      assert html =~ ~r/>\s*A\s*</
      assert html =~ "GH₵ 45.50"
      assert html =~ "Ankara Wrap Dress"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
    end

    test "show_add={false} renders a browse-only card — list page has no add handler" do
      html =
        render_component(&Shared.product_card/1, %{
          product: component_product(),
          store: @component_store,
          show_add: false
        })

      refute html =~ "phx-click"
      assert html =~ "Ankara Wrap Dress"
    end

    test "keeps the placeholder panel beneath the image when one exists" do
      html =
        render_component(&Shared.product_card/1, %{
          product: component_product(%{images: [%{thumbnail_url: "/uploads/dress.jpg"}]}),
          store: @component_store
        })

      assert html =~ ~s(src="/uploads/dress.jpg")
      assert html =~ ~s(alt="Ankara Wrap Dress")
      assert html =~ ~s(loading="lazy")
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
        render_component(&Shared.product_card/1, %{product: product, store: @component_store})

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
        render_component(&Shared.product_card/1, %{product: product, store: @component_store})

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end
  end

  describe "product list page" do
    defp list_assigns(overrides) do
      Map.merge(
        %{
          store: @component_store,
          categories: [%{id: "cat-1", name: "Kaftans", slug: "kaftans"}],
          products: [component_product()],
          selected_category: nil,
          search_query: "",
          has_more: false,
          cart_count: 2,
          __changed__: nil
        },
        overrides
      )
    end

    defp render_list(overrides \\ %{}) do
      overrides |> list_assigns() |> Ntoma.render_product_list() |> rendered_to_string()
    end

    test "renders the collection header with one h1 and Ntoma's chrome" do
      html = render_list()

      assert html =~ ~r/<h1[^>]*>\s*The Collection\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/cloth\/cart"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "search and category filters wire only to handlers the list LiveView owns" do
      html = render_list()

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-value-category_id="cat-1")
      # ProductListLive has no add_to_cart handler — cards must be browse-only
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "load more renders only when there are more products" do
      refute render_list() =~ ~s(phx-click="load_more")
      assert render_list(%{has_more: true}) =~ ~s(phx-click="load_more")
    end

    test "an empty result renders an intentional empty state with a clear-filters action" do
      html = render_list(%{products: [], search_query: "chiffon"})

      assert html =~ "Nothing matches"
      assert html =~ ~s(phx-click="filter_category")
    end
  end

  describe "product detail page" do
    defp detail_assigns(overrides) do
      Map.merge(
        %{
          store: @component_store,
          product: component_product(%{description: "Cut from hand-waxed Ankara."}),
          option_types: [],
          selected_options: %{},
          selected_variant: %{
            id: "var-1",
            price: 4550,
            compare_at_price: nil,
            track_inventory: false,
            stock_quantity: 0,
            sku: "NT-001"
          },
          quantity: 1,
          current_image_index: 0,
          related_products: [],
          categories: [],
          cart_count: 1,
          reviews: [],
          can_review: false,
          already_reviewed: false,
          review_form_rating: 0,
          review_form_title: "",
          review_form_body: "",
          review_submitting: false,
          uploads: nil,
          __changed__: nil
        },
        overrides
      )
    end

    defp render_detail(overrides \\ %{}) do
      overrides |> detail_assigns() |> Ntoma.render_product_detail() |> rendered_to_string()
    end

    test "renders the piece with one h1, its price, and Ntoma's chrome" do
      html = render_detail()

      assert html =~ ~r/<h1[^>]*>\s*Ankara Wrap Dress\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ "GH₵ 45.50"
      assert html =~ "Cut from hand-waxed Ankara."
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/cloth\/cart"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "purchase controls wire to the detail LiveView's real handlers" do
      html = render_detail()

      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
    end

    test "an out-of-stock variant disables the add to cart CTA" do
      html =
        render_detail(%{
          selected_variant: %{
            id: "var-1",
            price: 4550,
            compare_at_price: nil,
            track_inventory: true,
            stock_quantity: 0,
            sku: "NT-001"
          }
        })

      assert html =~ "Out of stock"
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "variant options render as a radiogroup wired to select_option" do
      html =
        render_detail(%{
          option_types: [
            %{
              id: "ot-1",
              name: "Size",
              option_values: [%{id: "ov-1", value: "M"}, %{id: "ov-2", value: "L"}]
            }
          ]
        })

      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id="ot-1")
      assert html =~ ~s(phx-value-value="ov-1")
      assert html =~ ~s(role="radiogroup")
    end

    test "gallery thumbnails wire to select_image only when there are multiple images" do
      refute render_detail() =~ ~s(phx-click="select_image")

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
      assert html =~ ~s(src="/uploads/a.jpg")
    end

    test "delivery and returns defer to the store's policies — no invented SLA" do
      html = render_detail()

      assert html =~ ~s(href="/s/cloth/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "the WhatsApp ask link renders only when the store has a number" do
      refute render_detail() =~ "wa.me/"

      html =
        render_detail(%{store: Map.put(@component_store, :whatsapp_number, "233200000000")})

      assert html =~ "wa.me/233200000000"
      assert html =~ "Ask on WhatsApp"
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
      theme: %{},
      cart_count: 0,
      __changed__: nil
    }
    |> Ntoma.render_home()
    |> rendered_to_string()
  end
end
