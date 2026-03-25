defmodule Emakola.Themes.Atelier do
  @moduledoc """
  Atelier - Premium fashion theme for Emakola storefronts.

  Design language:
  - Fonts: Cormorant (serif headings), Montserrat (sans body)
  - Colors: Gold (#CA8A04), Stone (#1C1917), Surface (#FAFAF9)
  - Clean, minimal, editorial feel
  - Full-screen editorial hero
  - Asymmetric masonry category grid
  - 5:6 aspect ratio product cards with hover hearts and star ratings

  All colors are exposed as CSS custom properties so merchants
  can override them via store settings.
  """

  @default_config %{
    primary_color: "#CA8A04",
    primary_light: "#EAB308",
    primary_dark: "#A16207",
    accent_color: "#1C1917",
    accent_secondary: "#44403C",
    surface_color: "#FAFAF9",
    ink_color: "#0C0A09",
    serif_font: "Cormorant",
    sans_font: "Montserrat",
    sections: %{
      hero: true,
      categories: true,
      products: true,
      brand_story: true,
      newsletter: true
    },
    hero: %{
      image_url: "",
      subtitle: "Curated Collection",
      title: "The New\nEssential",
      description: "Redefining modern luxury through timeless silhouettes and conscious craft."
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

  def fonts, do: [font_url()]

  def defaults do
    %{
      colors: %{primary: "#CA8A04", accent: "#1C1917", background: "#FAFAF9"},
      fonts: %{heading: "Cormorant", body: "Montserrat"},
      hero: %{
        image_url: "",
        title: "The New Essential",
        subtitle: "New Collection",
        cta_text: "Shop Collection",
        cta_url: "/products"
      },
      sections: %{
        hero: true,
        categories: true,
        featured_products: true,
        brand_story: true,
        instagram: true,
        newsletter: true
      }
    }
  end

  @doc """
  Merges merchant overrides into the default config.
  Accepts a map of overrides and deep-merges them.
  """
  def build_config(overrides \\ %{}) do
    deep_merge(@default_config, overrides)
  end

  @doc "Returns the Google Fonts import URL for Atelier's typefaces."
  def font_url do
    "https://fonts.googleapis.com/css2?family=Cormorant:ital,wght@0,400;0,500;0,600;0,700;1,400;1,500&family=Montserrat:wght@300;400;500;600;700&display=swap"
  end

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

  # Deep merge two maps, recursing into nested maps
  defp deep_merge(base, overrides) when is_map(base) and is_map(overrides) do
    Map.merge(base, overrides, fn
      _key, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
      _key, _v1, v2 -> v2
    end)
  end

  defp deep_merge(_base, overrides), do: overrides
end
