defmodule Emakola.Themes.Fresh do
  @moduledoc """
  Fresh theme — warm, organic, appetizing. Designed for food, grocery, and fresh produce stores.

  Design tokens:
  - Primary: #047857 (emerald green)
  - Accent: #92400E (warm brown)
  - Background: #FEFCE8 (warm cream)
  - Heading font: Nunito
  - Body font: Inter

  Render modules:
  - `Emakola.Themes.Fresh.Home` — store landing page
  - `Emakola.Themes.Fresh.ProductList` — shop / product listing
  - `Emakola.Themes.Fresh.ProductDetail` — product detail page
  - `Emakola.Themes.Fresh.Shared` — shared components (nav, card, circle)
  """

  def id, do: "fresh"
  def name, do: "Fresh"

  @doc """
  The home sections, in the order they render on an untouched storefront.
  """
  def sections,
    do: [
      Emakola.Themes.Fresh.Sections.Hero,
      Emakola.Themes.Fresh.Sections.CategoryCircles,
      Emakola.Themes.Fresh.Sections.Featured,
      Emakola.Themes.Fresh.Sections.DeliveryBanner,
      Emakola.Themes.Fresh.Sections.ProductGrid,
      Emakola.Themes.Fresh.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Nunito:wght@400;500;600;700;800&family=Inter:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Fresh theme.
  """
  def defaults do
    %{
      id: :fresh,
      name: "Fresh",
      colors: %{
        primary: "#047857",
        accent: "#92400E",
        background: "#FEFCE8",
        text: "#1C1917",
        text_secondary: "#78350F",
        border: "#D9F99D"
      },
      fonts: %{
        heading: "Nunito",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Fresh to Your Door",
        subtitle: "Farm-fresh groceries delivered same day in Accra",
        cta_text: "Start Shopping",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search fresh products...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        products: true,
        promo: true,
        about: true,
        newsletter: true
      },
      trust: %{
        title: "Why Shop With Us",
        subtitle: "Fresh produce, fast delivery, and secure payments you can trust."
      },
      newsletter: %{
        title: "Get Weekly Deals & Recipes",
        subtitle: "Fresh picks, seasonal specials, and recipes delivered to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#047857",
        "--theme-accent" => "#92400E",
        "--theme-bg" => "#FEFCE8",
        "--theme-font-heading" => "'Nunito', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Fresh.Home
  def renderer(:product_list), do: Emakola.Themes.Fresh.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Fresh.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Fresh.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Fresh.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Fresh.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Fresh.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  def storefront_nav(assigns) do
    Emakola.Themes.Fresh.Shared.fresh_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  def storefront_footer(assigns) do
    Emakola.Themes.Fresh.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end
end
