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
        title: "Elevate Your Essence",
        subtitle:
          "Botanical skincare and beauty essentials — crafted for melanin-rich skin and the rituals you love.",
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
      trust: %{
        title: "Beauty you can trust",
        subtitle: "Botanical, thoughtfully formulated, ethically sourced."
      },
      why_us: %{
        title: "Why your skin deserves the best",
        items: [
          %{
            icon: "spa",
            title: "Proven Effectiveness",
            description: "Each formula is made with active botanical ingredients you can feel."
          },
          %{
            icon: "compost",
            title: "Eco-friendly Packaging",
            description:
              "Recyclable glass jars and biodegradable inserts. Beauty that doesn't harm the planet."
          },
          %{
            icon: "local_florist",
            title: "Botanical Skin Love, Made for You",
            description:
              "Sourced from West African shea, cocoa, and baobab — gentle on melanin, kind to your routine."
          }
        ]
      },
      faq: %{
        title: "Frequently Asked Questions",
        subtitle: "Got questions? We've got answers.",
        items: [
          %{
            question: "Are your products tested for skin compatibility?",
            answer:
              "Yes — every product is tested for skin compatibility before launch and reformulated with feedback from our beauty community."
          },
          # This shipped answering "within 1–4 business days. Free delivery on
          # orders over GHS 200" for every Beauty store, none of which had set
          # either number. The FAQ is merchant-editable, so the honest default
          # is to point at the delivery terms the merchant actually configures
          # rather than to invent some.
          %{
            question: "Do you ship across Ghana?",
            answer:
              "Our delivery zones, fees and times are listed on our policies page and shown at checkout."
          },
          %{
            question: "Are your ingredients ethically sourced?",
            answer:
              "All our shea, cocoa, and baobab is sourced directly from West African women's cooperatives. Fair trade, every batch."
          },
          # This answer used to read "Unopened products can be returned within 14
          # days. We also offer a satisfaction guarantee on first-time purchases."
          # — a returns window and a guarantee shipped as a theme default, so
          # every Beauty store made both promises without a merchant ever
          # agreeing to honour either. A merchant's real window now comes from
          # their own terms (see `Emakola.Themes.Terms`) and is stated on the
          # product page; the policies page carries the detail.
          %{
            question: "What is your return policy?",
            answer: "Our returns window and warranty terms are listed on our policies page."
          }
        ]
      },
      newsletter: %{
        title: "Join the beauty list",
        subtitle: "New launches, restocks, and rituals — delivered monthly.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "Ready for flawless skin and luscious hair?",
        subtitle: "Shop the collection that's changing routines across Ghana.",
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
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

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
