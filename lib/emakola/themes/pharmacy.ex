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
        brand_story: true,
        newsletter: true
      },
      stats: %{
        heading: "Your Trusted Healthcare Service",
        subtitle:
          "We believe in building lasting relationships with our patients, offering not just medications, but comprehensive health support that helps you live your best life.",
        items: [
          %{value: "20+", label: "Years of experience", icon: "verified"},
          %{value: "5k+", label: "Trusted brands", icon: "inventory_2"},
          %{value: "600+", label: "Global brands", icon: "public"},
          %{value: "1M", label: "Happy customers", icon: "favorite"}
        ]
      },
      trust: %{
        title: "Licensed & Trusted",
        subtitle: "Verified pharmacy. Genuine medicines. Discreet delivery.",
        items: [
          %{
            icon: "verified_user",
            label: "Licensed pharmacy",
            subtitle: "FDA Ghana approved"
          },
          %{
            icon: "local_pharmacy",
            label: "Genuine medicines",
            subtitle: "Sourced from trusted brands"
          },
          %{
            icon: "local_shipping",
            label: "Discreet delivery",
            subtitle: "Across Ghana, fast"
          }
        ]
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
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

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
