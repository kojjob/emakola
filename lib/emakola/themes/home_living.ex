defmodule Emakola.Themes.HomeLiving do
  @moduledoc """
  Home Living theme — modern furniture/lifestyle store inspired by two
  user-supplied Dribbble references: Furniora (dark charcoal hero, bold
  uppercase headline, lime-green accent on active nav) and Lovely Home
  (commercial furniture store with rooms grid, sale bands, popular
  products, deal-of-the-day, customer testimonials).

  Targets furniture, decor, kitchenware, lighting, and home goods
  merchants. Combines Furniora's clean editorial dark hero with Lovely
  Home's commercial e-commerce structure.

  Design tokens:
  - Primary: `#1F2937` (charcoal) — hero bg, footer, primary CTAs
  - Accent:  `#84CC16` (lime) — active nav, badges, "Sale" pills
  - Secondary: `#C2410C` (terracotta) — sale bands, deal-of-the-day
  - Background: `#FAF7F2` (oat) — body sections
  - Heading: DM Sans (modern geometric sans, bold + uppercase)
  - Body:    Inter
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "home_living"

  @impl true
  def name, do: "Home Living"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700;9..40,800&family=Inter:wght@400;500;600;700&display=swap"
    ]

  @doc "Home sections in visual order — the hero carries the theme's nav."
  def sections,
    do: [
      Emakola.Themes.HomeLiving.Sections.Hero,
      Emakola.Themes.HomeLiving.Sections.CategoryStrip,
      Emakola.Themes.HomeLiving.Sections.SaleBand,
      Emakola.Themes.HomeLiving.Sections.FeaturedProducts,
      Emakola.Themes.HomeLiving.Sections.EditorPick,
      Emakola.Themes.HomeLiving.Sections.Trust,
      Emakola.Themes.HomeLiving.Sections.BrandStory,
      Emakola.Themes.HomeLiving.Sections.Newsletter
    ]

  def defaults do
    %{
      id: :home_living,
      name: "Home Living",
      colors: %{
        primary: "#1F2937",
        accent: "#84CC16",
        secondary: "#C2410C",
        background: "#FAF7F2",
        text: "#1F2937",
        text_secondary: "#4B5563",
        border: "#E5E7EB",
        surface: "#FFFFFF",
        on_dark: "#FAF6EE"
      },
      fonts: %{
        heading: "DM Sans",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Masterpieces Crafted From Solid Wood",
        subtitle:
          "Modern furniture and home goods, made for the way you live. Free delivery on orders over GHS 500.",
        cta_text: "Explore More",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search home...", transparent: false},
      sections: %{
        hero: true,
        feature_tiles: true,
        rooms: true,
        sale_band: true,
        featured_products: true,
        editor_pick: true,
        trust: true,
        brand_story: true,
        newsletter: true
      },
      rooms: %{
        title: "Shop by room",
        items: [
          %{name: "Living Room", icon: "weekend", slug: "living"},
          %{name: "Bedroom", icon: "bed", slug: "bedroom"},
          %{name: "Kitchen", icon: "blender", slug: "kitchen"},
          %{name: "Bathroom", icon: "bathtub", slug: "bath"}
        ]
      },
      feature_tiles: %{
        items: [
          %{title: "Decor Lighting", icon: "lightbulb"},
          %{title: "Modern Sofa", icon: "weekend"}
        ]
      },
      sale_band: %{
        items: [
          %{icon: "local_shipping", title: "Free Delivery", subtitle: "On orders GHS 500+"},
          %{icon: "verified_user", title: "Safe Payment", subtitle: "Mobile money & card"},
          %{icon: "schedule", title: "Daily Curation", subtitle: "Hand-picked pieces"}
        ]
      },
      trust: %{
        title: "Crafted to live with",
        subtitle: "Quality materials, designed for everyday life.",
        items: [
          %{
            icon: "category",
            label: "Quality materials",
            subtitle: "Solid wood, natural fibres"
          },
          %{
            icon: "local_shipping",
            label: "Ships in 5 days",
            subtitle: "Across Ghana"
          },
          %{
            icon: "swap_horiz",
            label: "30-day returns",
            subtitle: "No questions asked"
          }
        ]
      },
      newsletter: %{
        title: "New pieces, in your inbox",
        subtitle: "Restocks, seasonal releases, and home inspiration — once a month.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1F2937",
        "--theme-accent" => "#84CC16",
        "--theme-bg" => "#FAF7F2",
        "--theme-font-heading" => "'DM Sans', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.HomeLiving.Home
  def renderer(:product_list), do: Emakola.Themes.HomeLiving.ProductList
  def renderer(:product_detail), do: Emakola.Themes.HomeLiving.ProductDetail
  def renderer(:shared), do: Emakola.Themes.HomeLiving.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.HomeLiving.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.HomeLiving.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.HomeLiving.ProductDetail,
    as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.HomeLiving.Shared.home_living_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      on_dark: false,
      active_path: Map.get(assigns, :active_path) || ""
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.HomeLiving.Shared.home_living_footer(%{__changed__: nil, store: assigns.store})
  end
end
