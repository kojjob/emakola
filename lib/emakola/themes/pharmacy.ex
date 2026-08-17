defmodule Emakola.Themes.Pharmacy do
  @moduledoc """
  Pharmacy theme — premium wellness, trusted, accessibility-led.

  Inspired by the user-supplied Dribbble reference (Pharmaicus / "Professional
  Pharmacy Services You Can Trust") — forest-green hero, mint-green accents,
  cream paper body. Targets pharmacies, wellness shops, OTC, supplements,
  and herbal-care merchants.

  Design tokens:
  - Primary: `#14543E` (deep forest green) — hero bg, footer, primary buttons
  - Accent:  `#A7E5C5` (mint) — chips, secondary buttons
  - Background: `#F9F6F0` (cream paper)
  - Heading font: Fraunces (warm humanist serif)
  - Body font: Inter (high-legibility, min 16px)

  Render modules:
  - `Emakola.Themes.Pharmacy.Home` — landing
  - `Emakola.Themes.Pharmacy.ProductList` — shop / search
  - `Emakola.Themes.Pharmacy.ProductDetail` — product detail
  - `Emakola.Themes.Pharmacy.Shared` — shared theme_styles + nav + footer + helpers
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "pharmacy"

  @impl true
  def name, do: "Pharmacy"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Pharmacy.Sections.Hero,
      Emakola.Themes.Pharmacy.Sections.Stats,
      Emakola.Themes.Pharmacy.Sections.Trending,
      Emakola.Themes.Pharmacy.Sections.HighlightCards,
      Emakola.Themes.Pharmacy.Sections.CategoryStrip,
      Emakola.Themes.Pharmacy.Sections.ProductGrid,
      Emakola.Themes.Pharmacy.Sections.Trust,
      Emakola.Themes.Pharmacy.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600;9..144,700&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :pharmacy,
      name: "Pharmacy",
      colors: %{
        primary: "#14543E",
        accent: "#A7E5C5",
        background: "#F9F6F0",
        text: "#1F2937",
        text_secondary: "#4B5563",
        border: "#E5E7EB",
        surface: "#FFFFFF"
      },
      fonts: %{
        heading: "Fraunces",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Professional Pharmacy Services You Can Trust",
        subtitle:
          "Providing expert pharmacy care you can rely on. We are here to support your health every step of the way.",
        cta_text: "Explore Now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        stats: true,
        categories: true,
        featured_products: true,
        highlight_cards: true,
        trust: true,
        newsletter: true
      },
      # Stat items default to [] — the section only renders when the merchant
      # supplies real numbers via theme config.
      stats: %{
        heading: "Your Trusted Healthcare Service",
        subtitle:
          "We believe in building lasting relationships with our patients, offering not just medications, but comprehensive health support that helps you live your best life.",
        items: []
      },
      # Blank, but the keys must stay. This block used to certify every store
      # that installed the Pharmacy theme as a "Licensed pharmacy" selling
      # "Genuine medicines — sourced from trusted brands", under the heading
      # "Licensed & Trusted". A merchant picked a colour scheme; the platform
      # vouched for their licence and their supply chain.
      #
      # A pharmacy that IS licensed says so itself, in its own words, and owns
      # the claim. Blank, the trust strip does not render at all.
      #
      # Do NOT delete these keys: ThemeResolver.deep_merge_atomize/2 drops any
      # override whose key is absent from the defaults, so removing them would
      # silently discard the credentials of every merchant who wrote their own.
      trust: %{
        title: nil,
        subtitle: nil,
        items: []
      },
      newsletter: %{
        title: "Stay healthy, stay informed",
        subtitle:
          "Sign up to receive health tips, new product launches, and exclusive offers from our pharmacists.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#14543E",
        "--theme-accent" => "#A7E5C5",
        "--theme-bg" => "#F9F6F0",
        "--theme-font-heading" => "'Fraunces', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Pharmacy.Home
  def renderer(:product_list), do: Emakola.Themes.Pharmacy.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Pharmacy.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Pharmacy.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Pharmacy.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.Pharmacy.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Pharmacy.ProductDetail,
    as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Pharmacy.Shared.pharmacy_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Pharmacy.Shared.pharmacy_footer(%{__changed__: nil, store: assigns.store})
  end
end
