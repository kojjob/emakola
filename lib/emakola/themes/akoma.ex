defmodule Emakola.Themes.Akoma do
  @moduledoc """
  Akoma theme — clean, modern, minimal (inspired by Shopify "Be Yours").
  Forest palette: off-white background, near-black text/CTAs, deep-green accent.
  Manrope headings + Inter body.

  Render modules:
  - `Emakola.Themes.Akoma.Home`
  - `Emakola.Themes.Akoma.ProductList`
  - `Emakola.Themes.Akoma.ProductDetail`
  - `Emakola.Themes.Akoma.Shared`
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "akoma"

  @impl true
  def name, do: "Akoma"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :akoma,
      name: "Akoma",
      colors: %{
        primary: "#1A1A1A",
        accent: "#2F5D50",
        accent_dark: "#264B41",
        background: "#F8F9F7",
        text: "#1A1A1A",
        text_secondary: "#6B7280",
        border: "#E8EAE7",
        surface: "#FFFFFF"
      },
      fonts: %{heading: "Manrope", body: "Inter"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Considered goods,",
        subtitle: "made to last.",
        cta_text: "Shop the collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search products...", transparent: false},
      sections: %{
        hero: true,
        featured_in: false,
        featured_products: true,
        why_us: true,
        testimonials: false,
        faq: false,
        closing_cta: true,
        newsletter: true
      },
      trust: %{
        title: "Why shop with us",
        items: [
          %{
            icon: "verified_user",
            title: "Secure checkout",
            description: "MoMo, Paystack & cards — protected every step."
          },
          %{
            icon: "local_shipping",
            title: "Fast local delivery",
            description: "Next-day across Accra, nationwide in days."
          },
          %{
            icon: "autorenew",
            title: "Easy returns",
            description: "Not right? Return within 7 days, no fuss."
          }
        ]
      },
      newsletter: %{
        title: "Join the list",
        subtitle: "New arrivals and members-only drops, straight to your inbox.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "Find your next favourite thing",
        subtitle: "Thoughtfully made products, fairly priced.",
        button_text: "Browse all"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1A1A1A",
        "--theme-accent" => "#2F5D50",
        "--theme-bg" => "#F8F9F7",
        "--theme-font-heading" => "'Manrope', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Akoma.Home
  def renderer(:product_list), do: Emakola.Themes.Akoma.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Akoma.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Akoma.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Akoma.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Akoma.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns), to: Emakola.Themes.Akoma.ProductDetail, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Akoma.Shared.akoma_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Akoma.Shared.akoma_footer(%{__changed__: nil, store: assigns.store})
  end
end
