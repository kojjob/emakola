defmodule Emakola.Themes.SikaTest do
  # async: false — registers Sika through the :extra_sectionized_themes
  # application-env seam (global state) so SectionRenderer can resolve
  # "sika/*" keys before the central registration lands.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  require Ash.Query

  alias Emakola.Themes.Sections
  alias Emakola.Themes.Sika
  alias Emakola.Themes.Sika.Sections.{Assurance, Collection, Hero, Maker, Newsletter}
  alias Emakola.Themes.Sika.Shared

  @section_keys [
    "sika/hero",
    "sika/collection",
    "sika/maker",
    "sika/assurance",
    "sika/newsletter"
  ]

  @component_store %{
    slug: "vitrine",
    name: "Adjoa Fine Gold",
    currency: "GHS",
    whatsapp_number: nil,
    description: nil
  }

  setup do
    Application.put_env(:emakola, :extra_sectionized_themes, [Sika])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)
  end

  # ── helpers ─────────────────────────────────────────────────────

  defp render_component(fun, assigns) do
    assigns
    |> Map.put(:__changed__, nil)
    |> fun.()
    |> rendered_to_string()
  end

  defp section_settings(section, overrides) do
    defaults =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    Map.merge(defaults, overrides)
  end

  defp render_section(section, assigns, settings_overrides \\ %{}) do
    assigns = Map.put(assigns, :settings, section_settings(section, settings_overrides))
    render_component(&section.render/1, assigns)
  end

  defp component_product(attrs \\ %{}) do
    Map.merge(
      %{
        id: "piece-1",
        title: "Nsuo Band",
        slug: "nsuo-band",
        description: nil,
        min_price: 480_000,
        max_price: 480_000,
        images: []
      },
      attrs
    )
  end

  # Same reachability rule as ThemeNavAuditTest: at least one cart link
  # that is NOT inside the mobile-only bottom bar.
  defp cart_reachable_on_desktop?(html) do
    doc = LazyHTML.from_document(html)

    total = doc |> LazyHTML.query(~s(a[href$="/cart"])) |> Enum.count()

    mobile_only =
      doc
      |> LazyHTML.query(~s(nav[class~="sm:hidden"] a[href$="/cart"]))
      |> Enum.count()

    total > mobile_only
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
      theme: Sika.defaults(),
      cart_count: 0,
      __changed__: nil
    }
    |> Sika.render_home()
    |> rendered_to_string()
  end

  # ── theme contract ──────────────────────────────────────────────

  describe "theme contract" do
    test "exposes id, name, fonts and renderers" do
      assert Sika.id() == "sika"
      assert Sika.name() == "Sika"

      assert [url] = Sika.fonts()
      assert url =~ "fonts.googleapis.com"
      assert url =~ "Marcellus"
      assert url =~ "display=swap"

      assert Sika.renderer(:home) == Emakola.Themes.Sika.Home
      assert Sika.renderer(:product_list) == Emakola.Themes.Sika.ProductList
      assert Sika.renderer(:product_detail) == Emakola.Themes.Sika.ProductDetail
    end

    test "defaults carry the starter shape: colors and typography keys" do
      defaults = Sika.defaults()

      for key <- [:primary, :accent, :background, :text, :text_secondary, :border] do
        assert is_binary(defaults.colors[key]), "colors.#{key} missing"
      end

      assert defaults.fonts.heading == "Marcellus"
      assert is_binary(defaults.fonts.body)
      assert is_map(Sika.css_variables())
    end

    test "sections/0 lists the five home sections in visual order, hero first" do
      assert Enum.map(Sika.sections(), & &1.key()) == @section_keys
    end

    test "every settings_schema entry declares a default the editor can coerce" do
      for section <- Sika.sections(), setting <- section.settings_schema() do
        assert Map.has_key?(setting, :default),
               "#{inspect(section)} setting #{inspect(setting[:key])} must declare default:"
      end
    end

    test "every section key resolves through the registry seam" do
      assert Sections.sectionized?(Sika)

      for section <- Sika.sections() do
        assert {:ok, {resolved, %{}}} = Sections.resolve(section.key())
        assert resolved == section
      end
    end
  end

  # ── home page through SectionRenderer ───────────────────────────

  describe "home render" do
    test "renders all five sections in order with one h1 and a plainly stated price" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})
      create_category!(store, %{name: "Rings"})
      product = create_product!(store, %{title: "Asase Signet", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 3})

      html = render_home(store)

      # Hero carries the page's single h1, defaulting to the store name
      assert html =~ ~r/<h1[^>]*id="sika-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      assert length(String.split(html, "<h1")) == 2
      # Collection gives the piece room and states the price plainly
      assert html =~ "The collection"
      assert html =~ "Asase Signet"
      assert html =~ "GH₵ 123.45"
      assert html =~ "tabular-nums"
      # Maker's mark section
      assert html =~ "The maker&#39;s mark"
      # Assurance names the real rails; newsletter owns capture
      assert html =~ "MTN MoMo"
      assert html =~ "Telecel Cash"
      assert html =~ "AirtelTigo Money"
      assert length(String.split(html, ~s(phx-submit="subscribe_newsletter"))) == 2

      # Flat sibling order: hero -> collection -> maker -> assurance -> newsletter
      assert String.match?(
               html,
               ~r/sika-hero-heading.*Asase Signet.*maker&#39;s mark.*We accept.*sika-newsletter-form/s
             )
    end

    test "no quick add-to-cart on home — pieces are viewed, not grabbed" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})
      product = create_product!(store, %{title: "Asase Signet", status: :active})
      create_variant!(product, store, %{price: 12_345, stock_quantity: 3})

      html = render_home(store)

      refute html =~ ~s(phx-click="add_to_cart")
      assert html =~ ~s(href="/s/#{store.slug}/products/#{product.slug}")
    end

    test "an empty store renders an intentional vitrine state, never a blank page" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})

      html = render_home(store)

      assert html =~ "The vitrine is being arranged"
      assert html =~ "return soon"
      assert html =~ ~r/<h1[^>]*id="sika-hero-heading"[^>]*>\s*#{store.name}\s*<\/h1>/
      # No urgency, ever
      refute html =~ ~r/hurry|limited time|sale ends|countdown/i
    end

    test "carries Sika's own chrome: skip link, banner nav with cart, footer, bottom bar" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})

      html = render_home(store)

      assert html =~ ~s(href="#sika-content")
      assert html =~ ~s(id="sika-content")
      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/#{store.slug}\/cart"/
      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ "sm:hidden"
      assert cart_reachable_on_desktop?(html)
    end

    test "the merchant's accent is used for the CTA instead of a hardcoded brand colour" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})

      html = render_home(store)

      assert html =~ "bg-store-accent"
    end
  end

  # ── hero section ────────────────────────────────────────────────

  describe "hero section" do
    test "h1 defaults to the store name; a merchant headline replaces it" do
      html = render_section(Hero, %{store: @component_store})
      assert html =~ ~r/<h1[^>]*>\s*Adjoa Fine Gold\s*<\/h1>/

      html = render_section(Hero, %{store: @component_store}, %{"headline" => "Worn for life"})
      assert html =~ ~r/<h1[^>]*>\s*Worn for life\s*<\/h1>/
      assert html =~ "Adjoa Fine Gold"
    end

    test "subheadline falls back to the store description" do
      store = %{@component_store | description: "Gold, weighed and worked in Accra."}

      html = render_section(Hero, %{store: store})

      assert html =~ "Gold, weighed and worked in Accra."
    end

    test "CTA links to the server-generated products path with the merchant label" do
      html = render_section(Hero, %{store: @component_store})
      assert html =~ ~s(href="/s/vitrine/products")
      assert html =~ "View the collection"

      html = render_section(Hero, %{store: @component_store}, %{"cta_label" => "See the pieces"})
      assert html =~ "See the pieces"
      refute html =~ "View the collection"
    end

    test "only local upload paths reach the image src position" do
      html = render_section(Hero, %{store: @component_store}, %{"image_url" => "/uploads/g.jpg"})
      assert html =~ ~s(src="/uploads/g.jpg")

      for url <- ["https://evil.example/x.jpg", "javascript:alert(1)", "data:text/html,x"] do
        html = render_section(Hero, %{store: @component_store}, %{"image_url" => url})
        refute html =~ "<img"
        refute html =~ url
      end
    end

    test "is finished before any image arrives: no <img>, no grey skeleton" do
      html = render_section(Hero, %{store: @component_store})

      refute html =~ "<img"
      refute html =~ "animate-pulse"
    end

    test "the price card names and prices the piece — it does not reprint its photograph" do
      product = component_product(%{images: [%{url: "/uploads/signet.jpg"}]})

      html = render_section(Hero, %{store: @component_store, products: [product]})

      # The card used to carry a 48px thumbnail of the very photograph it sits
      # on top of — the same image twice, a few pixels apart. The vitrine shows
      # the piece once; the card is its price tag.
      assert length(String.split(html, "<img")) - 1 == 1

      assert html =~ "Nsuo Band"
      assert html =~ "GH₵ 4800"
    end
  end

  # ── collection section ──────────────────────────────────────────

  describe "collection section" do
    test "each piece gets a full row: velvet tray monogram, name, plain price, view link" do
      html =
        render_section(Collection, %{
          store: @component_store,
          products: [component_product()]
        })

      # Placeholder-first: finished with zero image bytes
      refute html =~ "<img"
      assert html =~ "Nsuo Band"
      # 480_000 pesewas stated plainly — no chip, no shouting
      assert html =~ "GH₵ 4800"
      assert html =~ "tabular-nums"
      assert html =~ ~s(href="/s/vitrine/products/nsuo-band")
      assert html =~ "View piece"
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "shows at most the configured number of pieces" do
      products = for n <- 1..8, do: component_product(%{id: "p#{n}", title: "Piece #{n}"})

      html = render_section(Collection, %{store: @component_store, products: products})
      assert length(String.split(html, "View piece")) == 7

      html =
        render_section(
          Collection,
          %{store: @component_store, products: products},
          %{"limit" => 2}
        )

      assert length(String.split(html, "View piece")) == 3
    end

    test "zero products render the vitrine-being-arranged state" do
      html = render_section(Collection, %{store: @component_store, products: []})

      assert html =~ "The vitrine is being arranged"
      assert html =~ "Adjoa Fine Gold"
      refute html =~ "View piece"
    end

    test "a sold-out piece is marked quietly, without red or urgency" do
      product =
        component_product(%{
          variants: [
            %{price: 480_000, compare_at_price: nil, track_inventory: true, stock_quantity: 0}
          ]
        })

      html = render_section(Collection, %{store: @component_store, products: [product]})

      assert html =~ "Sold out"
      refute html =~ ~r/(?<![a-zA-Z])red-\d/
    end
  end

  # ── maker section ───────────────────────────────────────────────

  describe "maker section" do
    test "falls back to neutral copy and shows the maker's mark monogram" do
      html = render_section(Maker, %{store: @component_store})

      assert html =~ "The maker&#39;s mark"
      assert html =~ "chosen with care"
      refute html =~ "wa.me/"
    end

    test "renders the store description and WhatsApp enquiry when present" do
      store = %{
        @component_store
        | description: "Third-generation goldsmiths at Ashaiman.",
          whatsapp_number: "233200000000"
      }

      html = render_section(Maker, %{store: store})

      assert html =~ "Third-generation goldsmiths at Ashaiman."
      assert html =~ "wa.me/233200000000"
      assert html =~ "Ask about a piece"
    end
  end

  # ── assurance section ───────────────────────────────────────────

  describe "assurance section" do
    test "names only the rails the platform really supports, as hallmark stamps" do
      html = render_section(Assurance, %{store: @component_store})

      assert html =~ "We accept"

      for rail <- ["MTN MoMo", "Telecel Cash", "AirtelTigo Money", "Visa", "Mastercard"] do
        assert html =~ rail
      end
    end

    test "policies link to the store's own pages; no invented SLA" do
      html = render_section(Assurance, %{store: @component_store})

      assert html =~ ~s(href="/s/vitrine/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days|returns? (accepted|within) \d+\s*days?/i
    end

    test "questions go to WhatsApp when configured, the contact page otherwise" do
      html = render_section(Assurance, %{store: @component_store})
      refute html =~ "wa.me/"
      assert html =~ ~s(href="/s/vitrine/contact")

      with_number = Map.put(@component_store, :whatsapp_number, "233200000000")
      html = render_section(Assurance, %{store: with_number})
      assert html =~ "wa.me/233200000000"
    end
  end

  # ── newsletter section ──────────────────────────────────────────

  describe "newsletter section" do
    test "renders the platform-handled subscribe form" do
      html = render_section(Newsletter, %{store: @component_store})

      assert html =~ ~s(id="sika-newsletter-form")
      assert html =~ ~s(phx-submit="subscribe_newsletter")
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ "Private viewings"
    end

    test "copy is honest — no discount bait" do
      html = render_section(Newsletter, %{store: @component_store})

      refute html =~ ~r/\d+\s*%|discount|% off|free shipping/i
    end

    test "a merchant heading replaces the default" do
      html = render_section(Newsletter, %{store: @component_store}, %{"heading" => "First look"})

      assert html =~ "First look"
      refute html =~ "Private viewings"
    end
  end

  # ── nav and footer chrome ───────────────────────────────────────

  describe "sika_nav/1" do
    test "banner header: maker's mark wordmark home link, search, cart with live count" do
      html =
        render_component(
          &Shared.sika_nav/1,
          %{store: @component_store, categories: [], cart_count: 3}
        )

      assert html =~ ~r/<header[^>]*role="banner"/
      assert html =~ ~r/<a[^>]*href="\/s\/vitrine"[^>]*>/
      assert html =~ "Adjoa Fine Gold"
      assert html =~ ~r/<a[^>]*href="\/s\/vitrine\/products"[^>]*aria-label="Search products"/
      assert html =~ ~r/<a[^>]*href="\/s\/vitrine\/cart"/
      assert html =~ "Shopping cart, 3 items"
      assert html =~ ~r/>\s*3\s*</
    end

    test "no count badge for an empty cart, and category links render" do
      html =
        render_component(
          &Shared.sika_nav/1,
          %{
            store: @component_store,
            categories: [%{name: "Rings", slug: "rings"}],
            cart_count: 0
          }
        )

      assert html =~ "Shopping cart, 0 items"
      refute html =~ ~r/>\s*0\s*<\/span>/
      assert html =~ ~s(href="/s/vitrine/category/rings")
      assert html =~ "Rings"
    end
  end

  describe "footer/1" do
    test "velvet contentinfo landmark with shop links, rails and identity" do
      html =
        render_component(
          &Shared.footer/1,
          %{
            store: @component_store,
            categories: [%{name: "Rings", slug: "rings"}]
          }
        )

      assert html =~ ~r/<footer[^>]*role="contentinfo"/
      assert html =~ ~s(href="/s/vitrine/products")
      assert html =~ ~s(href="/s/vitrine/category/rings")
      assert html =~ ~s(href="/s/vitrine/about")
      assert html =~ ~s(href="/s/vitrine/faq")
      assert html =~ ~s(href="/s/vitrine/policies#privacy")
      assert html =~ "MTN MoMo"
      assert html =~ "&copy; #{Date.utc_today().year} Adjoa Fine Gold"
      assert html =~ "Powered by"
      # Capture belongs to the newsletter section, not the footer
      refute html =~ ~s(phx-submit="subscribe_newsletter")
    end
  end

  # ── product list page ───────────────────────────────────────────

  defp list_assigns(store, products, overrides \\ %{}) do
    Map.merge(
      %{
        __changed__: nil,
        store: store,
        products: products,
        categories: [],
        cart_count: 0,
        selected_category: nil,
        search_query: "",
        has_more: false
      },
      overrides
    )
  end

  describe "product list page" do
    test "renders the collection with one h1, plain prices, and desktop cart reach" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})
      product = create_product!(store, %{title: "Asase Signet", status: :active})
      create_variant!(product, store, %{price: 250_000, stock_quantity: 2})

      products =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
        |> Ash.read!(authorize?: false)

      html =
        store
        |> list_assigns(products)
        |> Sika.render_product_list()
        |> rendered_to_string()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ "The collection"
      assert html =~ "Asase Signet"
      assert html =~ "GH₵ 2500"
      assert html =~ "1 piece"
      assert cart_reachable_on_desktop?(html)
      refute html =~ ~s(phx-click="add_to_cart")
    end

    test "search, category filters and load more use the real LiveView handlers" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})
      product = create_product!(store, %{title: "Nsuo Band", status: :active})
      create_variant!(product, store, %{price: 480_000, stock_quantity: 1})

      products =
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
        |> Ash.read!(authorize?: false)

      html =
        store
        |> list_assigns(products, %{
          categories: [%{id: "cat-1", name: "Rings", slug: "rings"}],
          has_more: true,
          search_query: "band"
        })
        |> Sika.render_product_list()
        |> rendered_to_string()

      assert html =~ ~s(phx-change="search")
      assert html =~ ~s(name="query")
      assert html =~ ~s(value="band")
      assert html =~ ~s(phx-click="filter_category")
      assert html =~ ~s(phx-value-category_id="cat-1")
      assert html =~ ~s(phx-value-category_id="all")
      assert html =~ ~s(phx-click="load_more")
    end

    test "an empty filtered result offers a way back; an empty store stays composed" do
      {_merchant, store} = create_merchant_with_store!(%{theme_config: %{"theme" => "sika"}})

      filtered =
        store
        |> list_assigns([], %{search_query: "emerald"})
        |> Sika.render_product_list()
        |> rendered_to_string()

      assert filtered =~ "No pieces match"
      assert filtered =~ "Clear filters"

      empty =
        store
        |> list_assigns([])
        |> Sika.render_product_list()
        |> rendered_to_string()

      assert empty =~ "The vitrine is being arranged"
      refute empty =~ "Clear filters"
    end
  end

  # ── product detail page ─────────────────────────────────────────

  defp detail_setup do
    {_merchant, store} =
      create_merchant_with_store!(%{
        theme_config: %{"theme" => "sika"},
        whatsapp_number: "233200000000"
      })

    product = create_product!(store, %{title: "Sika Signet", status: :active})

    size = create_option_type!(product, store, %{name: "Size", position: 0})
    create_option_value!(size, store, %{value: "M", position: 0})
    create_option_value!(size, store, %{value: "L", position: 1})

    variant = create_variant!(product, store, %{price: 950_000, stock_quantity: 2, sku: "SK-001"})

    loaded_product =
      Emakola.Catalog.Product
      |> Ash.Query.filter(id == ^product.id)
      |> Ash.Query.load([:variants, :images, :min_price, :max_price])
      |> Ash.read_one!(authorize?: false)

    [option_type] =
      Emakola.Catalog.OptionType
      |> Ash.Query.filter(product_id == ^product.id)
      |> Ash.Query.load(:option_values)
      |> Ash.read!(authorize?: false)

    %{store: store, product: loaded_product, option_type: option_type, variant: variant}
  end

  defp detail_assigns(%{store: store, product: product, option_type: ot} = ctx, overrides) do
    Map.merge(
      %{
        __changed__: nil,
        store: store,
        product: product,
        related_products: [],
        categories: [],
        cart_count: 0,
        selected_variant: ctx[:variant],
        option_types: [ot],
        selected_options: %{ot.id => List.first(ot.option_values).id},
        quantity: 1,
        current_image_index: 0
      },
      overrides
    )
  end

  describe "product detail page" do
    test "one h1 title, plainly stated price, options, quantity, add to cart, WhatsApp" do
      ctx = detail_setup()
      html = ctx |> detail_assigns(%{}) |> Sika.render_product_detail() |> rendered_to_string()

      assert length(String.split(html, "<h1")) == 2
      assert html =~ "Sika Signet"
      assert html =~ "GH₵ 9500"
      assert html =~ "tabular-nums"
      # Hallmark reference stamp carries the SKU
      assert html =~ "SK-001"
      # Options fire the real handler with the real payload keys
      assert html =~ ~s(phx-click="select_option")
      assert html =~ ~s(phx-value-option_type_id=)
      assert html =~ List.first(ctx.option_type.option_values).id
      # Quantity stepper uses the real handlers
      assert html =~ ~s(phx-click="increment_quantity")
      assert html =~ ~s(phx-click="decrement_quantity")
      # Add to cart is live for an in-stock variant
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ "Add to cart"
      # Enquiry channel — how gold is actually bought
      assert html =~ "wa.me/233200000000"
      assert html =~ "Enquire on WhatsApp"
      assert cart_reachable_on_desktop?(html)
    end

    test "no variant selected: the button says so and is disabled — quietly" do
      ctx = detail_setup()

      html =
        ctx
        |> detail_assigns(%{selected_variant: nil, selected_options: %{}})
        |> Sika.render_product_detail()
        |> rendered_to_string()

      assert html =~ "Select options"
      assert html =~ ~r/<button[^>]*\sdisabled/
    end

    test "price is stated without drama: no strikethrough, no savings badge, no countdown" do
      ctx = detail_setup()
      html = ctx |> detail_assigns(%{}) |> Sika.render_product_detail() |> rendered_to_string()

      refute html =~ "line-through"
      refute html =~ ~r/you save|% off|hurry|only \d+ left|order soon/i
    end

    test "delivery and returns defer to the store's own policies" do
      ctx = detail_setup()
      html = ctx |> detail_assigns(%{}) |> Sika.render_product_detail() |> rendered_to_string()

      assert html =~ ~s(href="/s/#{ctx.store.slug}/policies)
      refute html =~ ~r/\d+(-\d+)?\s*business days/i
    end
  end
end
