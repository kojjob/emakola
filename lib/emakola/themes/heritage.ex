defmodule Emakola.Themes.Heritage do
  @moduledoc """
  Heritage theme — for artisans, heirloom craft, leather, ceramics, kente,
  woodwork, beadwork. Inspired by an Artisan Bloom marketplace concept
  (Stitch design): deep burgundy + cream + gold, refined serif headlines,
  black "Stories from the Loom" editorial section.

  Design tokens:
  - Primary:    `#7A1F1F` (deep burgundy / wine) — CTAs, brand color
  - Accent:     `#D4A843` (warm gold) — badges, "Best Seller", trust marks
  - Background: `#FAF6EC` (cream / ivory)
  - Text:       `#3D2817` (warm dark brown)
  - On-dark:    `#F5EFE0` for the editorial black section
  - Heading:    Playfair Display (italic for accents)
  - Body:       Inter

  Render modules:
  - `Emakola.Themes.Heritage.Home` — landing
  - `Emakola.Themes.Heritage.ProductList` — shop
  - `Emakola.Themes.Heritage.ProductDetail` — product detail
  - `Emakola.Themes.Heritage.Shared` — theme_styles + nav + footer
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "heritage"

  @impl true
  def name, do: "Heritage"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;0,600;0,700;0,800;1,400;1,600&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :heritage,
      name: "Heritage",
      colors: %{
        primary: "#7A1F1F",
        accent: "#D4A843",
        background: "#FAF6EC",
        text: "#3D2817",
        text_secondary: "#6B4423",
        border: "#E8DBC2",
        surface: "#FFFFFF",
        on_dark: "#F5EFE0"
      },
      fonts: %{
        heading: "Playfair Display",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Discover Africa's",
        subtitle: "Finest Craftsmanship",
        cta_text: "Explore",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search artisans, stores, or crafts...", transparent: false},
      sections: %{
        hero: true,
        featured_in: false,
        featured_products: true,
        why_us: true,
        testimonials: true,
        faq: false,
        closing_cta: true,
        newsletter: true
      },
      trust: %{
        title: "The Maker's Mark",
        items: [
          %{
            icon: "workspace_premium",
            title: "Heritage Certified",
            description:
              "Every artisan is vetted for traditional technique and material authenticity."
          },
          %{
            icon: "handshake",
            title: "Fair Trade",
            description:
              "Direct partnerships with makers — fair wages, transparent provenance, no middlemen."
          },
          %{
            icon: "auto_stories",
            title: "Stories Behind Every Piece",
            description:
              "Each item carries the maker's story, the technique, and the lineage that shaped it."
          }
        ]
      },
      # Testimonials ship empty — the section only renders once the merchant
      # provides real customer quotes. Never fabricate social proof.
      testimonials: %{
        title: "Voices of the Collective",
        items: []
      },
      # "Stories from the Loom" editorial ships empty — the section only
      # renders once the merchant writes their own maker story.
      editorial: %{
        quote: "",
        body: ""
      },
      newsletter: %{
        title: "Join the Collective",
        subtitle: "New artisans, untold stories, and limited drops — straight to your inbox.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "Bring a piece of Africa's heritage home",
        subtitle: "Hand-crafted. Story-rich. Made to last generations.",
        button_text: "Shop the Collection"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#7A1F1F",
        "--theme-accent" => "#D4A843",
        "--theme-bg" => "#FAF6EC",
        "--theme-font-heading" => "'Playfair Display', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Heritage.Home
  def renderer(:product_list), do: Emakola.Themes.Heritage.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Heritage.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Heritage.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Heritage.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.Heritage.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Heritage.ProductDetail,
    as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Heritage.Shared.heritage_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      on_dark: false
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Heritage.Shared.heritage_footer(%{__changed__: nil, store: assigns.store})
  end
end
