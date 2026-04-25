defmodule Emakola.Themes.Fade do
  @moduledoc """
  Fade theme — drop-driven streetwear & urban fashion. Built for youth-led
  fashion labels, sneaker drops, and capsule streetwear in West Africa.
  Daily Paper × Off-White × Wales Bonner casual register.

  Design tokens:
  - Primary: #FAFAFA (off-white — high-contrast text on dark surfaces)
  - Accent: #00FF85 (neon green — drop-counter glow, scarcity moments)
  - Highlight: #1F1F1F (charcoal — secondary surface)
  - Background: #0A0A0A (near-black — full dark mode by default)
  - Heading font: Space Grotesk (geometric sans, bold weight)
  - Body font: Inter (clean sans for product info)
  - Drop counter font: JetBrains Mono (monospace numerals)

  Distinctive moves vs other themes:
  - Dark by default (the only dark theme in the library)
  - Live drop counter near the top — countdown to next release
  - Big-type product titles in uppercase Space Grotesk
  - "X left" scarcity chips in neon green
  - "Sold out" badge replaces price when stock = 0 (no fallback to "enquire")
  - Lookbook strip with full-bleed photography
  - Newsletter framed as "early access" — drops 24h before public
  - Footer minimal: drops calendar, returns, contact

  Render modules:
  - `Emakola.Themes.Fade.Home` — store landing page
  - `Emakola.Themes.Fade.ProductList` — drop / catalogue page
  - `Emakola.Themes.Fade.ProductDetail` — piece detail page
  - `Emakola.Themes.Fade.Shared` — shared (drop_card, fade_nav, footer)
  """

  def id, do: "fade"
  def name, do: "Fade"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Fade theme.
  """
  def defaults do
    %{
      id: :fade,
      name: "Fade",
      colors: %{
        primary: "#FAFAFA",
        accent: "#00FF85",
        highlight: "#1F1F1F",
        background: "#0A0A0A",
        text: "#FAFAFA",
        text_secondary: "#A3A3A3",
        border: "#262626"
      },
      fonts: %{
        heading: "Space Grotesk",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "DROP 04",
        subtitle: "Limited run · Friday 18:00 GMT",
        cta_text: "Notify me",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "SEARCH", transparent: false},
      sections: %{
        hero: true,
        drop_counter: true,
        capsules: true,
        featured: true,
        products: true,
        lookbook: true,
        newsletter: true
      },
      trust: %{
        title: "Limited runs. No restocks.",
        subtitle: "Once it's gone, it's gone."
      },
      newsletter: %{
        title: "Early access",
        subtitle: "Subscribe and get drops 24 hours before they go public.",
        button_text: "Get early access"
      },
      footer: %{social_links: %{instagram: "", twitter: "", tiktok: ""}},
      css_variables: %{
        "--theme-primary" => "#FAFAFA",
        "--theme-accent" => "#00FF85",
        "--theme-highlight" => "#1F1F1F",
        "--theme-bg" => "#0A0A0A",
        "--theme-font-heading" => "'Space Grotesk', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Fade.Home
  def renderer(:product_list), do: Emakola.Themes.Fade.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Fade.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Fade.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Fade.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Fade.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Fade.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
