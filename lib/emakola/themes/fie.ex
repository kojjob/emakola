defmodule Emakola.Themes.Fie do
  @moduledoc """
  Fie theme — home & décor. "Fie" is Twi for home.

  A modernist white catalogue for furniture, textiles, ceramics, baskets
  and homeware sellers: near-white ground, a blush frame that keeps the
  whiteness from feeling clinical, and a numbered index — collections and
  pieces are numbered by their real position in browse order, because a
  décor catalogue genuinely is an indexed collection. The chrome supplies
  no colour of its own; the warmth comes from the merchant's photography,
  and every image slot is typographically composed before the photos
  arrive (see `Emakola.Themes.Fie.Components`).

  Design tokens:
  - Primary: #211C1A (warm ink — the merchant's accent lands on CTAs)
  - Accent: #8A5B4C (clay)
  - Background: #FDFCFB (warm near-white)
  - Blush frame: #F7ECE7 panels inside #EBDAD3 hairlines
  - Font: Space Grotesk (headings + catalogue numerals), Inter body

  Render modules:
  - `Emakola.Themes.Fie.Home` — store landing page (chrome + sections)
  - `Emakola.Themes.Fie.ProductList` — the full catalogue
  - `Emakola.Themes.Fie.ProductDetail` — one plate, opened
  - `Emakola.Themes.Fie.Shared` — nav, footer, helpers
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Fie"

  def id, do: "fie"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Fie.Sections.Hero,
      Emakola.Themes.Fie.Sections.CollectionIndex,
      Emakola.Themes.Fie.Sections.Catalogue,
      Emakola.Themes.Fie.Sections.Story,
      Emakola.Themes.Fie.Sections.Trust,
      Emakola.Themes.Fie.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=Inter:wght@400;500;600&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Fie theme.
  """
  def defaults do
    %{
      id: :fie,
      name: "Fie",
      colors: %{
        primary: "#211C1A",
        accent: "#8A5B4C",
        background: "#FDFCFB",
        text: "#1C1917",
        text_secondary: "#57534E",
        border: "#EBDAD3"
      },
      fonts: %{
        heading: "Space Grotesk",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "",
        subtitle: "",
        cta_text: "Browse the catalogue",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the catalogue...", transparent: false},
      sections: %{
        hero: true,
        collections: true,
        catalogue: true,
        story: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Shop with confidence",
        subtitle: "Secure payments through mobile money and card."
      },
      newsletter: %{
        title: "New pieces, first",
        subtitle: "New catalogue pages, straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: css_variables()
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#211C1A",
      "--theme-accent" => "#8A5B4C",
      "--theme-bg" => "#FDFCFB",
      "--theme-font-heading" => "'Space Grotesk', sans-serif",
      "--theme-font-body" => "'Inter', sans-serif"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Fie.Home
  def renderer(:product_list), do: Emakola.Themes.Fie.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Fie.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Fie.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Fie.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Fie.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Fie.ProductDetail, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Fie.Shared.fie_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Fie.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      theme: %{}
    })
  end
end
