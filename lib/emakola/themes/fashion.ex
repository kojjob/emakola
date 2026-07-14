defmodule Emakola.Themes.Fashion do
  @moduledoc """
  Fashion theme — editorial magazine-style for boutiques selling
  Ankara, kente, ready-to-wear, accessories, and luxury fashion.

  Direction: oversized Playfair Display headlines, magazine-cover
  hero with "Volume / Issue" marker, lookbook grids, gold pill
  badges, editorial paragraphs introducing each section. Inspired
  by Mango, Squarespace storytelling templates, and East African
  diaspora boutiques.

  Design tokens:
  - Primary: `#5B21B6` (deep aubergine) — hero overlay, footer
  - Accent:  `#D97706` (warm gold) — pills, badges, CTA accents
  - Background: `#FAF6EE` (warm cream)
  - Heading: Playfair Display (dramatic editorial serif)
  - Body:    Inter
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  def id, do: "fashion"

  @impl true
  def name, do: "Fashion"

  @doc """
  Returns the home sections, in the default visual order.
  """
  def sections,
    do: [
      Emakola.Themes.Fashion.Sections.Hero,
      Emakola.Themes.Fashion.Sections.EditorialIntro,
      Emakola.Themes.Fashion.Sections.Lookbook,
      Emakola.Themes.Fashion.Sections.FeaturedProducts,
      Emakola.Themes.Fashion.Sections.NewArrivalsBand,
      Emakola.Themes.Fashion.Sections.Ugc,
      Emakola.Themes.Fashion.Sections.BrandStory,
      Emakola.Themes.Fashion.Sections.Newsletter
    ]

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400;0,500;0,600;0,700;0,800;0,900;1,400&family=Inter:wght@400;500;600;700&display=swap"
    ]

  def defaults do
    %{
      id: :fashion,
      name: "Fashion",
      colors: %{
        primary: "#5B21B6",
        accent: "#D97706",
        background: "#FAF6EE",
        text: "#1C1917",
        text_secondary: "#57534E",
        border: "#E7E5E4",
        surface: "#FFFFFF",
        on_dark: "#FAF6EE"
      },
      fonts: %{
        heading: "Playfair Display",
        body: "Inter"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        # Was "Made by Tailors. Worn by You." — the page's h1 on every Fashion
        # store, telling the shopper who sewed the clothes. Nobody knew.
        title: "The new collection",
        subtitle:
          "Curated drops in Ankara, kente, and ready-to-wear — designed in Accra, shipped across Ghana.",
        cta_text: "Shop the Drop",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search fashion...", transparent: false},
      sections: %{
        hero: true,
        editorial_intro: true,
        lookbook: true,
        featured_products: true,
        new_arrivals_band: true,
        # UGC strip is placeholder-only until real customer photos exist —
        # off by default; merchants opt in explicitly.
        ugc: false,
        brand_story: true,
        newsletter: true
      },
      # `title` and `body` blank, but the keys must stay. The body used to credit
      # two workshops that DO NOT EXIST — "the bold Ankara prints of the Mensah
      # collective", "the heritage kente of the Kwame house" — and told every
      # shopper each piece was "sewn in small batches by tailors and artisans
      # across Accra". A shop reselling imported dresses published all of it.
      #
      # Who made the clothes is the shop's claim to make. Blank, the section does
      # not render; a merchant who writes their story gets exactly their story.
      #
      # Do NOT delete these keys: ThemeResolver.deep_merge_atomize/2 drops any
      # override whose key is absent from the defaults.
      editorial_intro: %{
        eyebrow: "From the Editor",
        title: nil,
        body: nil
      },
      newsletter: %{
        title: "First access. No noise.",
        subtitle: "Be the first to shop new drops, runway looks, and editor picks.",
        button_text: "Join the List"
      },
      # "Crafted with care / Made by tailors. Worn by you." — who sewed the
      # clothes, asserted for every shop on the theme. The heading stays (it
      # claims nothing); the maker claim is the merchant's to write.
      trust: %{
        title: "Chosen with care",
        subtitle: nil
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#5B21B6",
        "--theme-accent" => "#D97706",
        "--theme-bg" => "#FAF6EE",
        "--theme-font-heading" => "'Playfair Display', serif",
        "--theme-font-body" => "'Inter', sans-serif"
      }
    }
  end

  @impl true
  def css_variables, do: defaults().css_variables

  def renderer(:home), do: Emakola.Themes.Fashion.Home
  def renderer(:product_list), do: Emakola.Themes.Fashion.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Fashion.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Fashion.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Fashion.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns),
    to: Emakola.Themes.Fashion.ProductList,
    as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Fashion.ProductDetail,
    as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  @impl true
  def storefront_nav(assigns) do
    Emakola.Themes.Fashion.Shared.fashion_nav(%{
      __changed__: nil,
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      on_dark: false
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Emakola.Themes.Fashion.Shared.fashion_footer(%{__changed__: nil, store: assigns.store})
  end
end
