defmodule Emakola.Themes.Vibrant do
  @moduledoc """
  Vibrant theme — bold, energetic, West African commerce-inspired.

  Design tokens:
  - Primary: #DC2626 (red)
  - Accent: #7C2D12 (burnt orange)
  - Background: #FFFBEB (warm ivory)
  - Heading font: Playfair Display
  - Body font: DM Sans

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
      "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;0,600;0,700;1,400&family=DM+Sans:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Vibrant theme.
  """
  def defaults do
    %{
      id: :vibrant,
      name: "Vibrant",
      colors: %{
        primary: "#DC2626",
        accent: "#7C2D12",
        background: "#FFFBEB",
        text: "#1C1917",
        text_secondary: "#78350F",
        border: "#FDE68A"
      },
      fonts: %{
        heading: "Playfair Display",
        body: "DM Sans"
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
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        products: true,
        promo: true,
        about: true,
        newsletter: true
      },
      css_variables: %{
        "--theme-primary" => "#DC2626",
        "--theme-accent" => "#7C2D12",
        "--theme-bg" => "#FFFBEB",
        "--theme-font-heading" => "'Playfair Display', serif",
        "--theme-font-body" => "'DM Sans', sans-serif"
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
end
