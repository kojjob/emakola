defmodule Emakola.Themes.Atlas do
  @moduledoc """
  Atlas theme — sidebar-driven catalog browsing for multi-category /
  department-store / curated-marketplace stores. Inspired by
  Constructor X (Spline) and the catalog/marketplace shape.

  Design tokens:
  - Primary: #0F172A (slate-900 — dark text on light background)
  - Accent: #2563EB (royal blue — links and active states)
  - Highlight: #F1F5F9 (slate-100 — sidebar background)
  - Background: #FAFAFA (off-white)
  - Heading font: Inter (clean professional sans, semibold)
  - Body font: Inter (regular for body, mono for prices)

  Distinctive moves vs other themes:
  - Persistent left sidebar (desktop) with collapsible category tree
    showing item counts per branch — the only theme with a sidebar nav
  - "News & Stories" sidebar block — content marketing alongside catalog
  - Color-coded pill prices on cards — cycles through 5 vibrant pills
    so the grid breathes with colour
  - 4-up "From the feed" / Instagram strip near the footer
  - Hero with arrow-controlled carousel and dual gendered CTA
    (Shop Women / Shop Men style adaptable per merchant)
  - Catalog-first feel: large product images with white frame, color
    swatch dots beneath each product

  Render modules:
  - `Emakola.Themes.Atlas.Home` — store landing page with sidebar
  - `Emakola.Themes.Atlas.ProductList` — sidebar-led catalog browse
  - `Emakola.Themes.Atlas.ProductDetail` — product page
  - `Emakola.Themes.Atlas.Shared` — sidebar, shelf_card, footer
  """

  def id, do: "atlas"
  def name, do: "Atlas"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Atlas theme.
  """
  def defaults do
    %{
      id: :atlas,
      name: "Atlas",
      colors: %{
        primary: "#0F172A",
        accent: "#2563EB",
        highlight: "#F1F5F9",
        background: "#FAFAFA",
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
        title: "New styles are here",
        subtitle: "Discover the latest premium pieces in our collections",
        cta_text: "Shop now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the catalog...", transparent: false},
      sections: %{
        hero: true,
        whats_new: true,
        bestsellers: true,
        feed: true,
        newsletter: true
      },
      trust: %{
        title: "Curated catalog. Considered choices.",
        subtitle: "Categories you can drill into. Brands we trust."
      },
      newsletter: %{
        title: "Sign up and save 10%",
        subtitle: "Sign up for the newsletter and get a discount on your first order.",
        button_text: "Send"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#0F172A",
        "--theme-accent" => "#2563EB",
        "--theme-highlight" => "#F1F5F9",
        "--theme-bg" => "#FAFAFA",
        "--theme-font-heading" => "'Inter', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Atlas.Home
  def renderer(:product_list), do: Emakola.Themes.Atlas.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Atlas.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Atlas.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Atlas.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Atlas.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Atlas.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
