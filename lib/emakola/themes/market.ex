defmodule Emakola.Themes.Market do
  @moduledoc """
  The Market theme — the default storefront theme for Emakola.

  Delegates rendering to specialised submodules:
  - `Emakola.Themes.Market.Home` — store landing page
  - `Emakola.Themes.Market.ProductList` — product listing / search
  - `Emakola.Themes.Market.ProductDetail` — single product view
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  @impl true
  def name, do: "Market"

  def id, do: "market"

  def fonts,
    do: ["https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"]

  def defaults do
    %{
      colors: %{primary: "#2563EB", accent: "#0F172A", background: "#FFFFFF"},
      fonts: %{heading: "Inter", body: "Inter"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Welcome to Our Store",
        subtitle: "Shop the latest",
        cta_text: "Shop Now",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        categories: true,
        featured_products: true,
        brand_story: true,
        instagram: false,
        newsletter: true
      },
      trust: %{
        title: "Shop with Confidence",
        subtitle: "Secure payments, fast delivery, and easy returns."
      },
      newsletter: %{
        title: "Stay in the Loop",
        subtitle: "Get the latest products, deals, and updates delivered to your inbox.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}}
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#1C1917",
      "--theme-accent" => "#B45309",
      "--theme-bg" => "#FAFAF9"
    }
  end

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Market.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Market.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Market.ProductDetail, as: :render
end
