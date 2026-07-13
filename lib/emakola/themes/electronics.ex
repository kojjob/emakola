defmodule Emakola.Themes.Electronics do
  @moduledoc """
  Electronics theme — modern tech-forward store inspired by user-supplied
  Dribbble reference ("Upgrade Your Gear, Upgrade Yourself"): deep teal
  hero with sky-blue CTAs, cream body sections, lifestyle imagery
  alongside product shots, monospace prices for that "spec sheet" feel.

  Targets phones, accessories, computers, audio, gadgets.

  Design tokens:
  - Primary: `#134E4A` (deep teal) — hero, footer, secondary CTAs
  - Accent:  `#0EA5E9` (sky blue) — primary CTAs, "Add to Cart"
  - Background: `#F5EFE5` (cream) — body sections
  - Heading: Outfit (geometric sans)
  - Body:    Inter
  - Mono:    JetBrains Mono (prices, spec callouts)
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "electronics"

  @impl true
  def name, do: "Electronics"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Electronics.Sections.Hero,
      Emakola.Themes.Electronics.Sections.CategoryStrip,
      Emakola.Themes.Electronics.Sections.Immersive,
      Emakola.Themes.Electronics.Sections.Featured,
      Emakola.Themes.Electronics.Sections.Trust,
      Emakola.Themes.Electronics.Sections.Bestsellers,
      Emakola.Themes.Electronics.Sections.CtaBand,
      Emakola.Themes.Electronics.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap"
    ]

  def defaults do
    %{
      id: :electronics,
      name: "Electronics",
      colors: %{
        primary: "#134E4A",
        accent: "#0EA5E9",
        background: "#F5EFE5",
        text: "#1F2937",
        text_secondary: "#4B5563",
        border: "#E5E7EB",
        surface: "#FFFFFF",
        on_dark: "#F5EFE5"
      },
      fonts: %{
        heading: "Outfit",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Upgrade Your Gear",
        subtitle: "The latest phones, audio, and accessories.",
        cta_text: "Shop Now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search electronics...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        immersive: true,
        featured_products: true,
        trust: true,
        bestsellers: true,
        cta_band: true,
        newsletter: true
      },
      categories_strip: %{
        items: [
          %{label: "Wireless", active: true},
          %{label: "Noise Cancellation"},
          %{label: "Sports & Active"},
          %{label: "Phones"},
          %{label: "Wearables"}
        ]
      },
      # `subtitle: nil` and `items: []` — blank, but the keys must stay. They
      # used to ship "1-year warranty" and "Free shipping over GHS 500" as theme
      # defaults, so every Electronics store made a warranty and a shipping
      # promise its merchant had never made. There is no warranty data model to
      # derive one from, so that claim is gone outright; blank, the trust section
      # states the store's OWN delivery terms (Emakola.Themes.Delivery) and falls
      # back to the merchant's policies page when it has configured no zones.
      #
      # Do NOT delete these keys: ThemeResolver.deep_merge_atomize/2 drops any
      # override whose key is absent from the defaults, so removing them would
      # silently discard the copy of every merchant who wrote their own.
      trust: %{
        title: "Why thousands trust us",
        subtitle: nil,
        items: []
      },
      cta_band: %{
        title: "Explore our latest collection",
        subtitle: "of electronics",
        button_text: "Shop the Collection"
      },
      newsletter: %{
        title: "Subscribe to our newsletter",
        subtitle: "New launches and exclusive offers, delivered to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#134E4A",
        "--theme-accent" => "#0EA5E9",
        "--theme-bg" => "#F5EFE5",
        "--theme-font-heading" => "'Outfit', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Electronics.Home
  def renderer(:product_list), do: Emakola.Themes.Electronics.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Electronics.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Electronics.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Electronics.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.Electronics.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Electronics.ProductDetail,
    as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Electronics.Shared.electronics_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      on_dark: false
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Electronics.Shared.electronics_footer(%{
      __changed__: nil,
      store: assigns.store
    })
  end
end
