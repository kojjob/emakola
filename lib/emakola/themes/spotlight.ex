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

  @doc """
  The "reasons it works" the merchant has written, from their theme config.

  This used to be a hardcoded list of five: "Made simply — clean, honest
  components", "Produced with attention to detail at every step", "materials
  that hold up over time", "Honest pricing with no surprises". Every Spotlight
  store published all five, on its home page and on every product page, about
  goods the platform has never seen. They were claims about manufacture, about
  materials and about pricing, and no merchant wrote a word of them.

  A merchant who can stand behind such a claim writes it. Empty, the section
  does not render.
  """
  def ingredients(theme \\ %{}) do
    case get_in(theme, [:ingredients, :items]) do
      items when is_list(items) -> Enum.filter(items, &Emakola.Themes.Item.has?(&1, :name))
      _ -> []
    end
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
      # Blank, but the key must stay. These four cards claimed, for every store
      # that installed Spotlight: "Radical transparency — clear components,
      # clearly listed", "Everyday quality", "Made with care — crafted to a
      # standard we'd be proud to use ourselves", and "Honestly made —
      # responsibly sourced and fairly priced, start to finish."
      #
      # The last is an ethical sourcing and pricing claim; the rest are claims
      # about manufacture and quality. All four were written by the theme, for
      # goods it has never seen, and shipped on by default. A merchant who can
      # stand behind such a claim writes it; blank, the section does not render.
      #
      # Do NOT delete this key: ThemeResolver.deep_merge_atomize/2 drops any
      # override whose key is absent from the defaults.
      trust: %{
        title: "What makes it different",
        items: []
      },
      # Also blank, and also a key that must survive resolution. See
      # `ingredients/1` for the five claims that used to live here.
      #
      # Wrapped in a map rather than a bare list on purpose: ThemeResolver's
      # extra_sections/2 merges merchant overrides only into MAP-valued defaults
      # and passes any other shape (a bare list included) straight through as the
      # theme default — so `ingredients: []` would have been unsettable, silently.
      ingredients: %{items: []},
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
