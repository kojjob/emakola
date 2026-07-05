defmodule Emakola.Themes.Vibrant do
  @moduledoc """
  Vibrant theme — bold, energetic, West African commerce-inspired.

  Design tokens (aligned with the canonical Emakola storefront palette):
  - Primary: #B45309 (amber-700)
  - Accent: #7C2D12 (burnt orange)
  - Highlight: #F59E0B (amber-500) — used in gradients
  - Background: #FFFBEB (warm ivory) — preserved for Vibrant identity
  - Heading font: Manrope
  - Body font: Inter

  Render modules:
  - `Emakola.Themes.Vibrant.Home` — store landing page
  - `Emakola.Themes.Vibrant.ProductList` — shop / product listing
  - `Emakola.Themes.Vibrant.ProductDetail` — product detail page
  - `Emakola.Themes.Vibrant.Shared` — shared components (nav, card, circle)
  """

  def id, do: "vibrant"
  def name, do: "Vibrant"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Manrope:wght@600;700;800&family=Inter:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Vibrant theme.
  """
  def defaults do
    %{
      id: :vibrant,
      name: "Vibrant",
      colors: %{
        primary: "#B45309",
        accent: "#7C2D12",
        highlight: "#F59E0B",
        background: "#FFFBEB",
        text: "#1C1917",
        text_secondary: "#78350F",
        border: "#FDE68A"
      },
      fonts: %{
        heading: "Manrope",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Discover Unique Finds",
        subtitle: "Handcrafted with Love",
        cta_text: "Explore Now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
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
        title: "Trusted by Thousands",
        subtitle: "Shop with confidence — secure payments and fast delivery."
      },
      newsletter: %{
        title: "Join Our Community",
        subtitle: "Stay updated with the latest collections, offers, and artisan stories.",
        button_text: "Sign Up"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#B45309",
        "--theme-accent" => "#7C2D12",
        "--theme-highlight" => "#F59E0B",
        "--theme-bg" => "#FFFBEB",
        "--theme-font-heading" => "'Manrope', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Vibrant.Home
  def renderer(:product_list), do: Emakola.Themes.Vibrant.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Vibrant.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Vibrant.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Vibrant.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Vibrant.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Vibrant.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  # Vibrant's own pages borrow Atelier's footer, so only the nav is adopted
  # here — Chrome's Atelier footer fallback stays coherent for this theme.
  def storefront_nav(assigns) do
    Emakola.Themes.Vibrant.Shared.vibrant_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end
end
