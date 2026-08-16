defmodule Emakola.Themes.Ntoma do
  @moduledoc """
  The Ntoma theme — mainstream fashion and apparel.

  "Ntoma" is Twi for cloth. Terracotta and amber on unbleached calico,
  oversized Fraunces display capitals doing the editorial work, a
  trust-badge strip, asymmetric category tiles, and a gold band that sets
  the merchant's own store name at fashion-house scale. Composed and
  intentional before any photography arrives — the type costs no bytes.

  Delegates rendering to specialised submodules:
  - `Emakola.Themes.Ntoma.Home` — store landing page
  - `Emakola.Themes.Ntoma.ProductList` — product listing / search
  - `Emakola.Themes.Ntoma.ProductDetail` — single product view
  - `Emakola.Themes.Ntoma.Shared` — nav, footer, cards, helpers
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Ntoma"

  def id, do: "ntoma"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Ntoma.Sections.Hero,
      Emakola.Themes.Ntoma.Sections.Trust,
      Emakola.Themes.Ntoma.Sections.CategoryTiles,
      Emakola.Themes.Ntoma.Sections.Wordmark,
      Emakola.Themes.Ntoma.Sections.Featured,
      Emakola.Themes.Ntoma.Sections.ProductGrid,
      Emakola.Themes.Ntoma.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&display=swap"
    ]

  @doc """
  Returns the default theme configuration for the Ntoma theme.
  """
  def defaults do
    %{
      id: :ntoma,
      name: "Ntoma",
      colors: %{
        primary: "#9E3B14",
        accent: "#E0A32E",
        background: "#FAF4EA",
        text: "#2B1708",
        text_secondary: "#7A6248",
        border: "#E6D5B8"
      },
      fonts: %{
        heading: "Fraunces",
        body: "system-ui"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Cloth, cut & craft",
        subtitle: "Tailored pieces in West African print.",
        cta_text: "Shop the collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search pieces...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured: true,
        products: true,
        trust: true,
        newsletter: true
      },
      trust: %{
        title: "Shop with confidence",
        subtitle: "Pay with mobile money or card — checkout is secure."
      },
      newsletter: %{
        title: "Join the list",
        subtitle: "New pieces and updates, straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#9E3B14",
        "--theme-accent" => "#E0A32E",
        "--theme-bg" => "#FAF4EA",
        "--theme-font-heading" => "'Fraunces', Georgia, serif",
        "--theme-font-body" => "system-ui, sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#9E3B14",
      "--theme-accent" => "#E0A32E",
      "--theme-bg" => "#FAF4EA"
    }
  end

  @doc """
  Returns the module responsible for rendering the given page type.
  """
  def renderer(:home), do: Emakola.Themes.Ntoma.Home
  def renderer(:product_list), do: Emakola.Themes.Ntoma.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Ntoma.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Ntoma.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Ntoma.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Ntoma.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Ntoma.ProductDetail, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Ntoma.Shared.ntoma_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Ntoma.Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      theme: %{}
    })
  end

  @impl true
  def storefront_bottom_nav(assigns) do
    Emakola.Themes.Ntoma.Shared.ntoma_bottom_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      active: Map.get(assigns, :active_tab) || :home
    })
  end
end
