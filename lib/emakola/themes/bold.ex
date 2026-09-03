defmodule Emakola.Themes.Bold do
  @moduledoc """
  Bold theme — editorial, typography-forward, high-contrast magazine-style.

  Design tokens:
  - Primary: #0F172A (slate-900 near-black)
  - Accent: #F59E0B (amber-500 gold)
  - Background: #F8FAFC (slate-50 off-white)
  - Heading font: Outfit (bold geometric sans)
  - Body font: Inter

  Render modules:
  - `Emakola.Themes.Bold.Home` — store landing page
  - `Emakola.Themes.Bold.ProductList` — shop / product listing
  - `Emakola.Themes.Bold.ProductDetail` — product detail page
  - `Emakola.Themes.Bold.Shared` — shared components (nav, card, footer)
  """

  def id, do: "bold"
  def name, do: "Bold"

  @doc """
  Returns the home sections, in today's default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Bold.Sections.Hero,
      Emakola.Themes.Bold.Sections.Categories,
      Emakola.Themes.Bold.Sections.Featured,
      Emakola.Themes.Bold.Sections.EditorialBanner,
      Emakola.Themes.Bold.Sections.ProductGrid,
      Emakola.Themes.Bold.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800;900&family=Inter:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Bold theme.
  """
  def defaults do
    %{
      id: :bold,
      name: "Bold",
      colors: %{
        primary: "#0F172A",
        accent: "#F59E0B",
        background: "#F8FAFC",
        text: "#0F172A",
        text_secondary: "#64748B",
        border: "#E2E8F0"
      },
      fonts: %{
        heading: "Outfit",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "The Edit",
        # "Curated goods for the discerning eye" stood under every Bold store's
        # name. The hero now falls back to the store's own description; blank,
        # but the key must stay — ThemeResolver.deep_merge_atomize/2 drops any
        # override whose key is absent from the defaults.
        subtitle: nil,
        cta_text: "Shop the Collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        editorial_banner: true,
        products: true,
        newsletter: true
      },
      trust: %{
        title: "Crafted with Intent",
        subtitle: "Quality products, thoughtfully curated."
      },
      newsletter: %{
        title: "Stay in the Know",
        subtitle: "New drops, editorial picks, and exclusive access.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#0F172A",
        "--theme-accent" => "#F59E0B",
        "--theme-bg" => "#F8FAFC",
        "--theme-font-heading" => "'Outfit', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Bold.Home
  def renderer(:product_list), do: Emakola.Themes.Bold.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Bold.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Bold.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Bold.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Bold.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Bold.ProductDetail,
    as: :render

  def storefront_nav(assigns) do
    Emakola.Themes.Bold.Shared.bold_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  def storefront_footer(assigns) do
    Emakola.Themes.Bold.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end
end
