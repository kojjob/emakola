defmodule Emakola.Themes.Depot do
  @moduledoc """
  The Depot theme — B2B / wholesale quick-order storefront.

  Built for suppliers whose buyers are shop owners restocking, not
  consumers browsing: the home page leads with a dense order sheet (SKU,
  price, stock on hand, add) instead of photography, the catalogue is a
  scannable table, and the product page reads like a spec sheet. Trust is
  commercial — real stock levels, payment rails, the store's own policies
  — rather than lifestyle imagery. Text-dense and image-light by design,
  which also makes it the fastest theme on metered data.

  Delegates rendering to specialised submodules:
  - `Emakola.Themes.Depot.Home` — home chrome around the section stack
  - `Emakola.Themes.Depot.ProductList` — full catalogue order table
  - `Emakola.Themes.Depot.ProductDetail` — spec-sheet product view
  - `Emakola.Themes.Depot.Shared` — nav, footer, order row, helpers
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Depot"

  def id, do: "depot"

  @doc """
  Returns the home sections, in the default visual order — the order
  sheet sits directly under the masthead because a returning trade buyer
  came to fill an order, not to browse.
  """
  def sections,
    do: [
      Emakola.Themes.Depot.Sections.Hero,
      Emakola.Themes.Depot.Sections.OrderSheet,
      Emakola.Themes.Depot.Sections.CategoryRail,
      Emakola.Themes.Depot.Sections.Terms,
      Emakola.Themes.Depot.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Depot theme.
  """
  def defaults do
    %{
      id: :depot,
      name: "Depot",
      colors: %{
        primary: "#18181B",
        accent: "#C2410C",
        background: "#FAFAFA",
        text: "#18181B",
        text_secondary: "#52525B",
        border: "#E4E4E7"
      },
      fonts: %{
        heading: "IBM Plex Sans",
        body: "IBM Plex Sans"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Wholesale, without the wait",
        subtitle: "Stock up in minutes, pay on your phone.",
        cta_text: "Browse the catalogue",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the catalogue...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "How ordering works",
        subtitle: "Order online, pay with mobile money or card."
      },
      newsletter: %{
        title: "Stock alerts",
        subtitle: "Restock and price updates, straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#18181B",
        "--theme-accent" => "#C2410C",
        "--theme-bg" => "#FAFAFA",
        "--theme-font-heading" => "'IBM Plex Sans', sans-serif",
        "--theme-font-body" => "'IBM Plex Sans', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#18181B",
      "--theme-accent" => "#C2410C",
      "--theme-bg" => "#FAFAFA"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Depot.Home
  def renderer(:product_list), do: Emakola.Themes.Depot.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Depot.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Depot.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Depot.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Depot.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Depot.ProductDetail, as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  # Depot keeps its own chrome on the fallback pages (cart, checkout,
  # account, ...) instead of swapping to Atelier's mid-funnel.
  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Depot.Shared.depot_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Depot.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      theme: %{}
    })
  end
end
