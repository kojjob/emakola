defmodule Emakola.Themes.Heirloom do
  @moduledoc """
  Heirloom theme — furniture, decor and lighting. Warm neutrals, one
  geometric face, generous radii.

  Converted from a Dribbble reference (Shakuro's "Nestery" furniture store)
  with the storefront's real data substituted throughout. Where the reference
  asserted things a merchant has not — named staff, client logos, a
  three-generations provenance story, a fixed delivery lead time — those
  layouts survive but their content is merchant-supplied and the section
  removes itself when empty.

  Design tokens (sampled from the reference, not eyeballed):
  - Ink:        `#1B1208` — headings, body, dark pills
  - Accent:     `#E8983F` — badges, active markers
  - Background: `#EFEFEF` — page ground
  - Tile:       `#E7E6E6` — product tile backgrounds
  - Muted:      `#8C8781` — inactive tabs, secondary text
  - Type:       Outfit throughout; weights 100-200 carry the footer wordmark

  Render modules:
  - `Emakola.Themes.Heirloom.Home` — landing page (chrome + sections)
  - `Emakola.Themes.Heirloom.ProductList` — shop / listing
  - `Emakola.Themes.Heirloom.ProductDetail` — product detail
  - `Emakola.Themes.Heirloom.Shared` — chrome (nav, footer, price helpers)
  """

  use Phoenix.Component

  @behaviour Emakola.Themes.ThemeBehaviour

  alias Emakola.Themes.Heirloom.Shared

  @impl true
  def name, do: "Heirloom"

  def id, do: "heirloom"

  def fonts,
    do: [
      "https://fonts.googleapis.com/css2?family=Outfit:wght@100;200;300;400;500;600;700;800&display=swap"
    ]

  @doc """
  Home sections, in default visual order.

  The reference's ninth band — the full-bleed wordmark over the newsletter —
  is not a section. It lives in `Shared.footer/1` chrome alongside the nav,
  so neither survives on the merchant's ability to keep a section enabled.
  """
  def sections,
    do: [
      Emakola.Themes.Heirloom.Sections.Hero,
      Emakola.Themes.Heirloom.Sections.BrandStory,
      Emakola.Themes.Heirloom.Sections.CategoryGallery,
      Emakola.Themes.Heirloom.Sections.OurStory,
      Emakola.Themes.Heirloom.Sections.Team,
      Emakola.Themes.Heirloom.Sections.ProductShowcase,
      Emakola.Themes.Heirloom.Sections.Clients,
      Emakola.Themes.Heirloom.Sections.Faq
    ]

  @doc """
  Default theme configuration.

  Note the keys that default to empty (`our_story.tabs`, `team.items`,
  `stockists.items`). They must not be deleted:
  `ThemeResolver.deep_merge_atomize/2` drops any override whose key is absent
  from the defaults, so removing one would silently discard the content of
  every merchant who had filled it in.

  They are empty rather than populated for a second reason. Populated, they
  would make every Heirloom store assert the same staff, the same stockists
  and the same heritage — claims no merchant made. Empty, each section
  renders nothing at all until its merchant supplies the truth.
  """
  def defaults do
    %{
      id: :heirloom,
      name: "Heirloom",
      colors: %{
        primary: "#1B1208",
        accent: "#E8983F",
        secondary: "#8C8781",
        background: "#EFEFEF",
        text: "#1B1208",
        text_secondary: "#8C8781",
        border: "#DEDCD8",
        surface: "#FFFFFF",
        on_dark: "#FFFFFF"
      },
      fonts: %{heading: "Outfit", body: "Outfit"},
      hero: %{
        image_url: "",
        images: [],
        carousel: false,
        title: "Furniture with a soul",
        subtitle: "Pieces chosen to last, for the way you actually live.",
        cta_text: "Shop the collection",
        cta_url: "/products"
      },
      nav: %{search_placeholder: "Search the collection...", transparent: true},
      sections: %{
        hero: true,
        brand_story: true,
        category_gallery: true,
        our_story: true,
        team: true,
        product_showcase: true,
        clients: true,
        faq: true
      },
      brand_story: %{body: ""},
      our_story: %{tabs: []},
      team: %{items: []},
      stockists: %{items: []},
      # `trust` and `newsletter` are not optional. ThemeResolver.resolve/1
      # reads `defaults.trust` and `defaults.newsletter` directly, so a theme
      # without them raises KeyError on every storefront request.
      #
      # `trust.items` is empty for the same reason as team and stockists:
      # populated, it would make every Heirloom store promise the same
      # delivery terms and returns policy. The sections build what they can
      # from the store's own delivery zones and show nothing otherwise.
      trust: %{
        title: "Made to live with",
        subtitle: "Considered materials, built for everyday use.",
        items: []
      },
      newsletter: %{
        title: "New pieces, in your inbox",
        subtitle: "Restocks and seasonal releases, once a month.",
        button_text: "Subscribe"
      },
      footer: %{social_links: %{instagram: "", twitter: "", facebook: ""}},
      css_variables: %{
        "--theme-primary" => "#1B1208",
        "--theme-accent" => "#E8983F",
        "--theme-bg" => "#EFEFEF",
        "--theme-font-heading" => "'Outfit', sans-serif",
        "--theme-font-body" => "'Outfit', sans-serif"
      }
    }
  end

  @impl true
  def css_variables do
    %{
      "--theme-primary" => "#1B1208",
      "--theme-accent" => "#E8983F",
      "--theme-bg" => "#EFEFEF"
    }
  end

  def renderer(:home), do: Emakola.Themes.Heirloom.Home
  def renderer(:product_list), do: Emakola.Themes.Heirloom.ProductList
  def renderer(:product_detail), do: Emakola.Themes.Heirloom.ProductDetail
  def renderer(:shared), do: Emakola.Themes.Heirloom.Shared

  @impl true
  defdelegate render_home(assigns), to: Emakola.Themes.Heirloom.Home, as: :render

  @impl true
  defdelegate render_product_list(assigns), to: Emakola.Themes.Heirloom.ProductList, as: :render

  @impl true
  defdelegate render_product_detail(assigns),
    to: Emakola.Themes.Heirloom.ProductDetail,
    as: :render

  @impl true
  def storefront_nav(assigns) do
    # Shared pages (cart, checkout, …) render this chrome via Chrome without
    # the theme's page wrapper, so the theme_styles block must ride with the
    # nav — otherwise var(--hl-*)-styled chrome silently loses its color
    # (the cart footer rendered white-on-white this way).
    assigns = %{
      __changed__: nil,
      theme: Map.get(assigns, :theme) || %{},
      store: assigns.store,
      cart_count: Map.get(assigns, :cart_count) || 0,
      active_path: Map.get(assigns, :active_path) || ""
    }

    ~H"""
    <Shared.theme_styles theme={@theme} />
    <Shared.heirloom_nav
      store={@store}
      cart_count={@cart_count}
      on_dark={false}
      active_path={@active_path}
    />
    """
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
