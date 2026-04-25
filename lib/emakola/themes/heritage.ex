defmodule Emakola.Themes.Heritage do
  @moduledoc """
  Heritage theme — warm, story-driven, maker-forward. Built for lifestyle,
  home goods, crafts, and gift-driven retail in West Africa. Brother Vellies
  × Goodee × Industrie Africa register.

  Design tokens:
  - Primary: #A0522D (warm clay — earthy, hand-crafted)
  - Accent: #84A98C (sage green — natural, calming companion)
  - Highlight: #F4E4C1 (raw cream — gentle highlights)
  - Background: #FFFBEB (warm ivory — feels like newsprint)
  - Heading font: Lora (humanist serif — warm reading register)
  - Body font: Inter (clean sans — readable for maker bios)

  Distinctive moves vs other themes:
  - Browse by room / use ("For the table / For the wall / For gifting")
    instead of generic categories
  - Maker spotlights row above the fold — workshop photo, name, region,
    technique. Maker is the hero, not the object.
  - Product cards always surface "Handmade in [city]" badge
  - Featured product shown in a room-context shot, not on white background
  - "Behind the craft" story strip with thumbnails (linked to longer reads)
  - Gift bundles by occasion (Naming ceremony, Wedding, Housewarming)

  Render modules:
  - `Emakola.Themes.Heritage.Home` — store landing page
  - `Emakola.Themes.Heritage.ProductList` — shop / category listing
  - `Emakola.Themes.Heritage.ProductDetail` — product detail page
  - `Emakola.Themes.Heritage.Shared` — shared components (nav, craft_card, footer)
  """

  def id, do: "heritage"
  def name, do: "Heritage"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Lora:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Inter:wght@300;400;500;600;700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Heritage theme.
  """
  def defaults do
    %{
      id: :heritage,
      name: "Heritage",
      colors: %{
        primary: "#A0522D",
        accent: "#84A98C",
        highlight: "#F4E4C1",
        background: "#FFFBEB",
        text: "#1C1917",
        text_secondary: "#78716C",
        border: "#E7DDC7"
      },
      fonts: %{
        heading: "Lora",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Hand-built in Bonwire",
        subtitle: "Goods made by hand, kept for life.",
        cta_text: "Shop the workshop",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the workshop...", transparent: false},
      sections: %{
        hero: true,
        makers: true,
        rooms: true,
        featured: true,
        products: true,
        story: true,
        bundles: true,
        newsletter: true
      },
      trust: %{
        title: "Made by hand. Kept for life.",
        subtitle: "Each piece carries the maker's name and the marks of the craft."
      },
      newsletter: %{
        title: "From the workshop",
        subtitle:
          "Quiet updates on new makers, upcoming pieces, and the occasional behind-the-craft story.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#A0522D",
        "--theme-accent" => "#84A98C",
        "--theme-highlight" => "#F4E4C1",
        "--theme-bg" => "#FFFBEB",
        "--theme-font-heading" => "'Lora', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Heritage.Home
  def renderer(:product_list), do: Emakola.Themes.Heritage.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Heritage.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Heritage.Shared

  defdelegate render_home(assigns), to: Emakola.Themes.Heritage.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Heritage.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Heritage.ProductDetail,
    as: :render

  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render
end
