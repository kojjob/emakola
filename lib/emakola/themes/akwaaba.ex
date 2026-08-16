defmodule Emakola.Themes.Akwaaba do
  @moduledoc """
  Akwaaba theme — the welcome.

  "Akwaaba" is Ghanaian for *welcome*, and that is the whole brief: a shop that
  greets you. Warm orange ground, Playfair display serif, rounded everything,
  cards that float over their panels — and, above all, **photography carrying the
  page**. Where the rest of the lineup is type-led and restrained, Akwaaba is the
  commercial storefront: the merchant's product photographs do the selling and
  the type gets out of the way.

  It is built for the seller whose Instagram is already full of good photographs
  and who wants a shop that looks like the shops they buy from.

  Render modules:
  - `Emakola.Themes.Akwaaba.Home` — landing page (chrome + sections)
  - `Emakola.Themes.Akwaaba.ProductList` — shop / listing
  - `Emakola.Themes.Akwaaba.ProductDetail` — product detail
  - `Emakola.Themes.Akwaaba.Shared` — nav, footer, cards
  """

  use Phoenix.Component

  @behaviour Emakola.Themes.ThemeBehaviour

  alias Emakola.Themes.Akwaaba.Shared

  @impl true
  def name, do: "Akwaaba"

  def id, do: "akwaaba"

  @doc "Home sections, in default visual order."
  def sections,
    do: [
      Emakola.Themes.Akwaaba.Sections.Hero,
      Emakola.Themes.Akwaaba.Sections.Usp,
      Emakola.Themes.Akwaaba.Sections.Categories,
      Emakola.Themes.Akwaaba.Sections.Collection,
      Emakola.Themes.Akwaaba.Sections.Wordmark,
      Emakola.Themes.Akwaaba.Sections.Editorial,
      Emakola.Themes.Akwaaba.Sections.Testimonials,
      Emakola.Themes.Akwaaba.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600&family=Archivo:wght@400;500;600;700&display=swap"
    ]

  @doc "Default theme configuration."
  def defaults do
    %{
      id: :akwaaba,
      name: "Akwaaba",
      colors: %{
        primary: "#F0531F",
        accent: "#F5A524",
        background: "#FFFFFF",
        text: "#101010",
        text_secondary: "#71717A",
        border: "#E4E4E7"
      },
      fonts: %{
        heading: "Playfair Display",
        body: "Archivo"
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
      nav: %{search_placeholder: "Search the shop...", transparent: true},
      sections: %{
        hero: true,
        usp: true,
        categories: true,
        collection: true,
        wordmark: true,
        editorial: true,
        testimonials: true,
        newsletter: true
      },
      trust: %{
        title: "Why shop here",
        subtitle: "Mobile money and card payments, processed securely."
      },
      newsletter: %{
        title: "Be first to know",
        subtitle: "New pieces and offers, straight to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#F0531F",
        "--theme-accent" => "#F5A524",
        "--theme-bg" => "#FFFFFF",
        "--theme-font-heading" => "'Playfair Display', Georgia, serif",
        "--theme-font-body" => "'Archivo', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#F0531F",
      "--theme-accent" => "#F5A524",
      "--theme-bg" => "#FFFFFF"
    }
  end

  @doc "The module that renders the given page type."
  def renderer(:home), do: Emakola.Themes.Akwaaba.Home
  def renderer(:product_list), do: Emakola.Themes.Akwaaba.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Akwaaba.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Akwaaba.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Akwaaba.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Akwaaba.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Akwaaba.ProductDetail,
    as: :render

  @impl true
  def storefront_nav(assigns) do
    # Shared pages (cart, checkout, …) render this chrome via Chrome without
    # the theme's page wrapper, so the theme_styles block must ride with the
    # nav — otherwise every var(--akwaaba-*)-styled element silently loses
    # its color (the cart footer rendered white-on-white this way).
    assigns = %{
      __changed__: nil,
      theme: Map.get(assigns, :theme) || %{},
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    }

    ~H"""
    <Shared.theme_styles theme={@theme} />
    <Shared.akwaaba_nav
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      overlay={false}
    />
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
