defmodule Emakola.Themes.Savor do
  @moduledoc """
  Savor theme — appetite-stimulating, communal, immediate. Built for restaurants,
  beverages, packaged-food brands, and dark-kitchen operators in Ghana.

  Design tokens:
  - Primary: #DC2626 (tomato red — appetite-stimulating, signals freshness)
  - Accent: #15803D (olive — pairs with red for the classic appetite palette)
  - Highlight: #FEF3C7 (butter — warm light backgrounds for cards)
  - Background: #FFFBEB (warm cream — feels like a printed menu)
  - Heading font: Anton (bold display sans, condensed — chalkboard menu energy)
  - Body font: Lora (warm humanist serif — readable, restaurant-menu register)

  Distinctive moves vs other themes:
  - Menu by meal type (Breakfast / Lunch / Dinner / Drinks) replaces the
    generic occasion edits row
  - Stock-per-day chips ("Only 5 left today") instead of generic scarcity
  - Delivery zone strip with ETA estimates above the fold
  - Dual CTA leans on WhatsApp Order + Call to Order, plus Add to Cart
  - Cash-on-delivery payment badge equal-weight with mobile money

  Render modules:
  - `Emakola.Themes.Savor.Home` — store landing page
  - `Emakola.Themes.Savor.ProductList` — menu / category listing
  - `Emakola.Themes.Savor.ProductDetail` — dish detail page
  - `Emakola.Themes.Savor.Shared` — shared components (nav, dish card, footer)
  """

  def id, do: "savor"
  def name, do: "Savor"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Anton&family=Lora:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Savor theme.
  """
  def defaults do
    %{
      id: :savor,
      name: "Savor",
      colors: %{
        primary: "#DC2626",
        accent: "#15803D",
        highlight: "#FEF3C7",
        background: "#FFFBEB",
        text: "#1C1917",
        text_secondary: "#78350F",
        border: "#FDE68A"
      },
      fonts: %{
        heading: "Anton",
        body: "Lora"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Hot from the kitchen",
        subtitle: "Daily-cooked dishes ready to deliver across Accra.",
        cta_text: "Order now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the menu...", transparent: false},
      sections: %{
        hero: true,
        menu: true,
        featured: true,
        delivery: true,
        products: true,
        favorites: true,
        story: true,
        newsletter: true
      },
      trust: %{
        title: "Made fresh, delivered fast",
        subtitle: "Cooked daily, no preservatives, hot to your door."
      },
      newsletter: %{
        title: "Today's menu, in your inbox",
        subtitle: "Be the first to know what's on tomorrow's menu and weekend specials.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#DC2626",
        "--theme-accent" => "#15803D",
        "--theme-highlight" => "#FEF3C7",
        "--theme-bg" => "#FFFBEB",
        "--theme-font-heading" => "'Anton', sans-serif",
        "--theme-font-body" => "'Lora', serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Savor.Home
  def renderer(:product_list), do: Emakola.Themes.Savor.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Savor.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Savor.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Savor.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Savor.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Savor.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
