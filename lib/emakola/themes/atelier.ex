defmodule Emakola.Themes.Atelier do
  @moduledoc """
  Atelier - Artisan craft theme for Emakola storefronts.

  Design language (Stitch reference):
  - Fonts: System sans-serif (bold/black headings, regular body)
  - Colors: Green (#16A34A primary, #166534 accent), White (#FFFFFF surface)
  - Clean, trust-forward, artisan aesthetic
  - Full-screen hero with bold sans-serif heading
  - Horizontal scrolling category circles
  - Featured hero card + smaller product cards
  - Trust/payment section with mobile money partners

  All colors are exposed as CSS custom properties so merchants
  can override them via store settings.
  """

  @default_config %{
    primary_color: "#16A34A",
    primary_light: "#22C55E",
    primary_dark: "#166534",
    accent_color: "#166534",
    accent_secondary: "#4B5563",
    surface_color: "#FFFFFF",
    ink_color: "#1a1a1a",
    sections: %{
      hero: true,
      categories: true,
      products: true,
      trust: true,
      newsletter: true
    },
    hero: %{
      image_url: "",
      subtitle: "The 2024 Collection",
      title: "Crafting Trust,\nCurating Excellence.",
      description: "Discover handcrafted masterpieces from West Africa's finest artisans."
    },
    brand_story: %{
      image_url: "",
      since: "",
      title: "Our Story",
      text: ""
    }
  }

  @doc "Returns the default theme configuration for Atelier."
  def default_config, do: @default_config

  def id, do: "atelier"
  def name, do: "Atelier"

  @doc """
  Returns the home sections, in today's default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Atelier.Sections.Hero,
      Emakola.Themes.Atelier.Sections.CategoryCircles,
      Emakola.Themes.Atelier.Sections.FeaturedProducts,
      Emakola.Themes.Atelier.Sections.NewArrivals,
      Emakola.Themes.Atelier.Sections.Trust,
      Emakola.Themes.Atelier.Sections.DeliveryZones,
      Emakola.Themes.Atelier.Sections.Newsletter
    ]

  def fonts, do: []

  def defaults do
    %{
      colors: %{primary: "#16A34A", accent: "#166534", background: "#FFFFFF"},
      fonts: %{heading: "system-ui", body: "system-ui"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Crafting Trust,\nCurating Excellence.",
        subtitle: "The 2024 Collection",
        description:
          "Experience the soul of West African craftsmanship. Every piece tells a story of heritage, precision, and modern elegance.",
        cta_text: "Explore Masterpieces",
        cta_secondary_text: "Meet the Artisans",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured_products: true,
        brand_story: true,
        trust: true,
        instagram: false,
        newsletter: true
      },
      trust: %{
        title: "Seamless Trust. Secure Commerce.",
        subtitle: "Shop with confidence using your preferred payment method."
      },
      newsletter: %{
        title: "Join the Artisan Circle.",
        subtitle:
          "Be the first to discover new artisan collections, exclusive offers, and stories from the makers.",
        button_text: "Join Now"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}}
    }
  end

  @doc """
  Merges merchant overrides into the default config.
  Accepts a map of overrides and deep-merges them.
  """
  def build_config(overrides \\ %{}) do
    deep_merge(@default_config, overrides)
  end

  @doc "No external fonts needed — uses system sans-serif stack."
  def font_url, do: nil

  @doc "Returns the list of render modules for this theme."
  def renderers do
    %{
      home: Emakola.Themes.Atelier.Home,
      product_list: Emakola.Themes.Atelier.ProductList,
      product_detail: Emakola.Themes.Atelier.ProductDetail
    }
  end

  defdelegate render_home(assigns), to: Emakola.Themes.Atelier.Home, as: :render
  defdelegate render_product_list(assigns), to: Emakola.Themes.Atelier.ProductList, as: :render

  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Atelier.ProductDetail,
    as: :render

  defdelegate render_about(assigns),
    to: Emakola.Themes.Atelier.About,
    as: :render

  # Deep merge two maps, recursing into nested maps
  defp deep_merge(base, overrides) when is_map(base) and is_map(overrides) do
    Map.merge(base, overrides, fn
      _key, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
      _key, _v1, v2 -> v2
    end)
  end

  defp deep_merge(_base, overrides), do: overrides
end
