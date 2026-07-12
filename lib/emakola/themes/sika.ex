defmodule Emakola.Themes.Sika do
  @moduledoc """
  Sika — "gold" in Twi. The quiet-luxury theme for goldsmiths, beadmakers
  and fine-jewellery sellers: few pieces, each given room.

  Design language — gold as light, not paint:
  - Porcelain ground (#FAF9F7), warm ink (#211D16), touchstone green
    (#1F332C) for chrome and image trays.
  - Gold (#C2A15B) appears only where light would catch a polished edge:
    1px "caught light" gradient rules and the assay-ring monogram stroke.
  - The hallmark is the structural device: a square maker's-mark stamp and
    small punched hallmark chips that carry only true facts (payment
    rails, a piece's reference, availability).
  - Prices are stated plainly in tabular numerals — no chips, no
    strikethroughs, no urgency.
  - Marcellus (inscriptional Roman, the letterform of engraving) for
    display; Work Sans for body.

  Render modules:
  - `Emakola.Themes.Sika.Home` — store landing page
  - `Emakola.Themes.Sika.ProductList` — the collection
  - `Emakola.Themes.Sika.ProductDetail` — single piece
  - `Emakola.Themes.Sika.Shared` — chrome (nav, footer) and hallmark parts
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Sika"

  def id, do: "sika"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Sika.Sections.Hero,
      Emakola.Themes.Sika.Sections.Collection,
      Emakola.Themes.Sika.Sections.Maker,
      Emakola.Themes.Sika.Sections.Assurance,
      Emakola.Themes.Sika.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Marcellus&family=Work+Sans:wght@400;500;600&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Sika theme.
  """
  def defaults do
    %{
      id: :sika,
      name: "Sika",
      colors: %{
        primary: "#1F332C",
        accent: "#C2A15B",
        background: "#FAF9F7",
        text: "#211D16",
        text_secondary: "#6E675C",
        border: "#E8E3D9"
      },
      fonts: %{
        heading: "Marcellus",
        body: "Work Sans"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Gold, weighed and worked",
        subtitle: "A small collection of fine pieces.",
        cta_text: "View the collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the collection", transparent: false},
      sections: %{
        hero: true,
        categories: false,
        featured: false,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Good to know",
        subtitle: "Secure payments, and this store's own delivery and returns policies."
      },
      newsletter: %{
        title: "Private viewings",
        subtitle: "Be the first to see new pieces.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1F332C",
        "--theme-accent" => "#C2A15B",
        "--theme-bg" => "#FAF9F7",
        "--theme-font-heading" => "'Marcellus', Georgia, serif",
        "--theme-font-body" => "'Work Sans', system-ui, sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#1F332C",
      "--theme-accent" => "#C2A15B",
      "--theme-bg" => "#FAF9F7",
      "--theme-font-heading" => "'Marcellus', Georgia, serif",
      "--theme-font-body" => "'Work Sans', system-ui, sans-serif"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Sika.Home
  def renderer(:product_list), do: Emakola.Themes.Sika.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Sika.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Sika.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Sika.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Sika.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Sika.ProductDetail, as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Sika.Shared.sika_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Sika.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end
end
