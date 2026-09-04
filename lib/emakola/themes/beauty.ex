defmodule Emakola.Themes.Beauty do
  @moduledoc """
  Beauty theme — warm botanical luxe for cosmetics, skincare, natural hair,
  and shea-butter merchants.

  Inspired by two user-supplied Dribbble references:
  - ÉLAN BEAUTY (dark espresso editorial — typography + pill nav direction)
  - Elevate Your Essence (warm sienna ecommerce — full structure)

  Combined: warm walnut/sienna hero, gold accents, cream body, dramatic
  serif headlines, full ecommerce flow (hero / brand strip / products /
  feature cards / testimonials / FAQ / CTA / newsletter).

  Design tokens:
  - Primary: `#6B4423` (warm walnut) — hero bg, footer, dark sections
  - Accent:  `#C9925E` (warm gold) — CTAs, badges, "Add to Bag" pills
  - Background: `#F5EFE5` (warm cream)
  - Heading: Cormorant Garamond (refined serif)
  - Body:    Manrope (modern sans)

  Render modules:
  - `Emakola.Themes.Beauty.Home` — landing
  - `Emakola.Themes.Beauty.ProductList` — shop
  - `Emakola.Themes.Beauty.ProductDetail` — product detail
  - `Emakola.Themes.Beauty.Shared` — shared theme_styles + nav + footer
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "beauty"

  @impl true
  def name, do: "Beauty"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Beauty.Sections.Hero,
      Emakola.Themes.Beauty.Sections.FeaturedIn,
      Emakola.Themes.Beauty.Sections.FeaturedProducts,
      Emakola.Themes.Beauty.Sections.WhyUs,
      Emakola.Themes.Beauty.Sections.Testimonials,
      Emakola.Themes.Beauty.Sections.Faq,
      Emakola.Themes.Beauty.Sections.ClosingCta,
      Emakola.Themes.Beauty.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Manrope:wght@400;500;600;700;800&display=swap"
    ]

  def defaults do
    %{
      id: :beauty,
      name: "Beauty",
      colors: %{
        primary: "#6B4423",
        accent: "#C9925E",
        background: "#F5EFE5",
        text: "#3D2F25",
        text_secondary: "#6B4423",
        border: "#E8DBC8",
        surface: "#FFFFFF",
        on_dark: "#FAF6EE"
      },
      fonts: %{
        heading: "Cormorant Garamond",
        body: "Manrope"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        # "Elevate Your Essence" and "Botanical skincare and beauty essentials —
        # crafted for melanin-rich skin and the rituals you love." stood over
        # every Beauty store. The hero now carries the store's name and its own
        # description. Blank, but the keys must stay (see trust/why_us below).
        title: nil,
        subtitle: nil,
        cta_text: "Shop the Collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search beauty...", transparent: false},
      sections: %{
        hero: true,
        featured_in: false,
        featured_products: true,
        why_us: true,
        testimonials: true,
        faq: true,
        closing_cta: true,
        newsletter: true
      },
      # Blank, but the keys must stay. Every Beauty store used to tell shoppers
      # its products were "ethically sourced", its formulas had "Proven
      # Effectiveness", its jars were "Recyclable glass … biodegradable inserts",
      # and its ingredients were "Sourced from West African shea, cocoa, and
      # baobab". A merchant reselling imported soap published all four.
      #
      # These are claims about what is in the jar, how it was made, and what it
      # does — none of which the platform knows, and the last of which is a
      # cosmetics efficacy claim. A merchant with a real sourcing story writes it
      # here (or in the section editor) and it is theirs. Blank, nothing renders.
      #
      # Do NOT delete these keys: ThemeResolver.deep_merge_atomize/2 drops any
      # override whose key is absent from the defaults, so removing them would
      # silently discard the story of every merchant who wrote their own.
      trust: %{
        title: "Beauty you can trust",
        subtitle: nil
      },
      why_us: %{
        title: "Why buy from us",
        items: []
      },
      faq: %{
        title: "Frequently Asked Questions",
        subtitle: "Got questions? We've got answers.",
        # No default questions. Two used to sit here that presupposed their
        # answers ("Are your products tested for skin compatibility?", "Are
        # your ingredients ethically sourced?"), then two softer ones ("Do you
        # ship across Ghana?", "What is your return policy?") that still spoke
        # for a merchant who had said nothing. A question is the merchant's to
        # ask and answer; with none written the section does not render.
        items: []
      },
      newsletter: %{
        title: "Join the list",
        subtitle: "New launches and restocks, first.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "Ready when you are.",
        subtitle: "Shop the collection.",
        button_text: "Shop Now"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#6B4423",
        "--theme-accent" => "#C9925E",
        "--theme-bg" => "#F5EFE5",
        "--theme-font-heading" => "'Cormorant Garamond', serif",
        "--theme-font-body" => "'Manrope', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Beauty.Home
  def renderer(:product_list), do: Emakola.Themes.Beauty.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Beauty.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Beauty.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Beauty.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.Beauty.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Beauty.ProductDetail,
    as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Beauty.Shared.beauty_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      on_dark: false
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Beauty.Shared.beauty_footer(%{__changed__: nil, store: assigns.store})
  end
end
