defmodule Emakola.Themes.Adwuma do
  @moduledoc """
  Adwuma theme — for shops that sell their work, not their stock.

  "Adwuma" is Twi for *work*, in the sense of a person's own output: the beat,
  the ebook, the preset pack, the course. The brief is a shop that feels like a
  studio rather than a warehouse — near-white ground, a soft pastel mesh behind
  the hero, hairline and dashed blueprint rules framing each band, and product
  imagery doing the selling.

  Two constraints shaped it more than the reference did:

  **Zero-input completeness.** An Adwuma shop must look finished when the
  merchant has typed nothing and uploaded nothing. The hero takes no image at
  all — the mesh is pure CSS — and every band self-fills from data entered
  elsewhere (categories, covers, enabled product types, real reviews). Bands
  that need prose hide themselves rather than render an empty slab.

  **Merchants who read little.** Card copy is capped at a short title plus one
  line, numerals and outline icons carry the labelling, and the fulfilment
  statement on a download is four words. Nothing here is a merchant promise, so
  nothing here can become a merchant's lie.

  Render modules:
  - `Emakola.Themes.Adwuma.Home` — chrome + sections
  - `Emakola.Themes.Adwuma.ProductList` — shop / listing
  - `Emakola.Themes.Adwuma.ProductDetail` — product detail
  - `Emakola.Themes.Adwuma.Shared` — nav, footer, cards, styles
  """

  @behaviour Emakola.Themes.ThemeBehaviour

  alias Emakola.Themes.Adwuma.Shared

  @impl true
  def name, do: "Adwuma"

  def id, do: "adwuma"

  @doc "Home sections, in default visual order."
  def sections,
    do: [
      Emakola.Themes.Adwuma.Sections.Hero,
      Emakola.Themes.Adwuma.Sections.Formats,
      Emakola.Themes.Adwuma.Sections.Why,
      Emakola.Themes.Adwuma.Sections.Categories,
      Emakola.Themes.Adwuma.Sections.Collection,
      Emakola.Themes.Adwuma.Sections.Offer,
      Emakola.Themes.Adwuma.Sections.Showcase,
      Emakola.Themes.Adwuma.Sections.Testimonials,
      Emakola.Themes.Adwuma.Sections.Newsletter
    ]

  # One request, both families. `display=swap` is asserted for every offered
  # theme by onboarding_theme_picker_test.
  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Sora:wght@300;400;500;600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600&display=swap"
    ]

  @doc """
  Default theme configuration.

  `trust` and `newsletter` are dot-accessed by `ThemeResolver.resolve/2` — a
  missing key raises a `KeyError` on every storefront request, not just one
  section. `colors.primary`, `colors.accent` and `fonts.heading` are
  dot-accessed by both theme pickers.
  """
  def defaults do
    %{
      id: :adwuma,
      name: "Adwuma",
      colors: %{
        primary: "#6E56CF",
        accent: "#F2B8A2",
        background: "#FBFBFA",
        text: "#14131A",
        text_secondary: "#6F6C7A",
        border: "#E7E5EC"
      },
      fonts: %{
        heading: "Sora",
        body: "Plus Jakarta Sans"
      },
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "",
        subtitle: "",
        cta_text: "Browse the shop",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search this shop...", transparent: false},
      sections: %{
        hero: true,
        formats: true,
        why: true,
        categories: true,
        collection: true,
        offer: true,
        showcase: true,
        testimonials: true,
        newsletter: true
      },
      # Empty on purpose. Populated, every Adwuma shop would assert the same
      # file formats. Never delete the key: ThemeResolver.deep_merge_atomize/2
      # drops any override whose key is absent from defaults, so removing it
      # would silently discard the content of every merchant who filled it in.
      formats: %{items: []},
      trust: %{
        title: "Why buy here",
        subtitle: "Mobile money and card payments, processed securely."
      },
      newsletter: %{
        title: "New drops, in your inbox",
        subtitle: "Hear first when something new lands.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#6E56CF",
        "--theme-accent" => "#F2B8A2",
        "--theme-bg" => "#FBFBFA",
        "--theme-font-heading" => "'Sora', system-ui, sans-serif",
        "--theme-font-body" => "'Plus Jakarta Sans', system-ui, sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#6E56CF",
      "--theme-accent" => "#F2B8A2",
      "--theme-bg" => "#FBFBFA"
    }
  end

  @doc "The module that renders the given page type."
  def renderer(:home), do: Emakola.Themes.Adwuma.Home
  def renderer(:product_list), do: Emakola.Themes.Adwuma.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Adwuma.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Adwuma.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Adwuma.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Adwuma.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Adwuma.ProductDetail,
    as: :render

  @impl true
  defdelegate render_about(assigns), to: Emakola.Themes.Atelier.About, as: :render

  # Without these two, cart / account / tracking / category / wishlist silently
  # wear Atelier's chrome mid-funnel (DefaultRenderers.Chrome dispatches on
  # function_exported?/3).
  @impl true
  def storefront_nav(assigns) do
    Shared.adwuma_nav(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || [],
      cart_count: Map.get(assigns, :cart_count) || 0
    })
  end

  @impl true
  def storefront_footer(assigns) do
    Shared.footer(%{
      __changed__: nil,
      store: assigns.store,
      categories: Map.get(assigns, :categories) || []
    })
  end
end
