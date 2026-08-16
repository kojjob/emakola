defmodule Emakola.Themes.Chale do
  @moduledoc """
  Chale theme — streetwear. Cobalt on bone, ink type.

  "Chale" is Accra's most everyday word — mate, bro. This is the theme for
  sneakers, graphic tees and caps: drop culture, Instagram-native sellers.
  The display type still does the shouting, but the surfaces no longer
  join in: bone is the ground, hairlines and soft elevation replace the
  hard black frames and offset "sticker" shadows, and the accent — a
  single confident cobalt — is spent in one place, on the buy button.
  The clothes supply the rest of the colour.

  Render modules:
  - `Emakola.Themes.Chale.Home` — store landing page (chrome + sections)
  - `Emakola.Themes.Chale.ProductList` — shop / product listing
  - `Emakola.Themes.Chale.ProductDetail` — product detail page
  - `Emakola.Themes.Chale.Shared` — chrome + cards (nav, footer, stamps)
  """

  use Phoenix.Component

  @behaviour Emakola.Themes.ThemeBehaviour

  alias Emakola.Themes.Chale.Shared

  @impl true
  def name, do: "Chale"

  def id, do: "chale"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Chale.Sections.Hero,
      Emakola.Themes.Chale.Sections.Categories,
      Emakola.Themes.Chale.Sections.Drop,
      Emakola.Themes.Chale.Sections.Grid,
      Emakola.Themes.Chale.Sections.Trust,
      Emakola.Themes.Chale.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Anton&family=Archivo:wght@400;500;600;700;800&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Chale theme.
  """
  def defaults do
    %{
      id: :chale,
      name: "Chale",
      colors: %{
        primary: "#2547E8",
        accent: "#101114",
        background: "#F7F5F1",
        text: "#101114",
        text_secondary: "#5B5750",
        border: "#E3E0DA"
      },
      fonts: %{
        heading: "Anton",
        body: "Archivo"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "",
        subtitle: "",
        cta_text: "Shop the drop",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the rack...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        drop: true,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Shop safe, chale",
        subtitle: "MoMo and card payments, processed securely."
      },
      newsletter: %{
        title: "Don't miss the next drop",
        subtitle: "New stock, straight to your inbox.",
        button_text: "Sign up"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#2547E8",
        "--theme-accent" => "#101114",
        "--theme-bg" => "#F7F5F1",
        "--theme-font-heading" => "'Anton', sans-serif",
        "--theme-font-body" => "'Archivo', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#2547E8",
      "--theme-accent" => "#101114",
      "--theme-bg" => "#F7F5F1"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Chale.Home
  def renderer(:product_list), do: Emakola.Themes.Chale.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Chale.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Chale.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Chale.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Chale.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Chale.ProductDetail, as: :render

  @impl true
  def storefront_nav(assigns) do
    # Shared pages (cart, checkout, …) render this chrome via Chrome without
    # the theme's page wrapper, so the theme_styles block must ride with the
    # nav — otherwise var(--chale-*)-styled chrome silently loses its styling.
    assigns = %{
      __changed__: nil,
      theme: Map.get(assigns, :theme) || %{},
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    }

    ~H"""
    <Shared.theme_styles theme={@theme} />
    <Shared.chale_nav store={@store} categories={@categories} cart_count={@cart_count} />
    """
  end

  @impl true
  def storefront_footer(assigns) do
    Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      theme: %{}
    })
  end
end
