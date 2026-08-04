defmodule Emakola.Themes.DedeTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test-only seam that lets Dede's section keys resolve before the central
  # registration lands) — must not run async with other tests touching it.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Dede
  alias Emakola.Themes.Dede.Sections.{Hero, Menu, Newsletter, OrderInfo, Special}
  alias Emakola.Themes.Dede.Shared
  alias Emakola.Themes.Sections

  @invented_sla ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i

  @component_store %{
    slug: "dede-kitchen",
    name: "Dede's Kitchen",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Dede])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  defp dish(attrs \\ %{}) do
    Map.merge(
      %{
        id: "dish-1",
        title: "Waakye Special",
        slug: "waakye-special",
        description: nil,
        min_price: 1500,
        max_price: 1500,
        images: []
      },
      attrs
    )
  end

  defp sold_out_dish(attrs \\ %{}) do
    dish(
      Map.merge(
        %{
          variants: [
            %{price: 1500, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        },
        attrs
      )
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

    render_component(&section.render/1, Map.put(assigns, :settings, settings))
  end

  # Mirrors the theme_nav_audit_test rule: a cart link only inside the
  # mobile-only bar still strands every desktop shopper.
  defp cart_reachable_on_desktop?(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(~s(a[href$="/cart"])) |> Enum.count()

    mobile_only =
      doc |> LazyHTML.query(~s(nav[class~="sm:hidden"] a[href$="/cart"])) |> Enum.count()

    total > mobile_only
  end

  describe "theme contract" do
    test "id and name" do
      assert Dede.id() == "dede"
      assert Dede.name() == "Dede"
    end

    test "sections/0 lists the six home sections, signboard first, menu at the middle" do
      assert Enum.map(Dede.sections(), & &1.key()) == [
               "dede/hero",
               "dede/special",
               "dede/categories",
               "dede/menu",
               "dede/order_info",
               "dede/newsletter"
             ]
    end

    test "every settings_schema entry declares a default the editor can coerce against" do
      for section <- Dede.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry (via the test seam)" do
      for section <- Dede.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end

    test "defaults/0 carries every key the ThemeResolver merges" do
      defaults = Dede.defaults()

      for key <- [:colors, :fonts, :hero, :nav, :sections, :trust, :newsletter, :footer] do
        assert Map.has_key?(defaults, key), "defaults/0 is missing #{inspect(key)}"
      end

      assert %{primary: <<"#", _::binary>>, accent: _, background: _} = defaults.colors
      assert %{heading: "Anton", body: _} = defaults.fonts
    end

    test "fonts/0 loads the signboard face with display=swap" do
      assert [url] = Dede.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Anton"
      assert url =~ "display=swap"
    end

    test "renderer/1 maps the three pages to Dede's own modules" do
      assert Dede.renderer(:home) == Emakola.Themes.Dede.Home
      assert Dede.renderer(:product_list) == Emakola.Themes.Dede.ProductList
      assert Dede.renderer(:product_detail) == Emakola.Themes.Dede.ProductDetail
    end
  end

  describe "home through SectionRenderer" do
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
        theme: Dede.defaults(),
        cart_count: 0,
        __changed__: nil
      }
      |> Dede.render_home()
      |> rendered_to_string()
    end

    test "renders the six sections in order with a single h1 and real prices" do
      {_merchant, store} = create_merchant_with_store!()
      create_category!(store, %{name: "Rice Dishes"})
      product = create_product!(store, %{title: "Jollof with Chicken", status: :active})
      create_variant!(product, store, %{price: 3550, stock_quantity: 9})

      html = render_home(store)

      # The signboard carries the page's only h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="dede-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Menu board row: dish name, price formatted from integer minor units
      assert html =~ "Jollof with Chicken"
      assert html =~ "GH₵ 35.50"
      assert html =~ "tabular-nums"
      # Ordering is one tap from the board
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="#{product.id}")
      # Category chips
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Rice Dishes"
      # Section order: signboard -> special -> categories -> board -> order info -> newsletter
      assert String.match?(
               html,
               ~r/dede-hero-heading.*dede-special-heading.*Product categories.*dede-menu-heading.*dede-order-info-heading.*dede-newsletter-form/s
             )
    end

    test "an empty store renders an intentional chalkboard empty state, not a blank page" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      assert html =~ ~r/<h1[^>]*id="dede-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert html =~ "The board is still being chalked up"
      assert html =~ "written up the menu yet"
      # No dead controls and no vanished sections
      refute html =~ ~s(phx-click="add_to_cart")
      refute html =~ ~s(aria-label="Product categories")
      assert html =~ "dede-order-info-heading"
    end

    test "home chrome: skip link, Dede's banner nav, board footer, mobile tab bar" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      assert html =~ ~s(href="#dede-content")
      assert html =~ ~s(id="dede-content")
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "sm:hidden"
      assert cart_reachable_on_desktop?(html)
    end
  end

  describe "dede_nav/1" do
    defp render_nav(attrs \\ %{}) do
      render_component(
        &Shared.dede_nav/1,
        Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
      )
    end

    test "banner header links the store name home and the cart with its live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/dede-kitchen"/
      assert html =~ "Dede&#39;s Kitchen"
      assert html =~ ~r/<a[^>]*href="\/s\/dede-kitchen\/cart"/
      assert html =~ "Cart, 3 items"
      assert html =~ ~r/>\s*3\s*</
    end

    test "no count badge renders for an empty cart" do
      html = render_nav(%{cart_count: 0})

      assert html =~ "Cart, 0 items"
      refute html =~ ~r/rounded-full[^>]*>\s*0\s*</
    end

    test "search is a plain link to the menu page — no client event to crash on" do
      html = render_nav()

      assert html =~
               ~r/<a[^>]*href="\/s\/dede-kitchen\/products"[^>]*aria-label="Search the menu"/

      refute html =~ "phx-click"
    end

    test "WhatsApp sits in the chrome when the store has a number, and only then" do
      refute render_nav() =~ "wa.me/"

      html =
        render_nav(%{store: Map.put(@component_store, :whatsapp_number, "+233 20 000 0000")})

      assert html =~ "https://wa.me/233200000000"
      assert html =~ ~s(aria-label="Order on WhatsApp")
    end

    test "desktop category links render when categories exist" do
      html = render_nav(%{categories: [%{name: "Drinks", slug: "drinks"}]})

      assert html =~ ~s(href="/s/dede-kitchen/category/drinks")
      assert html =~ "Drinks"
    end
  end

  describe "dede_bottom_nav/1" do
    defp render_bottom_nav(attrs \\ %{}) do
      render_component(
        &Shared.dede_bottom_nav/1,
        Map.merge(%{store: @component_store, cart_count: 0}, attrs)
      )
    end

    test "is mobile-only chrome with Home, Menu and Cart on real routes" do
      html = render_bottom_nav(%{cart_count: 5})

      assert html =~ "sm:hidden"
      assert html =~ ~r/<a[^>]*href="\/s\/dede-kitchen"[^>]*>/
      assert html =~ "Home"
      assert html =~ ~s(href="/s/dede-kitchen/products")
      assert html =~ "Menu"
      assert html =~ ~s(href="/s/dede-kitchen/cart")
      assert html =~ ~r/>\s*5\s*</
    end

    test "the WhatsApp tab appears only for stores with a number" do
      refute render_bottom_nav() =~ "wa.me/"

      html =
        render_bottom_nav(%{store: Map.put(@component_store, :whatsapp_number, "233200000000")})

      assert html =~ "https://wa.me/233200000000"
      assert html =~ "WhatsApp"
    end
  end

  describe "hero section (the signboard)" do
    test "paints the store name as the h1 by default" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ ~r/<h1[^>]*id="dede-hero-heading"[^>]*>\s*Dede&#39;s Kitchen\s*<\/h1>/
    end

    test "a merchant headline replaces the store name and keeps it as a kicker" do
      html =
        render_section(Hero, %{
          store: @component_store,
          settings: %{"headline" => "Hot pots daily"}
        })

      assert html =~ ~r/<h1[^>]*>\s*Hot pots daily\s*<\/h1>/
      assert html =~ "Dede&#39;s Kitchen"
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Waakye and jollof, fresh every morning."}

      assert render_section(Hero, %{store: store}) =~ "Waakye and jollof, fresh every morning."
    end

    test "the CTA links to the server-generated menu path" do
      html = render_section(Hero, %{store: @component_store})

      assert html =~ ~s(href="/s/dede-kitchen/products")
      assert html =~ "See the menu"
    end

    test "WhatsApp ordering is a first-class hero action when the number exists" do
      refute render_section(Hero, %{store: @component_store}) =~ "wa.me/"

      html =
        render_section(Hero, %{
          store: Map.put(@component_store, :whatsapp_number, "233200000000")
        })

      assert html =~ "https://wa.me/233200000000"
      assert html =~ "Order on WhatsApp"
    end

    test "photo-optional: renders a finished signboard with zero image bytes" do
      html = render_section(Hero, %{store: @component_store})

      refute html =~ "<img"
    end

    test "renders a local upload only — remote and scheme URLs never reach src" do
      html =
        render_section(Hero, %{
          store: @component_store,
          settings: %{"image_url" => "/uploads/stall.jpg"}
        })

      assert html =~ ~s(src="/uploads/stall.jpg")

      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_section(Hero, %{store: @component_store, settings: %{"image_url" => url}})

        refute html =~ "<img"
        refute html =~ url
      end
    end
  end

  describe "menu section (the board)" do
    test "a dish row carries name, price on the leader line, and one-tap add" do
      html =
        render_section(Menu, %{
          store: @component_store,
          products: [dish(%{description: "Rice and beans, gari, spaghetti, egg."})]
        })

      assert html =~ "Waakye Special"
      assert html =~ "GH₵ 15"
      assert html =~ "tabular-nums"
      assert html =~ "Rice and beans, gari, spaghetti, egg."
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="dish-1")
      assert html =~ ~s(aria-label="Add Waakye Special to your order")
      assert html =~ ~s(href="/s/dede-kitchen/products/waakye-special")
    end

    test "small frequent prices render clean — no forced decimals" do
      html =
        render_section(Menu, %{
          store: @component_store,
          products: [
            dish(%{
              id: "d1",
              title: "Kelewele",
              slug: "kelewele",
              min_price: 1000,
              max_price: 1000
            }),
            dish(%{id: "d2", title: "Sobolo", slug: "sobolo", min_price: 750, max_price: 750})
          ]
        })

      assert html =~ "GH₵ 10"
      assert html =~ "GH₵ 7.50"
      refute html =~ "GH₵ 10.00"
    end

    test "sold out is unmissable: struck name, stamp, no add control" do
      html = render_section(Menu, %{store: @component_store, products: [sold_out_dish()]})

      assert html =~ "Sold out"
      assert html =~ "line-through"
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "an untracked variant at zero stock stays orderable" do
      product =
        dish(%{
          variants: [
            %{price: 1500, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      html = render_section(Menu, %{store: @component_store, products: [product]})

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "products without loaded variants fail open to orderable" do
      html = render_section(Menu, %{store: @component_store, products: [dish()]})

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "zero products render the chalked-up empty state, never a blank board" do
      html = render_section(Menu, %{store: @component_store, products: []})

      assert html =~ "The board is still being chalked up"
      assert html =~ "Dede&#39;s Kitchen"
      assert html =~ "written up the menu yet"
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "a merchant heading and note replace the defaults" do
      html =
        render_section(Menu, %{
          store: @component_store,
          products: [dish()],
          settings: %{"heading" => "Today's pots", "note" => "Until the pots run dry."}
        })

      assert html =~ "Today&#39;s pots"
      assert html =~ "Until the pots run dry."
    end

    test "the note stays silent by default — no invented promises" do
      html = render_section(Menu, %{store: @component_store, products: [dish()]})

      refute html =~ @invented_sla
    end
  end

  describe "special section (today's special)" do
    test "features the first available dish with a one-tap order" do
      html =
        render_section(Special, %{
          store: @component_store,
          products: [sold_out_dish(), dish(%{id: "d2", title: "Red Red", slug: "red-red"})]
        })

      assert html =~ "Today&#39;s special"
      assert html =~ "Red Red"
      refute html =~ "Waakye Special"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="d2")
      assert html =~ "GH₵ 15"
    end

    test "renders nothing when no dish is available" do
      assert render_section(Special, %{store: @component_store, products: []}) =~ ~r/^\s*$/

      assert render_section(Special, %{store: @component_store, products: [sold_out_dish()]}) =~
               ~r/^\s*$/
    end

    test "a merchant label replaces the default" do
      html =
        render_section(Special, %{
          store: @component_store,
          products: [dish()],
          settings: %{"label" => "Chef's pick"}
        })

      assert html =~ "Chef&#39;s pick"
      refute html =~ "Today&#39;s special"
    end
  end

  describe "order info section" do
    test "names only the payment rails the platform really supports" do
      html = render_section(OrderInfo, %{store: @component_store})

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "WhatsApp ordering leads when the number exists, contact page otherwise" do
      html = render_section(OrderInfo, %{store: @component_store})

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/dede-kitchen/contact")

      html =
        render_section(OrderInfo, %{
          store: Map.put(@component_store, :whatsapp_number, "233200000000")
        })

      assert html =~ "https://wa.me/233200000000"
    end

    test "delivery and pickup point at the store's own policies, with no invented SLA" do
      html = render_section(OrderInfo, %{store: @component_store})

      assert html =~ ~s(href="/s/dede-kitchen/policies)
      refute html =~ @invented_sla
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, %{store: @component_store})

      assert html =~ ~s(id="dede-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
    end

    test "copy is honest — no fake incentive" do
      refute render_section(Newsletter, %{store: @component_store}) =~
               ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html =
        render_section(Newsletter, %{
          store: @component_store,
          settings: %{"heading" => "Know when the pot lands"}
        })

      assert html =~ "Know when the pot lands"
      refute html =~ "Fresh pot alerts"
    end
  end

  describe "footer/1" do
    defp render_footer(attrs \\ %{}) do
      render_component(
        &Shared.footer/1,
        Map.merge(%{store: @component_store, categories: []}, attrs)
      )
    end

    test "declares the contentinfo landmark explicitly" do
      assert render_footer() =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "keeps menu, company links, rails and identity" do
      html = render_footer(%{categories: [%{name: "Drinks", slug: "drinks"}]})

      assert html =~ ~s(href="/s/dede-kitchen/products")
      assert html =~ ~s(href="/s/dede-kitchen/category/drinks")
      assert html =~ ~s(href="/s/dede-kitchen/about")
      assert html =~ ~s(href="/s/dede-kitchen/policies)
      assert html =~ "MTN MoMo"
      assert html =~ "&copy; #{Date.utc_today().year} Dede&#39;s Kitchen"
      assert html =~ "Powered by"
    end

    test "contact links render only when the store has them" do
      html = render_footer()

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      html =
        render_footer(%{
          store:
            Map.merge(@component_store, %{
              whatsapp_number: "233200000000",
              contact_email: "chop@dede.example",
              contact_phone: "+233200000000"
            })
        })

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:chop@dede.example"
      assert html =~ "tel:+233200000000"
    end

    test "no invented SLA copy" do
      refute render_footer() =~ @invented_sla
    end
  end

  describe "whatsapp_link/2" do
    test "builds a wa.me link from digits only, with the dish in the message" do
      store = Map.put(@component_store, :whatsapp_number, "+233 20 123 4567")

      link = Shared.whatsapp_link(store, "Waakye Special")

      assert link =~ "https://wa.me/233201234567"
      assert link =~ "text="
    end

    test "percent-encodes the message so an ampersand doesn't truncate it" do
      store = Map.put(@component_store, :whatsapp_number, "233201234567")

      text_param =
        store
        |> Shared.whatsapp_link("Rice & Stew")
        |> String.split("?text=")
        |> List.last()

      refute String.contains?(text_param, "&")
      assert text_param =~ "Rice"
      assert text_param =~ "Stew"
    end

    test "returns nil without a usable number" do
      assert Shared.whatsapp_link(@component_store, "Waakye") == nil

      assert Shared.whatsapp_link(
               Map.put(@component_store, :whatsapp_number, "no digits"),
               "Waakye"
             ) == nil
    end
  end

  describe "product list page" do
    defp render_list(attrs \\ %{}) do
      %{
        store: @component_store,
        products: [dish()],
        categories: [],
        selected_category: nil,
        search_query: "",
        has_more: false,
        cart_count: 0,
        __changed__: nil
      }
      |> Map.merge(attrs)
      |> Emakola.LiveViewHelpers.with_product_stream()
      |> Dede.render_product_list()
      |> rendered_to_string()
    end

    test "carries a single h1 and the cart is reachable on desktop" do
      html = render_list()

      assert html =~ ~r/<h1[^>]*id="dede-list-heading"[^>]*>/
      assert length(String.split(html, "<h1")) == 2
      assert cart_reachable_on_desktop?(html)
    end

    test "menu rows link to the dish page — ProductListLive has no add_to_cart handler" do
      html = render_list()

      assert html =~ "Waakye Special"
      assert html =~ "GH₵ 15"
      assert html =~ ~s(href="/s/dede-kitchen/products/waakye-special")
      # A quick-add here would crash the live storefront: the list LiveView
      # exposes search/filter_category/load_more, not add_to_cart.
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "search and category filters bind to the LiveView's real handlers" do
      html =
        render_list(%{
          categories: [%{id: "cat-1", name: "Drinks", slug: "drinks"}],
          selected_category: "cat-1"
        })

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-value-category_id="cat-1")
    end

    test "load more renders only when there is more" do
      refute render_list() =~ ~s(phx-click="load_more")
      assert render_list(%{has_more: true}) =~ ~s(phx-click="load_more")
    end

    test "no matches render an intentional empty board with a way back" do
      html = render_list(%{products: [], search_query: "pizza"})

      assert html =~ "Nothing on the board matches"
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
    end

    test "sold-out dishes stay on the board, marked, without an add control" do
      html = render_list(%{products: [sold_out_dish()]})

      assert html =~ "Waakye Special"
      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
    end
  end

  describe "product detail page" do
    defp detail_assigns(attrs) do
      variant = %{
        id: "var-1",
        price: 1500,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 8,
        sku: nil
      }

      Map.merge(
        %{
          store: @component_store,
          product:
            dish(%{
              description: "Rice and beans with fried plantain.",
              avg_rating: nil,
              review_count: 0
            }),
          option_types: [],
          selected_options: %{},
          selected_variant: variant,
          quantity: 1,
          current_image_index: 0,
          related_products: [],
          categories: [],
          cart_count: 0,
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
        attrs
      )
    end

    defp render_detail(attrs \\ %{}) do
      attrs
      |> detail_assigns()
      |> Dede.render_product_detail()
      |> rendered_to_string()
    end

    test "one h1 with the dish name, price from minor units, desktop cart link" do
      html = render_detail()

      assert html =~ ~r/<h1[^>]*>\s*Waakye Special\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      assert html =~ "GH₵ 15"
      assert cart_reachable_on_desktop?(html)
    end

    test "availability is unmissable: in stock says available, ordering enabled" do
      html = render_detail()

      assert html =~ "Available now"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ "Add to order"
      refute html =~ "Sold out today"
    end

    test "sold out today disables ordering" do
      html =
        render_detail(%{
          selected_variant: %{
            id: "var-1",
            price: 1500,
            compare_at_price: nil,
            track_inventory: true,
            stock_quantity: 0,
            sku: nil
          }
        })

      assert html =~ "Sold out today"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "quantity stepper binds to the real handlers" do
      html = render_detail()

      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
    end

    test "variant options render as radio pills on the real handler" do
      html =
        render_detail(%{
          option_types: [
            %{
              id: "ot-1",
              name: "Size",
              option_values: [%{id: "ov-1", value: "Regular"}, %{id: "ov-2", value: "Large"}]
            }
          ],
          selected_options: %{"ot-1" => "ov-1"}
        })

      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id="ot-1")
      assert html =~ ~s(phx-value-option_value_id="ov-2")
      assert html =~ ~s(role="radiogroup")
      assert html =~ ~s(aria-checked="true")
    end

    test "photo-optional: no images renders the board panel, not a broken frame" do
      html = render_detail()

      refute html =~ "<img"
      refute html =~ ~s(phx-click="select_image")
    end

    test "multiple images get dot selectors on the real handler" do
      html =
        render_detail(%{
          product:
            dish(%{
              images: [%{url: "/uploads/a.jpg"}, %{url: "/uploads/b.jpg"}],
              avg_rating: nil,
              review_count: 0
            })
        })

      assert html =~ ~s(src="/uploads/a.jpg")
      assert html =~ ~s(phx-click="select_image")
    end

    test "WhatsApp ordering renders beside add-to-order when the store has a number" do
      refute render_detail() =~ "wa.me/"

      html =
        render_detail(%{
          store: Map.put(@component_store, :whatsapp_number, "233201234567")
        })

      assert html =~ "https://wa.me/233201234567"
      assert html =~ "Order on WhatsApp"
      assert html =~ "Waakye%20Special"
    end

    test "related dishes render as board rows without a quick-add" do
      html =
        render_detail(%{
          related_products: [dish(%{id: "d9", title: "Banku and Tilapia", slug: "banku"})]
        })

      assert html =~ "Also on the menu"
      assert html =~ "Banku and Tilapia"
      assert html =~ ~s(href="/s/dede-kitchen/products/banku")
      # ProductDetailLive's add_to_cart ignores the payload and adds the
      # page's own dish — a quick-add on a related row would add the wrong
      # product.
      refute html =~ ~s(phx-value-product-id="d9")
    end

    test "no invented SLA copy on the dish page" do
      refute render_detail() =~ @invented_sla
    end
  end
end
