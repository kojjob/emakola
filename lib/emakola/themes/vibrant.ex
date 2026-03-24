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
end
