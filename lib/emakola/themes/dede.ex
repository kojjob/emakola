defmodule Emakola.Themes.Dede do
  @moduledoc """
  The Dede theme — a chop-bar menu board for cooked-food sellers: jollof
  and waakye vendors, caterers, bakers, juice makers. Named the way Accra
  chop bars are named — after the woman at the pot.

  Mobile-order-first: the customer is on a phone, hungry, at lunchtime.
  The design is a painted menu board (bottle green, chalk lettering,
  prices on dotted leaders) that is complete before any photo arrives,
  with WhatsApp ordering as a first-class path in the chrome and beside
  every dish.

  Delegates rendering to specialised submodules:
  - `Emakola.Themes.Dede.Home` — store landing page
  - `Emakola.Themes.Dede.ProductList` — the full menu
  - `Emakola.Themes.Dede.ProductDetail` — single dish view
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Dede"

  def id, do: "dede"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Dede.Sections.Hero,
      Emakola.Themes.Dede.Sections.Special,
      Emakola.Themes.Dede.Sections.Categories,
      Emakola.Themes.Dede.Sections.Menu,
      Emakola.Themes.Dede.Sections.OrderInfo,
      Emakola.Themes.Dede.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Anton&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :dede,
      name: "Dede",
      colors: %{
        primary: "#8C2F0D",
        accent: "#1B2E23",
        background: "#FAF5EA",
        text: "#26211A",
        text_secondary: "#6B6355",
        border: "#E7DCC4"
      },
      fonts: %{
        heading: "Anton",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "",
        subtitle: "",
        cta_text: "Shop now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the shop...", transparent: false},
      sections: %{
        hero: true,
        special: true,
        categories: true,
        menu: true,
        order_info: true,
        newsletter: true
      },
      trust: %{
        title: "How to order",
        subtitle: "WhatsApp, mobile money, easy delivery."
      },
      newsletter: %{
        title: "Hear it first",
        subtitle: "Updates straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#8C2F0D",
        "--theme-accent" => "#1B2E23",
        "--theme-bg" => "#FAF5EA",
        "--theme-font-heading" => "'Anton', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#8C2F0D",
      "--theme-accent" => "#1B2E23",
      "--theme-bg" => "#FAF5EA"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Dede.Home
  def renderer(:product_list), do: Emakola.Themes.Dede.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Dede.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Dede.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Dede.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Dede.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Dede.ProductDetail, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Dede.Shared.dede_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Dede.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end

  @impl true
  def storefront_bottom_nav(assigns) do
    Emakola.Themes.Dede.Shared.dede_bottom_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end
end
