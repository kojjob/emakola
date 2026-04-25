defmodule Emakola.Themes.Maison do
  @moduledoc """
  Maison theme — restrained, photography-first, museum-grade. Built for
  premium fashion houses, designer-led labels, and editorial-driven boutiques
  in West Africa (Tongoro, Studio 189, Aimé Leon Dore territory).

  Design tokens:
  - Primary: #1C1917 (stone-900 — used for text and CTA, the dominant tone)
  - Accent: #D4A843 (warm gold — used sparingly for kickers and editorial flourish)
  - Highlight: #F5F5F4 (warm light gray — section pause backgrounds)
  - Background: #FFFFFF (stark white — lets photography breathe)
  - Heading font: Playfair Display (heavy serif display — couture register)
  - Body font: Inter 300/400 weight (clean sans, low contrast — restraint)

  Distinctive moves vs other themes:
  - Hero: full-bleed editorial photography with sparse overlay copy only
    (collection name + season), no CTA buttons crowding the image
  - Lookbook carousel — named seasonal edits, treated as content not catalogue
  - Capsule collection 3-up cards with portrait photography
  - Designer's note replaces generic about (single-column, serif-heavy)
  - Product cards are tall portrait, image dominates, name + price only —
    Maison.Shared exposes a portrait_card with hover crossfade between
    the hero shot and a detail shot
  - Footer leans editorial: stockists / press / contact, no service strip

  Render modules:
  - `Emakola.Themes.Maison.Home` — store landing page
  - `Emakola.Themes.Maison.ProductList` — shop / collection page
  - `Emakola.Themes.Maison.ProductDetail` — product detail page
  - `Emakola.Themes.Maison.Shared` — shared components (nav, portrait_card, footer)
  """

  def id, do: "maison"
  def name, do: "Maison"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,700;0,900;1,400;1,700&family=Inter:wght@300;400;500;600&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Maison theme.
  """
  def defaults do
    %{
      id: :maison,
      name: "Maison",
      colors: %{
        primary: "#1C1917",
        accent: "#D4A843",
        highlight: "#F5F5F4",
        background: "#FFFFFF",
        text: "#1C1917",
        text_secondary: "#78716C",
        border: "#E7E5E4"
      },
      fonts: %{
        heading: "Playfair Display",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "The Sahel Edit",
        subtitle: "Spring · Summer 2026",
        cta_text: "View collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the maison...", transparent: true},
      sections: %{
        hero: true,
        lookbook: true,
        capsules: true,
        featured: true,
        products: true,
        designer_note: true,
        film: false,
        newsletter: true
      },
      trust: %{
        title: "Crafted in West Africa",
        subtitle: "Made in limited runs by artisans we know by name."
      },
      newsletter: %{
        title: "Private list",
        subtitle: "Be first to see new collections, in-person trunk shows, and archive drops.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1C1917",
        "--theme-accent" => "#D4A843",
        "--theme-highlight" => "#F5F5F4",
        "--theme-bg" => "#FFFFFF",
        "--theme-font-heading" => "'Playfair Display', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Maison.Home
  def renderer(:product_list), do: Emakola.Themes.Maison.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Maison.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Maison.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Maison.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Maison.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Maison.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
