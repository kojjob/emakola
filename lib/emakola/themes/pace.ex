defmodule Emakola.Themes.Pace do
  @moduledoc """
  Pace theme — activewear and techwear storefront.

  Ice-blue ground, content on a large rounded canvas, night-gradient
  photo cards, a ghost marquee wordmark behind the hero, and kinetic
  uppercase-italic type in Chakra Petch. Motion is CSS-transform only
  and lives strictly behind `prefers-reduced-motion: no-preference`;
  every card is designed to look finished before its photo arrives.

  Render modules:
  - `Emakola.Themes.Pace.Home` — store landing page (chrome + sections)
  - `Emakola.Themes.Pace.ProductList` — shop / product listing
  - `Emakola.Themes.Pace.ProductDetail` — product detail page
  - `Emakola.Themes.Pace.Shared` — theme styles, nav, footer, helpers
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Pace"

  def id, do: "pace"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Pace.Sections.Hero,
      Emakola.Themes.Pace.Sections.CategoryRail,
      Emakola.Themes.Pace.Sections.Featured,
      Emakola.Themes.Pace.Sections.ProductGrid,
      Emakola.Themes.Pace.Sections.About,
      Emakola.Themes.Pace.Sections.Trust,
      Emakola.Themes.Pace.Sections.Newsletter
    ]

  @doc """
  One webfont only — the display face. Body text rides the platform's
  system/Inter stack, keeping page weight down on metered connections.
  """
  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Chakra+Petch:ital,wght@0,500;0,600;0,700;1,500;1,600;1,700&display=swap"
    ]

  def defaults do
    %{
      id: :pace,
      name: "Pace",
      colors: %{
        primary: "#1D4ED8",
        accent: "#0F172A",
        background: "#E6EFF6",
        text: "#0F172A",
        text_secondary: "#475569",
        border: "#CBD5E1"
      },
      fonts: %{
        heading: "Chakra Petch",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Built to move",
        subtitle: "Gear for every session.",
        cta_text: "Shop the lineup",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search gear...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Pay your way",
        subtitle: "Mobile money and card, processed securely."
      },
      newsletter: %{
        title: "Stay on pace",
        subtitle: "New drops and updates, straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1D4ED8",
        "--theme-accent" => "#0F172A",
        "--theme-bg" => "#E6EFF6",
        "--theme-font-heading" => "'Chakra Petch', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#1D4ED8",
      "--theme-accent" => "#0F172A",
      "--theme-bg" => "#E6EFF6"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Pace.Home
  def renderer(:product_list), do: Emakola.Themes.Pace.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Pace.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Pace.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Pace.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Pace.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Pace.ProductDetail, as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @doc """
  Pace's chrome on fallback storefront pages (cart, checkout, account…)
  via `Emakola.Themes.DefaultRenderers.Chrome` — keeps the store in the
  same theme mid-funnel.
  """
  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Pace.Shared.pace_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Pace.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      theme: %{}
    })
  end
end
