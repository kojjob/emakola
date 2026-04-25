defmodule Emakola.Themes.Circuit do
  @moduledoc """
  Circuit theme — minimal tech / electronics retail. Built for phone shops,
  electronics retailers, gadget importers, and consumer-tech brands in Ghana.
  Apple × Nothing × Studio Display register.

  Design tokens:
  - Primary: #FFFFFF (pure white text on dark surfaces)
  - Accent: #3B82F6 (electric blue — links, focus rings, spec highlights)
  - Highlight: #1A1A1F (slightly lighter dark — card backgrounds)
  - Background: #0F0F12 (very dark blue-tinted near-black)
  - Heading font: Inter (with explicit display weight for hero)
  - Body font: Inter (clean sans for spec descriptions)
  - Numerals: JetBrains Mono (spec values, prices, model numbers)

  Distinctive moves vs other themes:
  - Dark by default (second theme in the library after Fade)
  - Spec sheet treated as content — key/value rows on PDP
  - Tech badges (5G, USB-C, IP68, etc.) on product cards
  - "Notify me" button when stock = 0 (no melodrama, just utility)
  - Product photography on white-in-dark frames (Apple-style isolation)
  - Comparison row teaser on home ("Compare iPhone 15 vs iPhone 14")
  - Spec table accordion on PDP

  Render modules:
  - `Emakola.Themes.Circuit.Home` — store landing page
  - `Emakola.Themes.Circuit.ProductList` — catalog page
  - `Emakola.Themes.Circuit.ProductDetail` — device PDP
  - `Emakola.Themes.Circuit.Shared` — shared (device_card, circuit_nav, footer)
  """

  def id, do: "circuit"
  def name, do: "Circuit"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Circuit theme.
  """
  def defaults do
    %{
      id: :circuit,
      name: "Circuit",
      colors: %{
        primary: "#FFFFFF",
        accent: "#3B82F6",
        highlight: "#1A1A1F",
        background: "#0F0F12",
        text: "#FFFFFF",
        text_secondary: "#9CA3AF",
        border: "#27272A"
      },
      fonts: %{
        heading: "Inter",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Tech, refined.",
        subtitle: "Curated electronics for the considered buyer.",
        cta_text: "Shop devices",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search devices...", transparent: false},
      sections: %{
        hero: true,
        compare: true,
        capsules: true,
        featured: true,
        products: true,
        specs: true,
        newsletter: true
      },
      trust: %{
        title: "Authentic. Warranted.",
        subtitle:
          "Every device is sealed in original packaging and backed by manufacturer warranty."
      },
      newsletter: %{
        title: "Stock alerts",
        subtitle:
          "Subscribe to be the first to hear when new devices land or popular ones restock.",
        button_text: "Notify me"
      },
      footer: %{social_links: %{instagram: "", twitter: "", youtube: ""}},
      css_variables: %{
        "--theme-primary" => "#FFFFFF",
        "--theme-accent" => "#3B82F6",
        "--theme-highlight" => "#1A1A1F",
        "--theme-bg" => "#0F0F12",
        "--theme-font-heading" => "'Inter', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Circuit.Home
  def renderer(:product_list), do: Emakola.Themes.Circuit.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Circuit.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Circuit.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Circuit.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Circuit.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Circuit.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
