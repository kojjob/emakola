defmodule Emakola.Themes.DepotTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test-only seam shared with Sections.resolve/1) so Depot's section keys
  # resolve before central registration — must not run async with other
  # tests touching that seam.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Depot
  alias Emakola.Themes.Depot.Sections.{CategoryRail, Hero, Newsletter, OrderSheet, Terms}
  alias Emakola.Themes.Depot.Shared
  alias Emakola.Themes.Sections

  # The shared mobile bar pattern — anything inside it is invisible from
  # `sm` upward, so a cart link only there strands desktop buyers.
  @mobile_only_bar ~s(nav[class~="sm:hidden"])
  @cart_link ~s(a[href$="/cart"])

  @component_store %{
    id: "store-1",
    slug: "volta-depot",
    name: "Volta Trade Depot",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil,
    theme_config: %{}
  }

  defp component_variant(attrs) do
    Map.merge(
      %{
        id: "var-1",
        sku: "PALM-25L",
        price: 45_000,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 24,
        position: 0,
        weight_grams: nil
      },
      attrs
    )
  end

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Palm Oil 25L",
        slug: "palm-oil-25l",
        description: nil,
        min_price: 45_000,
        max_price: 45_000,
        images: [],
        variants: [component_variant(%{})]
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

  defp render_section(section, assigns, settings_overrides \\ %{}) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    render_component(
      &section.render/1,
      Map.put(assigns, :settings, Map.merge(defaults, settings_overrides))
    )
  end

  defp cart_reachable_on_desktop?(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(@cart_link) |> Enum.count()
    mobile_only = doc |> LazyHTML.query("#{@mobile_only_bar} #{@cart_link}") |> Enum.count()

    total > mobile_only
  end

  defp with_depot_seam(_context) do
    Application.put_env(:emakola, :extra_sectionized_themes, [Depot])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  describe "theme contract" do
    test "exposes its identity" do
      assert Depot.id() == "depot"
      assert Depot.name() == "Depot"
    end

    test "lists the five home sections in visual order, order sheet right after the masthead" do
      keys = Enum.map(Depot.sections(), & &1.key())

      assert keys == [
               "depot/hero",
               "depot/order_sheet",
               "depot/category_rail",
               "depot/terms",
               "depot/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce against" do
      for section <- Depot.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "renderer/1 maps the three pages to Depot's own modules" do
      assert Depot.renderer(:home) == Emakola.Themes.Depot.Home
      assert Depot.renderer(:product_list) == Emakola.Themes.Depot.ProductList
      assert Depot.renderer(:product_detail) == Emakola.Themes.Depot.ProductDetail
    end

    test "defaults/0 mirrors the Starter config shape, colors and typography included" do
      defaults = Depot.defaults()
      starter = Emakola.Themes.Starter.defaults()

      assert Enum.sort(Map.keys(defaults)) == Enum.sort(Map.keys(starter))
      assert Enum.sort(Map.keys(defaults.colors)) == Enum.sort(Map.keys(starter.colors))
      assert %{heading: _heading, body: _body} = defaults.fonts
      assert Enum.sort(Map.keys(defaults.fonts)) == Enum.sort(Map.keys(starter.fonts))
      assert defaults.css_variables["--theme-primary"] == defaults.colors.primary
    end

    test "fonts/0 returns swap-loaded Google Fonts stylesheets" do
      fonts = Depot.fonts()

      refute Enum.empty?(fonts)

      for url <- fonts do
        assert String.starts_with?(url, "https://fonts.googleapis.com/")
        assert url =~ "display=swap"
      end
    end
  end

  describe "section registry readiness" do
    setup :with_depot_seam

    test "every Depot section key resolves through the registry" do
      for section <- Depot.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  describe "home render through SectionRenderer" do
    setup :with_depot_seam

    defp render_home(store) do
      products =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
        |> Ash.Query.load(:variants)
        |> Ash.read!(authorize?: false)

      categories = Emakola.Catalog.list_root_categories!(store.id)

      %{
        store: store,
        products: products,
        categories: categories,
        theme: %{colors: Depot.defaults().colors},
        cart_count: 0,
        __changed__: nil
      }
      |> Depot.render_home()
      |> rendered_to_string()
    end

    test "renders the order sheet: SKU, minor-unit price, stock on hand, quick add" do
      {_merchant, store} = create_merchant_with_store!(%{currency: "GHS"})
      create_category!(store, %{name: "Cooking Oils"})
      product = create_product!(store, %{title: "Cassava Flour 10kg", status: :active})

      create_variant!(product, store, %{
        price: 12_345,
        stock_quantity: 24,
        sku: "CSV-10KG",
        position: 0
      })

      html = render_home(store)

      # Masthead carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="depot-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2

      # The order sheet — Depot's signature — is a real table
      assert html =~ ~s(id="depot-order-sheet-heading")
      assert html =~ "Order sheet"
      assert html =~ "<table"
      assert html =~ "Cassava Flour 10kg"
      assert html =~ "CSV-10KG"
      # Price formatted from integer minor units, in tabular numerals
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # Real stock level from the variant
      assert html =~ "24 in stock"
      # Quick add wires the only handler the home page really has
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="#{product.id}")

      # Category rail
      assert html =~ ~s(id="depot-lines-heading")
      assert html =~ "Cooking Oils"

      # Trade terms name the real payment rails
      assert html =~ "MTN MoMo"
      assert html =~ "AirtelTigo Money"

      # Exactly one newsletter capture form on the page
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: masthead -> order sheet -> lines -> terms -> newsletter
      assert String.match?(
               html,
               ~r/depot-hero-heading.*depot-order-sheet-heading.*depot-lines-heading.*We accept.*depot-newsletter-form/s
             )
    end

    test "an empty store renders an intentional stocking-up state, never a blank page" do
      {_merchant, store} = create_merchant_with_store!(%{currency: "GHS"})

      html = render_home(store)

      refute html =~ "<table"
      refute html =~ ~s(id="depot-lines-heading")
      assert html =~ "The depot is being stocked"
      assert html =~ "hasn't listed any items yet"
      # The masthead still opens the page with the store name as its h1
      assert html =~ ~r/<h1[^>]*id="depot-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert cart_reachable_on_desktop?(html)
    end

    test "a store description becomes the masthead subheadline" do
      {_merchant, store} =
        create_merchant_with_store!(%{
          currency: "GHS",
          description: "Carton and sack goods for resellers across Volta."
        })

      html = render_home(store)

      assert html =~ "Carton and sack goods for resellers across Volta."
    end

    test "the home page carries Depot's own chrome with a desktop-reachable cart" do
      {_merchant, store} = create_merchant_with_store!(%{currency: "GHS"})

      html = render_home(store)

      # Skip link lands on the section content
      assert html =~ ~s(href="#depot-content")
      assert html =~ ~s(id="depot-content")
      # Banner header before the sections; explicit contentinfo after them
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ ~r/aria-label="Search products"/
      # Mobile tab bar exists but is not the only route to the cart
      assert html =~ "sm:hidden"
      assert cart_reachable_on_desktop?(html)
    end
  end

  describe "order sheet section" do
    test "a stocked single-variant row: SKU, price, stock count and an Add button" do
      html =
        render_section(OrderSheet, %{store: @component_store, products: [component_product()]})

      assert html =~ "PALM-25L"
      assert html =~ "GH₵ 450"
      assert html =~ "24 in stock"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
      assert html =~ ~s(aria-label="Add Palm Oil 25L to your order")
    end

    test "low stock shows the real remaining count" do
      product =
        component_product(%{variants: [component_variant(%{stock_quantity: 3})]})

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      assert html =~ "3 left"
    end

    test "a sold-out row says so and offers no add binding" do
      product =
        component_product(%{variants: [component_variant(%{stock_quantity: 0})]})

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      assert html =~ "Out of stock"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "an untracked variant stays orderable at zero stock" do
      product =
        component_product(%{
          variants: [component_variant(%{track_inventory: false, stock_quantity: 0})]
        })

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      assert html =~ "Available"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "a multi-variant product shows its price range and routes to options instead of blind-adding" do
      product =
        component_product(%{
          min_price: 10_000,
          max_price: 25_000,
          variants: [
            component_variant(%{id: "var-1", price: 10_000, position: 0}),
            component_variant(%{id: "var-2", sku: "PALM-5L", price: 25_000, position: 1})
          ]
        })

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      assert html =~ "GH₵ 100 - GH₵ 250"
      assert html =~ "Options"
      assert html =~ ~s(href="/s/volta-depot/products/palm-oil-25l")
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "a product whose variants aren't loaded fails quiet, not broken" do
      product = component_product() |> Map.delete(:variants)

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      # Row still renders with the fields we do have; add fails open —
      # the add_to_cart handler re-checks stock server-side.
      assert html =~ "Palm Oil 25L"
      assert html =~ "GH₵ 450"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "zero products render the stocking-up state" do
      html = render_section(OrderSheet, %{store: @component_store, products: []})

      assert html =~ "The depot is being stocked"
      assert html =~ "hasn't listed any items yet"
      refute html =~ "<table"
    end

    test "a merchant heading replaces the default" do
      html =
        render_section(
          OrderSheet,
          %{store: @component_store, products: [component_product()]},
          %{"heading" => "This week in stock"}
        )

      assert html =~ "This week in stock"
      refute html =~ "Order sheet"
    end

    test "a line carries the product's own photograph" do
      product =
        component_product(%{
          images: [%{thumbnail_url: "/uploads/palm.jpg", url: "/uploads/p.jpg"}]
        })

      html = render_section(OrderSheet, %{store: @component_store, products: [product]})

      assert html =~ "/uploads/palm.jpg"
      # The thumbnail is an identification aid beside the title it repeats,
      # so it is decorative to a screen reader, not a second announcement.
      assert html =~ ~r/<img[^>]*alt=""/
    end

    test "a line with no photograph falls back to a lettered tile, never a broken image" do
      html =
        render_section(OrderSheet, %{store: @component_store, products: [component_product()]})

      refute html =~ "<img"
      assert html =~ ~r/aria-hidden="true"[^>]*>\s*P\s*</
    end

    test "the sheet numbers its lines the way a manifest does" do
      products = [
        component_product(),
        component_product(%{id: "prod-2", title: "Rice 25kg", slug: "rice-25kg"})
      ]

      html = render_section(OrderSheet, %{store: @component_store, products: products})

      assert html =~ "01"
      assert html =~ "02"
    end
  end

  describe "masthead section" do
    test "the spec block states only facts the store really has" do
      html =
        render_section(Hero, %{
          store: @component_store,
          categories: [
            %{id: "c1", name: "Oils", slug: "oils"},
            %{id: "c2", name: "Rice", slug: "rice"}
          ]
        })

      assert html =~ "GHS"
      assert html =~ "Categories"
      assert html =~ ~r/<dd[^>]*>\s*2\s*<\/dd>/
    end

    test "the spec block never counts the products, because the home page only gets a preview" do
      products = for i <- 1..3, do: component_product(%{id: "p#{i}"})

      html =
        render_section(Hero, %{
          store: @component_store,
          products: products,
          categories: []
        })

      refute html =~ "Lines"
      refute html =~ "products in stock"
    end

    test "renders without categories or products at all" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ "Volta Trade Depot"
    end

    test "carries the h1, defaulting to the store name" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ ~r/<h1[^>]*id="depot-hero-heading"[^>]*>\s*Volta Trade Depot\s*<\/h1>/
    end

    test "a merchant headline replaces the store name and the kicker keeps the identity" do
      html =
        render_section(Hero, %{store: @component_store}, %{"headline" => "Restock in minutes"})

      assert html =~ ~r/<h1[^>]*id="depot-hero-heading"[^>]*>\s*Restock in minutes\s*<\/h1>/
      assert html =~ "Volta Trade Depot"
    end

    test "the subheadline falls back to the store description and a custom one wins" do
      store = %{@component_store | description: "Wholesale staples, sold by the carton."}

      assert render_section(Hero, %{store: store}) =~ "Wholesale staples, sold by the carton."

      html = render_section(Hero, %{store: store}, %{"subheadline" => "Open to trade buyers."})

      assert html =~ "Open to trade buyers."
      refute html =~ "Wholesale staples, sold by the carton."
    end

    test "the CTA links to the server-generated products path with an editable label" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ ~s(href="/s/volta-depot/products")
      assert html =~ "Browse the catalogue"

      html = render_section(Hero, %{store: @component_store}, %{"cta_label" => "See stock list"})

      assert html =~ "See stock list"
      refute html =~ "Browse the catalogue"
    end
  end

  describe "category rail section" do
    test "renders nothing at all without categories" do
      html = render_section(CategoryRail, %{store: @component_store, categories: []})

      refute html =~ "depot-lines-heading"
      refute html =~ "<a"
    end

    test "renders line links to the category routes" do
      html =
        render_section(CategoryRail, %{
          store: @component_store,
          categories: [%{name: "Cooking Oils", slug: "cooking-oils"}]
        })

      assert html =~ ~s(href="/s/volta-depot/category/cooking-oils")
      assert html =~ "Cooking Oils"
      assert html =~ "Browse by line"
    end
  end

  describe "trade terms section" do
    test "names only the payment rails the platform really supports" do
      html = render_section(Terms, %{store: @component_store})

      assert html =~ "We accept"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery points at the store's own policies with no invented SLA" do
      html = render_section(Terms, %{store: @component_store})

      assert html =~ ~s(href="/s/volta-depot/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
      refute html =~ ~r/lead time of \d+/i
    end

    test "trade inquiries go to WhatsApp when configured, the contact page otherwise" do
      html = render_section(Terms, %{store: @component_store})

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/volta-depot/contact")

      with_whatsapp = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_section(Terms, %{store: with_whatsapp})

      assert html =~ "wa.me/233200000000"
    end

    test "a merchant heading replaces the default" do
      html = render_section(Terms, %{store: @component_store}, %{"heading" => "Buying from us"})

      assert html =~ "Buying from us"
      refute html =~ "How ordering works"
    end
  end

  describe "stock alerts section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, %{store: @component_store})

      assert html =~ ~s(id="depot-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Subscribe"
    end

    test "copy promises nothing the merchant didn't offer" do
      html = render_section(Newsletter, %{store: @component_store})

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html =
        render_section(Newsletter, %{store: @component_store}, %{"heading" => "Restock alerts"})

      assert html =~ "Restock alerts"
      refute html =~ "Stock alerts"
    end
  end

  describe "depot_nav/1" do
    defp render_nav(attrs \\ %{}) do
      render_component(
        &Shared.depot_nav/1,
        Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
      )
    end

    test "is a banner header with the store identity linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky top-0"
      assert html =~ ~r/<a[^>]*href="\/s\/volta-depot"/
      assert html =~ "Volta Trade Depot"
    end

    test "the cart is a labelled order link carrying the live count, reachable on desktop" do
      html = render_nav(%{cart_count: 7})

      assert html =~ ~r/<a[^>]*href="\/s\/volta-depot\/cart"/
      assert html =~ "Your order, 7 items"
      assert html =~ ~r/>\s*7\s*</
      assert cart_reachable_on_desktop?(html)
    end

    test "no count badge renders for an empty cart" do
      html = render_nav(%{cart_count: 0})

      assert html =~ "Your order, 0 items"
      refute html =~ ~r/>\s*0\s*<\/span>/
    end

    test "search is a plain link to the products page — no client event to crash on" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/volta-depot\/products"[^>]*aria-label="Search products"/
      refute html =~ "phx-click"
    end

    test "category links render for desktop navigation with visible keyboard focus" do
      html = render_nav(%{categories: [%{name: "Cooking Oils", slug: "cooking-oils"}]})

      assert html =~ ~s(href="/s/volta-depot/category/cooking-oils")
      assert html =~ "focus-visible:"
    end
  end

  describe "depot_bottom_nav/1" do
    defp render_bottom_nav(attrs) do
      render_component(
        &Shared.depot_bottom_nav/1,
        Map.merge(%{store: @component_store, cart_count: 0, active: :home}, attrs)
      )
    end

    test "is mobile-only chrome linking home, catalogue and the order" do
      html = render_bottom_nav(%{cart_count: 5})

      assert html =~ "sm:hidden"
      assert html =~ ~s(href="/s/volta-depot")
      assert html =~ ~s(href="/s/volta-depot/products")
      assert html =~ ~s(href="/s/volta-depot/cart")
      assert html =~ ~r/>\s*5\s*</
    end

    test "marks the active tab as current" do
      html = render_bottom_nav(%{active: :catalogue})

      assert html =~
               ~r/aria-current="page"[^>]*href="\/s\/volta-depot\/products"|href="\/s\/volta-depot\/products"[^>]*aria-current="page"/
    end
  end

  describe "footer/1" do
    defp render_footer(attrs \\ %{}) do
      render_component(
        &Shared.footer/1,
        Map.merge(%{store: @component_store, categories: [], theme: %{}}, attrs)
      )
    end

    test "declares the contentinfo landmark explicitly" do
      assert render_footer() =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "keeps catalogue and company links" do
      html = render_footer(%{categories: [%{name: "Cooking Oils", slug: "cooking-oils"}]})

      assert html =~ "All products"
      assert html =~ ~s(href="/s/volta-depot/products")
      assert html =~ "Cooking Oils"
      assert html =~ ~s(href="/s/volta-depot/policies#privacy")
      assert html =~ "FAQ"
    end

    test "carries payment badges, the secure checkout mark and the identity line" do
      html = render_footer()

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      assert html =~ "Secure checkout"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year} Volta Trade Depot"
    end

    test "contact links render only when the store has them" do
      html = render_footer()

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "orders@volta.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(%{store: store})

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:orders@volta.example"
      assert html =~ "tel:+233200000000"
    end

    test "owns no newsletter form — the stock alerts section does" do
      html = render_footer()

      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end
  end

  describe "product list page" do
    defp render_list(overrides) do
      render_component(
        &Depot.render_product_list/1,
        %{
          store: @component_store,
          products: [],
          categories: [],
          selected_category: nil,
          search_query: "",
          has_more: false,
          cart_count: 0
        }
        |> Map.merge(overrides)
        |> Emakola.LiveViewHelpers.with_product_stream()
      )
    end

    test "renders the catalogue as link rows — never a client event without a handler" do
      # The list LiveView loads no variants and has NO add_to_cart handler,
      # so rows must link through to the product page instead of quick-adding.
      product =
        component_product()
        |> Map.delete(:variants)
        |> Map.put(:variant_count, 3)

      html =
        render_list(%{
          products: [product],
          categories: [%{id: "cat-1", name: "Cooking Oils", slug: "cooking-oils"}]
        })

      assert html =~ ~r/<h1[^>]*>\s*Catalogue\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ "Palm Oil 25L"
      assert html =~ "GH₵ 450"
      assert html =~ "3 options"
      assert html =~ ~s(href="/s/volta-depot/products/palm-oil-25l")
      refute html =~ ~s(phx-click="add_to_cart")
      assert cart_reachable_on_desktop?(html)
    end

    test "search and category filters wire only verified handlers" do
      html =
        render_list(%{
          products: [component_product()],
          categories: [%{id: "cat-1", name: "Cooking Oils", slug: "cooking-oils"}]
        })

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="cat-1")
      assert html =~ ~s(phx-value-category_id="all")
    end

    test "load more renders only when there is more" do
      refute render_list(%{products: [component_product()]}) =~ ~s(phx-click="load_more")

      assert render_list(%{products: [component_product()], has_more: true}) =~
               ~s(phx-click="load_more")
    end

    test "an empty result renders an intentional state with a way back" do
      html = render_list(%{search_query: "chalk"})

      assert html =~ "No items match"
      assert html =~ ~s(phx-click="filter_category")
      assert cart_reachable_on_desktop?(html)
    end
  end

  describe "product detail page" do
    defp render_detail(overrides) do
      product =
        component_product(%{
          description: "Sold by the carton. 12 bottles per carton.",
          variants: [component_variant(%{weight_grams: 2500})]
        })

      render_component(
        &Depot.render_product_detail/1,
        Map.merge(
          %{
            store: @component_store,
            product: product,
            option_types: [],
            selected_options: %{},
            selected_variant: List.first(product.variants),
            quantity: 1,
            current_image_index: 0,
            related_products: [],
            categories: [],
            cart_count: 0
          },
          overrides
        )
      )
    end

    test "reads like a spec sheet: SKU, unit weight, stock, description" do
      html = render_detail(%{})

      assert html =~ ~r/<h1[^>]*>\s*Palm Oil 25L\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ "PALM-25L"
      assert html =~ "2 kg 500 g"
      assert html =~ "24 in stock"
      assert html =~ "GH₵ 450"
      assert html =~ "Sold by the carton. 12 bottles per carton."
      assert cart_reachable_on_desktop?(html)
    end

    test "quantity stepper and add-to-order wire the detail page's real handlers" do
      html = render_detail(%{quantity: 3})

      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
      assert html =~ ~s(phx-click="add_to_cart")
      # Line total = 3 × GH₵ 450, integer minor-unit arithmetic
      assert html =~ "GH₵ 1,350"
    end

    test "an out-of-stock variant disables the CTA" do
      product =
        component_product(%{
          variants: [component_variant(%{stock_quantity: 0})]
        })

      html =
        render_detail(%{product: product, selected_variant: List.first(product.variants)})

      assert html =~ "Out of stock"
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "option selectors render only when the product has option types" do
      refute render_detail(%{}) =~ ~s(phx-click="select_option")

      html =
        render_detail(%{
          option_types: [
            %{id: "ot-1", name: "Size", option_values: [%{id: "ov-1", value: "25L"}]}
          ]
        })

      assert html =~ ~s(phx-click="select_option")
      assert html =~ "25L"
    end

    test "no photo still renders a finished page, and related items list compactly" do
      html =
        render_detail(%{
          related_products: [
            component_product(%{
              id: "prod-2",
              title: "Groundnut Oil 5L",
              slug: "groundnut-oil-5l",
              min_price: 9_000,
              max_price: 9_000
            })
          ]
        })

      refute html =~ "<img"
      assert html =~ "Also stocked"
      assert html =~ "Groundnut Oil 5L"
      assert html =~ ~s(href="/s/volta-depot/products/groundnut-oil-5l")
      assert html =~ "GH₵ 90"
    end

    test "WhatsApp trade inquiry appears only with a configured number" do
      refute render_detail(%{}) =~ "wa.me/"

      store = Map.put(@component_store, :whatsapp_number, "+233 20 000 0000")
      html = render_detail(%{store: store})

      assert html =~ "wa.me/233200000000"
    end
  end

  describe "money helpers stay in integer minor units" do
    test "format_weight renders grams and kilograms without floats" do
      assert Shared.format_weight(%{weight_grams: 500}) == "500 g"
      assert Shared.format_weight(%{weight_grams: 2000}) == "2 kg"
      assert Shared.format_weight(%{weight_grams: 2500}) == "2 kg 500 g"
      assert Shared.format_weight(%{weight_grams: nil}) == nil
      assert Shared.format_weight(nil) == nil
    end

    test "stock_state reflects the single purchasability rule" do
      assert Shared.stock_state(nil) == :unknown
      assert Shared.stock_state(%{track_inventory: false, stock_quantity: 0}) == :untracked
      assert Shared.stock_state(%{track_inventory: true, stock_quantity: 0}) == :out
      assert Shared.stock_state(%{track_inventory: true, stock_quantity: 3}) == {:low, 3}
      assert Shared.stock_state(%{track_inventory: true, stock_quantity: 24}) == {:in_stock, 24}
    end
  end
end
