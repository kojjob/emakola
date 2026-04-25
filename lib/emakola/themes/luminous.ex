defmodule Emakola.Themes.Luminous do
  @moduledoc """
  Luminous theme — soft, aspirational, ingredient-honest. Built for beauty,
  cosmetics, skincare, and wellness merchants in Ghana.

  Design tokens:
  - Primary: #DB2777 (rose — beauty-brand pink that also pops on warm skin tones)
  - Accent: #E5B299 (rose-gold — luxe metallic accent for badges and dividers)
  - Highlight: #FCE7F3 (blush mist — soft card backgrounds)
  - Background: #FFFBF8 (warm ivory — softer than #FFFFFF, warmer than #FAFAF9)
  - Heading font: Cormorant Garamond (modern serif — beauty-magazine register)
  - Body font: Inter (clean sans — readable for ingredient lists)

  Distinctive moves vs other themes:
  - Browse by skin type / concern (For oily skin / For glow / For sensitive)
    instead of generic categories
  - Bundle deals carousel ("Build your routine — save 15%")
  - Ingredient transparency strip with hero ingredients per featured product
  - Before/after story cards (real customer outcomes)
  - Swatch dots on product cards (for shade-based products)
  - "Best for" badge on product cards (skin type / concern fit)
  - Newsletter framed as a skin-profile quiz CTA

  Render modules:
  - `Emakola.Themes.Luminous.Home` — store landing page
  - `Emakola.Themes.Luminous.ProductList` — shop / category listing
  - `Emakola.Themes.Luminous.ProductDetail` — product detail page
  - `Emakola.Themes.Luminous.Shared` — shared components (nav, product card, footer)
  """

  def id, do: "luminous"
  def name, do: "Luminous"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&family=Inter:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Luminous theme.
  """
  def defaults do
    %{
      id: :luminous,
      name: "Luminous",
      colors: %{
        primary: "#DB2777",
        accent: "#E5B299",
        highlight: "#FCE7F3",
        background: "#FFFBF8",
        text: "#1F1717",
        text_secondary: "#78716C",
        border: "#FBCFE8"
      },
      fonts: %{
        heading: "Cormorant Garamond",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Made for your routine",
        subtitle: "Ingredient-honest beauty crafted for African skin and weather.",
        cta_text: "Shop the routine",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        concerns: true,
        bundles: true,
        featured: true,
        ingredients: true,
        products: true,
        stories: true,
        newsletter: true
      },
      trust: %{
        title: "Honest Beauty, Real Results",
        subtitle: "Clean ingredients, transparent sourcing, dermatologist-tested."
      },
      newsletter: %{
        title: "Find your routine",
        subtitle: "Take our 60-second quiz and get a personalised routine.",
        button_text: "Take the quiz"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#DB2777",
        "--theme-accent" => "#E5B299",
        "--theme-highlight" => "#FCE7F3",
        "--theme-bg" => "#FFFBF8",
        "--theme-font-heading" => "'Cormorant Garamond', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Luminous.Home
  def renderer(:product_list), do: Emakola.Themes.Luminous.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Luminous.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Luminous.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Luminous.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Luminous.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Luminous.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
