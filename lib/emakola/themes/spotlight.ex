defmodule Emakola.Themes.Spotlight do
  @moduledoc """
  Spotlight theme — for single-product stores. A lighter, immersive long-form
  landing experience for one hero product (inspired by the "LIVELY" reference):
  warm off-white background, big Archivo display type, one vibrant configurable
  accent, pill CTAs, scroll-reveal motion.

  Render modules: Spotlight.Home, Spotlight.ProductList, Spotlight.ProductDetail, Spotlight.Shared.
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "spotlight"

  @impl true
  def name, do: "Spotlight"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Archivo:wght@600;700;800;900&family=Inter:wght@400;500;600;700&display=swap"
    ]

  @doc "Home sections in visual order — the long-form single-product funnel."
  def sections,
    do: [
      Emakola.Themes.Spotlight.Sections.Hero,
      Emakola.Themes.Spotlight.Sections.Benefits,
      Emakola.Themes.Spotlight.Sections.Ingredients,
      Emakola.Themes.Spotlight.Sections.Testimonials,
      Emakola.Themes.Spotlight.Sections.ClosingCta,
      Emakola.Themes.Spotlight.Sections.Newsletter
    ]

  @doc "Ingredient/feature breakdown cards (theme-default content; not yet admin-editable)."
  def ingredients do
    [
      %{
        name: "Made simply",
        description: "Clean, honest components — nothing hidden, nothing unnecessary."
      },
      %{
        name: "Made with care",
        description: "Produced with attention to detail at every step."
      },
      %{
        name: "Everyday quality",
        description: "Built for daily use — dependable, consistent, and well-made."
      },
      %{name: "Fairly priced", description: "Honest pricing with no surprises at checkout."},
      %{
        name: "Made to last",
        description: "Considered design and materials that hold up over time."
      }
    ]
  end

  def defaults do
    %{
      id: :spotlight,
      name: "Spotlight",
      colors: %{
        primary: "#16130F",
        accent: "#7C3AED",
        accent_dark: "#6D28D9",
        accent_soft: "#EDE7FB",
        background: "#FBF9F5",
        surface: "#FFFFFF",
        text: "#16130F",
        text_secondary: "#6B675F",
        border: "#ECE7DE"
      },
      fonts: %{heading: "Archivo", body: "Inter"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        overline: "The one you reach for",
        title: "One product.",
        subtitle: "Done right.",
        tagline: "Clean, honest, and made to be part of your everyday rhythm.",
        cta_text: "Choose yours",
        cta_url: "/products",
        # No default badge — provenance claims are the merchant's to make.
        badge: nil
      },
      nav: %{search_placeholder: "Search...", transparent: false},
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
        title: "What makes it different",
        items: [
          %{
            icon: "visibility",
            title: "Radical transparency",
            description: "Clear components, clearly listed — nothing hidden."
          },
          %{
            icon: "bolt",
            title: "Everyday quality",
            description: "Dependable and consistent, built for daily use."
          },
          %{
            icon: "favorite",
            title: "Made with care",
            description: "Crafted to a standard we'd be proud to use ourselves."
          },
          %{
            icon: "eco",
            title: "Honestly made",
            description: "Responsibly sourced and fairly priced — start to finish."
          }
        ]
      },
      newsletter: %{
        title: "Stay in the loop",
        subtitle: "New drops and members-only offers, straight to your inbox.",
        button_text: "Subscribe"
      },
      closing_cta: %{
        title: "One product, done properly.",
        subtitle: "If you only make one thing, make it count.",
        button_text: "Get yours"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#16130F",
        "--theme-accent" => "#7C3AED",
        "--theme-bg" => "#FBF9F5",
        "--theme-font-heading" => "'Archivo', sans-serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Spotlight.Home
  def renderer(:product_list), do: Emakola.Themes.Spotlight.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Spotlight.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Spotlight.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Spotlight.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Spotlight.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Spotlight.ProductDetail,
    as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Spotlight.Shared.nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Spotlight.Shared.footer(%{__changed__: nil, store: assigns.store})
  end
end
