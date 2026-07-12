defmodule Emakola.Themes.ChaleTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (the
  # test-only seam that lets an unregistered theme's section keys resolve
  # through Sections.resolve/1 before the central fan-out registration) —
  # must not run async with other tests touching it.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Chale
  alias Emakola.Themes.Chale.Sections.{Categories, Drop, Grid, Hero, Newsletter, Trust}
  alias Emakola.Themes.Chale.Shared

  @component_store %{
    slug: "corner",
    name: "Corner Boys",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Chale])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
    :ok
  end

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "prod-1",
        title: "Osu Tee",
        slug: "osu-tee",
        description: nil,
        min_price: 15_000,
        max_price: 15_000,
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

  defp settings_for(section, overrides \\ %{}) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    Map.merge(defaults, overrides)
  end

  # ── Theme contract ─────────────────────────────────────────────

  describe "theme contract" do
    test "id, name, fonts and renderer mapping" do
      assert Chale.id() == "chale"
      assert Chale.name() == "Chale"

      assert [font_url] = Chale.fonts()
      assert font_url =~ "fonts.googleapis.com"
      assert font_url =~ "display=swap"

      assert Chale.renderer(:home) == Emakola.Themes.Chale.Home
      assert Chale.renderer(:product_list) == Emakola.Themes.Chale.ProductList
      assert Chale.renderer(:product_detail) == Emakola.Themes.Chale.ProductDetail
    end

    test "defaults carry the starter shape with the locked palette" do
      defaults = Chale.defaults()

      # Starter's shape: colors with all six keys, typography keys, chrome maps
      for key <- [:primary, :accent, :background, :text, :text_secondary, :border] do
        assert Map.has_key?(defaults.colors, key)
      end

      for key <- [:fonts, :hero, :nav, :sections, :trust, :newsletter, :footer, :css_variables] do
        assert Map.has_key?(defaults, key)
      end

      assert %{heading: _, body: _} = defaults.fonts

      # Locked: crimson heat, concrete ground, black type
      assert defaults.colors.primary == "#DC143C"
      assert defaults.colors.background == "#F4F4F5"
      assert defaults.colors.text == "#09090B"
    end

    test "sections/0 lists the six home sections in visual order, hero first" do
      keys = Enum.map(Chale.sections(), & &1.key())

      assert keys == [
               "chale/hero",
               "chale/categories",
               "chale/drop",
               "chale/grid",
               "chale/trust",
               "chale/newsletter"
             ]
    end

    test "every settings_schema entry declares a default" do
      for section <- Chale.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end
  end

  # ── Home render through SectionRenderer ────────────────────────

  defp render_home(store) do
    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.Query.limit(8)
      |> Ash.Query.load(:variants)
      |> Ash.read!(authorize?: false)

    categories = Emakola.Catalog.list_root_categories!(store.id)

    %{
      store: store,
      products: products,
      categories: categories,
      theme: %{colors: %{}, footer: %{}},
      cart_count: 0,
      __changed__: nil
    }
    |> Chale.render_home()
    |> rendered_to_string()
  end

  describe "home render through SectionRenderer" do
    test "renders all six sections in order with their landmarks" do
      {_merchant, store} = create_merchant_with_store!()
      create_category!(store, %{name: "Snapbacks"})
      product = create_product!(store, %{title: "Jamestown Hoodie", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 5})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="chale-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Category rail
      assert html =~ ~s(aria-label="Product categories")
      assert html =~ "Snapbacks"
      # The drop — newest product with its price and add-to-cart
      assert html =~ ~s(id="chale-drop-heading")
      assert html =~ "Jamestown Hoodie"
      # Price stamped from integer minor units, tabular numerals
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # Grid
      assert html =~ ~s(id="chale-grid-heading")
      # Trust names the real rails; newsletter owns capture — exactly one form
      assert html =~ "MTN MoMo"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> categories -> drop -> grid -> trust
      # -> newsletter
      assert String.match?(
               html,
               ~r/chale-hero-heading.*Product categories.*chale-drop-heading.*chale-grid-heading.*chale-trust-heading.*chale-newsletter-form/s
             )
    end

    test "empty products and categories render an intentional empty state, not a blank page" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      refute html =~ ~s(aria-label="Product categories")
      refute html =~ ~s(id="chale-drop-heading")
      # The grid renders its setting-up state instead of vanishing
      assert html =~ "Nothing on the rack yet"
      assert html =~ "check back soon"
      # The hero still opens the page with the store name as its h1
      assert html =~ ~r/<h1[^>]*id="chale-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
    end

    test "the home page carries Chale's own chrome: skip link, banner nav, bottom nav" do
      {_merchant, store} = create_merchant_with_store!()

      html = render_home(store)

      # Skip link lands on the section content
      assert html =~ ~s(href="#chale-content")
      assert html =~ ~s(id="chale-content")
      # Banner header with cart + search, before the sections
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~r/aria-label="Search products"/
      # Mobile bottom nav
      assert html =~ ~s(href="/s/#{store.slug}/wishlist")
      # Chrome order: header -> sections -> footer (black concrete-wall footer)
      assert String.match?(html, ~r/role="banner".*chale-hero-heading.*role="contentinfo"/s)
    end
  end

  # ── Chrome components ──────────────────────────────────────────

  defp render_nav(attrs \\ %{}) do
    render_component(
      &Shared.chale_nav/1,
      Map.merge(%{store: @component_store, categories: [], cart_count: 0}, attrs)
    )
  end

  describe "chale_nav/1" do
    test "renders a sticky banner header with the store name linking home" do
      html = render_nav()

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ "sticky top-0"
      assert html =~ ~r/<a[^>]*href="\/s\/corner"[^>]*>/
      assert html =~ "Corner Boys"
    end

    test "search is reachable as a plain link to the products path" do
      html = render_nav()

      assert html =~ ~r/<a[^>]*href="\/s\/corner\/products"[^>]*aria-label="Search products"/
    end

    test "the cart link points at the store cart route and carries the live count" do
      html = render_nav(%{cart_count: 3})

      assert html =~ ~r/<a[^>]*href="\/s\/corner\/cart"/
      assert html =~ "Shopping cart, 3 items"
      assert html =~ ~r/>\s*3\s*</
    end

    test "no count badge renders for an empty cart" do
      html = render_nav(%{cart_count: 0})

      assert html =~ "Shopping cart, 0 items"
      refute html =~ ~r/bg-store-accent[^>]*>\s*0\s*</
    end

    test "category links render for desktop navigation with visible keyboard focus" do
      html =
        render_nav(%{
          categories: [
            %{name: "Snapbacks", slug: "snapbacks"},
            %{name: "Kicks", slug: "kicks"}
          ]
        })

      assert html =~ ~s(href="/s/corner/category/snapbacks")
      assert html =~ "Snapbacks"
      assert html =~ ~s(href="/s/corner/category/kicks")
      assert html =~ "focus-visible:"
    end
  end

  describe "chale_bottom_nav/1" do
    test "is mobile-only chrome with links to the real routes and the cart badge" do
      html =
        render_component(
          &Shared.chale_bottom_nav/1,
          %{store: @component_store, cart_count: 5}
        )

      assert html =~ "sm:hidden"
      assert html =~ ~r/<a[^>]*href="\/s\/corner"[^>]*>/
      assert html =~ ~s(href="/s/corner/products")
      assert html =~ ~s(href="/s/corner/wishlist")
      assert html =~ ~s(href="/s/corner/cart")
      assert html =~ ~s(aria-current="page")
      assert html =~ ~r/>\s*5\s*</
    end
  end

  describe "footer/1" do
    defp render_footer(store, attrs \\ %{}) do
      render_component(
        &Shared.footer/1,
        Map.merge(%{store: store, categories: [], theme: %{}}, attrs)
      )
    end

    test "declares the contentinfo landmark and the store identity" do
      html = render_footer(@component_store)

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "Corner Boys"
      assert html =~ "Powered by"
      assert html =~ "&copy; #{Date.utc_today().year}"
    end

    test "keeps shop and info links" do
      html =
        render_footer(@component_store, %{
          categories: [%{name: "Snapbacks", slug: "snapbacks"}]
        })

      assert html =~ ~s(href="/s/corner/products")
      assert html =~ "Snapbacks"
      assert html =~ ~s(href="/s/corner/category/snapbacks")
      assert html =~ ~s(href="/s/corner/about")
      assert html =~ ~s(href="/s/corner/faq")
      assert html =~ ~s(href="/s/corner/policies#privacy")
    end

    test "names the real payment rails and carries no newsletter form" do
      html = render_footer(@component_store)

      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
      refute html =~ ~s(phx-submit="subscribe_newsletter")
      refute html =~ ~s(type="email")
    end

    test "contact links render only when the store has them" do
      html = render_footer(@component_store)

      refute html =~ "wa.me/"
      refute html =~ "mailto:"
      refute html =~ "tel:"

      store =
        Map.merge(@component_store, %{
          whatsapp_number: "233200000000",
          contact_email: "hi@corner.example",
          contact_phone: "+233200000000"
        })

      html = render_footer(store)

      assert html =~ "wa.me/233200000000"
      assert html =~ "mailto:hi@corner.example"
      assert html =~ "tel:+233200000000"
    end
  end

  # ── Sections ───────────────────────────────────────────────────

  defp render_hero(store, overrides \\ %{}) do
    render_component(&Hero.render/1, %{store: store, settings: settings_for(Hero, overrides)})
  end

  describe "hero section" do
    test "carries the page's h1, defaulting to the store name" do
      html = render_hero(@component_store)

      assert html =~ ~r/<h1[^>]*id="chale-hero-heading"[^>]*>\s*Corner Boys\s*<\/h1>/
    end

    test "a merchant headline replaces the store name in the h1" do
      html = render_hero(@component_store, %{"headline" => "Fresh off the wall"})

      assert html =~ ~r/<h1[^>]*id="chale-hero-heading"[^>]*>\s*Fresh off the wall\s*<\/h1>/
      # The store name stays visible as the kicker
      assert html =~ "Corner Boys"
    end

    test "the subheadline falls back to the store description" do
      store = %{@component_store | description: "Streetwear from Accra."}

      html = render_hero(store)

      assert html =~ "Streetwear from Accra."

      html = render_hero(store, %{"subheadline" => "Caps, tees, kicks."})

      assert html =~ "Caps, tees, kicks."
      refute html =~ "Streetwear from Accra."
    end

    test "the CTA links to the server-generated products path" do
      html = render_hero(@component_store)

      assert html =~ ~s(href="/s/corner/products")
      assert html =~ "Shop the drop"

      html = render_hero(@component_store, %{"cta_label" => "See the heat"})

      assert html =~ "See the heat"
      refute html =~ "Shop the drop"
    end

    test "photo-optional: no image still renders a finished poster with the tape strip" do
      html = render_hero(@component_store)

      refute html =~ "<img"
      assert html =~ "Fresh stock"
      assert html =~ ~s(aria-hidden="true")
    end

    test "renders a local upload as the hero image with alt text" do
      html = render_hero(@component_store, %{"image_url" => "/uploads/wall.jpg"})

      assert html =~ ~s(src="/uploads/wall.jpg")
      assert html =~ ~s(alt="Corner Boys storefront")
    end

    test "non-local image URLs never reach the src position" do
      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_hero(@component_store, %{"image_url" => url})

        refute html =~ "<img"
        refute html =~ url
      end
    end
  end

  describe "categories section" do
    test "renders a labelled rail of category links, hidden when there are none" do
      html =
        render_component(&Categories.render/1, %{
          store: @component_store,
          categories: [%{name: "Snapbacks", slug: "snapbacks"}],
          settings: settings_for(Categories)
        })

      assert html =~ ~s(aria-label="Product categories")
      assert html =~ ~s(href="/s/corner/category/snapbacks")
      assert html =~ "Snapbacks"

      empty =
        render_component(&Categories.render/1, %{
          store: @component_store,
          categories: [],
          settings: settings_for(Categories)
        })

      refute empty =~ ~s(aria-label="Product categories")
    end
  end

  describe "drop section" do
    test "presents the newest product as the drop with price and add-to-cart" do
      newest = component_product(%{inserted_at: DateTime.utc_now()})
      older = component_product(%{id: "prod-2", title: "Old Cap", slug: "old-cap"})

      html =
        render_component(&Drop.render/1, %{
          store: @component_store,
          products: [newest, older],
          settings: settings_for(Drop)
        })

      assert html =~ "The latest drop"
      assert html =~ "Osu Tee"
      refute html =~ "Old Cap"
      assert html =~ "GH₵ 150"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
      # Genuinely recent products carry the New stamp
      assert html =~ ~r/>\s*New\s*</
    end

    test "a sold-out drop swaps the CTA for a disabled sold-out state" do
      product =
        component_product(%{
          variants: [
            %{price: 15_000, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Drop.render/1, %{
          store: @component_store,
          products: [product],
          settings: settings_for(Drop)
        })

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "renders nothing without products — the grid owns the empty state" do
      html =
        render_component(&Drop.render/1, %{
          store: @component_store,
          products: [],
          settings: settings_for(Drop)
        })

      refute html =~ "chale-drop-heading"
    end

    test "a merchant heading replaces the default" do
      html =
        render_component(&Drop.render/1, %{
          store: @component_store,
          products: [component_product()],
          settings: settings_for(Drop, %{"heading" => "Drop 04"})
        })

      assert html =~ "Drop 04"
      refute html =~ "The latest drop"
    end
  end

  describe "grid section" do
    test "renders product cards with quick add-to-cart" do
      html =
        render_component(&Grid.render/1, %{
          store: @component_store,
          products: [component_product()],
          settings: settings_for(Grid)
        })

      assert html =~ "Shop all"
      assert html =~ "Osu Tee"
      assert html =~ "GH₵ 150"
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(phx-value-product-id="prod-1")
      assert html =~ ~s(aria-label="Add Osu Tee to cart")
    end

    test "cards look finished with no image: initial and price stamp, no <img>" do
      html =
        render_component(&Grid.render/1, %{
          store: @component_store,
          products: [component_product()],
          settings: settings_for(Grid)
        })

      refute html =~ "<img"
      assert html =~ ~r/>\s*O\s*</
      assert html =~ "GH₵ 150"
    end

    test "a sold-out product shows the stamp and disables add to cart" do
      product =
        component_product(%{
          variants: [
            %{price: 15_000, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Grid.render/1, %{
          store: @component_store,
          products: [product],
          settings: settings_for(Grid)
        })

      assert html =~ "Sold out"
      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "an untracked variant keeps the product purchasable at zero stock" do
      product =
        component_product(%{
          variants: [
            %{price: 15_000, compare_at_price: nil, track_inventory: false, stock_quantity: 0}
          ]
        })

      html =
        render_component(&Grid.render/1, %{
          store: @component_store,
          products: [product],
          settings: settings_for(Grid)
        })

      refute html =~ "Sold out"
      assert html =~ ~s(phx-click="add_to_cart")
    end

    test "zero products render an intentional empty state, not nothing" do
      html =
        render_component(&Grid.render/1, %{
          store: @component_store,
          products: [],
          settings: settings_for(Grid)
        })

      assert html =~ "Nothing on the rack yet"
      assert html =~ "Corner Boys"
      assert html =~ "check back soon"
      refute html =~ "Shop all"
    end
  end

  describe "trust section" do
    defp render_trust(store, overrides \\ %{}) do
      render_component(&Trust.render/1, %{store: store, settings: settings_for(Trust, overrides)})
    end

    test "names only the payment rails the platform really supports" do
      html = render_trust(@component_store)

      assert html =~ "We accept"
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert html =~ "Visa"
      assert html =~ "Mastercard"
    end

    test "delivery and returns point at the store's own policies, with no invented SLA" do
      html = render_trust(@component_store)

      assert html =~ ~s(href="/s/corner/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "support links to WhatsApp when the store has a number, contact page otherwise" do
      html = render_trust(@component_store)

      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/corner/contact")

      html = render_trust(Map.put(@component_store, :whatsapp_number, "233200000000"))

      assert html =~ "wa.me/233200000000"
    end

    test "a merchant heading replaces the default" do
      html = render_trust(@component_store, %{"heading" => "Money safe"})

      assert html =~ "Money safe"
      refute html =~ "Shop safe, chale"
    end
  end

  describe "newsletter section" do
    test "renders the platform-handled subscribe form with honest copy" do
      html =
        render_component(&Newsletter.render/1, %{
          store: @component_store,
          settings: settings_for(Newsletter)
        })

      assert html =~ ~s(id="chale-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Sign up"
      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html =
        render_component(&Newsletter.render/1, %{
          store: @component_store,
          settings: settings_for(Newsletter, %{"heading" => "Join the crew"})
        })

      assert html =~ "Join the crew"
      refute html =~ "Don&#39;t miss the next drop"
    end
  end

  # ── Product list page ──────────────────────────────────────────

  defp render_list(attrs \\ %{}) do
    %{
      store: @component_store,
      categories: [],
      products: [component_product()],
      selected_category: nil,
      search_query: "",
      has_more: false,
      cart_count: 0,
      theme: %{colors: %{}},
      __changed__: nil
    }
    |> Map.merge(attrs)
    |> Chale.render_product_list()
    |> rendered_to_string()
  end

  describe "product list page" do
    test "renders one h1, the grid, and Chale's own chrome with a desktop cart link" do
      html = render_list()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<h1[^>]*>\s*Shop all\s*<\/h1>/
      assert html =~ "Osu Tee"
      assert html =~ "GH₵ 150"
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/corner\/cart"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "search and category filters wire to the real LiveView handlers" do
      html =
        render_list(%{
          categories: [%{id: "cat-1", name: "Snapbacks", slug: "snapbacks"}]
        })

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-value-category_id="cat-1")
    end

    test "the list page has no quick add — its LiveView has no add_to_cart handler" do
      html = render_list()

      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "load more renders only when there are more products" do
      assert render_list(%{has_more: true}) =~ ~s(phx-click="load_more")
      refute render_list(%{has_more: false}) =~ ~s(phx-click="load_more")
    end

    test "an empty result renders an intentional empty state with a clear-filters action" do
      html = render_list(%{products: [], search_query: "ghost"})

      assert html =~ "Nothing here, chale"
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ "Clear all filters"
    end
  end

  # ── Product detail page ────────────────────────────────────────

  defp detail_assigns(overrides) do
    in_stock = %{
      id: "var-s",
      price: 15_000,
      compare_at_price: nil,
      track_inventory: true,
      stock_quantity: 5,
      sku: nil
    }

    Map.merge(
      %{
        store: @component_store,
        product:
          component_product(%{
            description: "Heavy cotton, boxy fit.",
            variants: [in_stock],
            inserted_at: DateTime.utc_now()
          }),
        option_types: [],
        vov_map: %{},
        selected_options: %{},
        selected_variant: in_stock,
        quantity: 1,
        current_image_index: 0,
        related_products: [],
        categories: [],
        cart_count: 0,
        theme: %{colors: %{}},
        __changed__: nil
      },
      overrides
    )
  end

  defp render_detail(overrides \\ %{}) do
    detail_assigns(overrides)
    |> Chale.render_product_detail()
    |> rendered_to_string()
  end

  describe "product detail page" do
    test "renders the product as the single h1 with its price and add to cart" do
      html = render_detail()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ ~r/<h1[^>]*>\s*Osu Tee\s*<\/h1>/
      assert html =~ "GH₵ 150"
      assert html =~ "Heavy cotton, boxy fit."
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ "Add to cart"
      # Chrome: banner nav with a desktop cart link, footer, bottom bar
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/corner\/cart"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
    end

    test "quantity stepper wires to the real handlers with accessible labels" do
      html = render_detail()

      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
      assert html =~ ~s(aria-label="Increase quantity")
      assert html =~ ~s(aria-label="Decrease quantity")
    end

    test "the size run is legible: sold-out sizes are struck through and named" do
      option_type = %{
        id: "ot-size",
        name: "Size",
        option_values: [
          %{id: "ov-s", value: "S", option_type_id: "ot-size"},
          %{id: "ov-l", value: "L", option_type_id: "ot-size"}
        ]
      }

      in_stock = %{
        id: "var-s",
        price: 15_000,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 5,
        sku: nil
      }

      gone = %{
        id: "var-l",
        price: 15_000,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 0,
        sku: nil
      }

      html =
        render_detail(%{
          product:
            component_product(%{
              variants: [in_stock, gone],
              inserted_at: nil
            }),
          option_types: [option_type],
          vov_map: %{
            "var-s" => [%{option_value_id: "ov-s"}],
            "var-l" => [%{option_value_id: "ov-l"}]
          },
          selected_options: %{"ot-size" => "ov-s"},
          selected_variant: in_stock
        })

      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id="ot-size")
      assert html =~ ~s(phx-value-value="ov-l")
      assert html =~ ~s(aria-label="L — sold out")
      assert html =~ "line-through"
      refute html =~ ~s(aria-label="S — sold out")
    end

    test "an out-of-stock selection disables the CTA and shouts the state" do
      sold_out = %{
        id: "var-x",
        price: 15_000,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 0,
        sku: nil
      }

      html =
        render_detail(%{
          product: component_product(%{variants: [sold_out], inserted_at: nil}),
          selected_variant: sold_out
        })

      assert html =~ ~r/<button[^>]*id="chale-add-to-cart"[^>]*\sdisabled/s
      assert html =~ "Sold out"
    end

    test "low stock is called out on the selected variant" do
      low = %{
        id: "var-low",
        price: 15_000,
        compare_at_price: nil,
        track_inventory: true,
        stock_quantity: 2,
        sku: nil
      }

      html =
        render_detail(%{
          product: component_product(%{variants: [low], inserted_at: nil}),
          selected_variant: low
        })

      assert html =~ "Only 2 left"
    end

    test "gallery thumbnails wire select_image only when there are multiple images" do
      html =
        render_detail(%{
          product:
            component_product(%{
              images: [
                %{url: "/uploads/tee-front.jpg", thumbnail_url: "/uploads/tee-front-thumb.jpg"},
                %{url: "/uploads/tee-back.jpg", thumbnail_url: "/uploads/tee-back-thumb.jpg"}
              ],
              variants: [],
              inserted_at: nil
            })
        })

      assert html =~ ~s(phx-click="select_image")
      assert html =~ ~s(src="/uploads/tee-front.jpg")

      single = render_detail()
      refute single =~ ~s(phx-click="select_image")
    end

    test "WhatsApp ask renders only when the store has a number" do
      refute render_detail() =~ "Ask on WhatsApp"

      html =
        render_detail(%{store: Map.put(@component_store, :whatsapp_number, "233200000000")})

      assert html =~ "Ask on WhatsApp"
      assert html =~ "wa.me/233200000000"
    end

    test "delivery and returns defer to the store's policies — no invented SLA" do
      html = render_detail()

      assert html =~ ~s(href="/s/corner/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "related products render as links" do
      html =
        render_detail(%{
          related_products: [
            component_product(%{id: "prod-9", title: "Labadi Cap", slug: "labadi-cap"})
          ]
        })

      assert html =~ "Labadi Cap"
      assert html =~ ~s(href="/s/corner/products/labadi-cap")
    end
  end
end
