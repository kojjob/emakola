defmodule Emakola.Themes.Starter do
  @moduledoc """
  Starter theme -- clean, modern, minimal storefront.

  Inspired by Shopify's Dawn/Sense themes. Lots of white space,
  soft shadows, rounded corners, and a professional feel that works
  for any product category.

  Design tokens:
  - Primary: #6366F1 (indigo)
  - Accent: #1E293B (slate-dark)
  - Background: #FFFFFF (white)
  - Font: Inter (headings + body)

  Render modules:
  - `Emakola.Themes.Starter.Home` -- store landing page
  - `Emakola.Themes.Starter.ProductList` -- shop / product listing
  - `Emakola.Themes.Starter.ProductDetail` -- product detail page
  - `Emakola.Themes.Starter.Shared` -- shared components (nav, card, pill, footer)
  """

  def id, do: "starter"
  def name, do: "Starter"

  @doc """
  Returns the home sections, in today's default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Starter.Sections.Hero,
      Emakola.Themes.Starter.Sections.CategoryPills,
      Emakola.Themes.Starter.Sections.FeaturedProducts,
      Emakola.Themes.Starter.Sections.Trust,
      Emakola.Themes.Starter.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Starter theme.
  """
  def defaults do
    %{
      id: :starter,
      name: "Starter",
      colors: %{
        primary: "#6366F1",
        accent: "#1E293B",
        background: "#FFFFFF",
        text: "#0F172A",
        text_secondary: "#64748B",
        border: "#E2E8F0"
      },
      fonts: %{
        heading: "Inter",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Your New Favorite Store",
        subtitle: "Quality products, curated for you.",
        cta_text: "Shop Now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Why Shop With Us",
        subtitle: "We make shopping simple, safe, and satisfying."
      },
      newsletter: %{
        title: "Stay in the Know",
        subtitle: "Get updates on new arrivals and exclusive offers.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#6366F1",
        "--theme-accent" => "#1E293B",
        "--theme-bg" => "#FFFFFF",
        "--theme-font-heading" => "'Inter', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Starter.Home
  def renderer(:product_list), do: Emakola.Themes.Starter.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Starter.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Starter.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Starter.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Starter.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Starter.ProductDetail,
    as: :render

  def storefront_nav(assigns) do
    Emakola.Themes.Starter.Shared.starter_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  def storefront_footer(assigns) do
    Emakola.Themes.Starter.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end
end
