defmodule EmakolaWeb.SEO do
  @moduledoc """
  Function components for rendering SEO metadata in the document head.

  The primary entry point is `meta_tags/1`, which emits:

    * Standard `<meta name="description">` and `<link rel="canonical">`
    * Open Graph tags (`og:title`, `og:description`, `og:image`, `og:url`,
      `og:type`, `og:site_name`)
    * Twitter Card tags (`twitter:card`, `twitter:title`,
      `twitter:description`, `twitter:image`)
    * Optional JSON-LD structured data (Product, Store, BreadcrumbList, etc.)

  ## Why this component matters for Emakola

  West African customers share product links **primarily via WhatsApp**.
  When a merchant sends `https://store.emakola.com/products/kente-shirt`
  to a buyer, WhatsApp unfurls the link by fetching the server-rendered
  HTML and reading the `og:image`, `og:title`, and `og:description` tags.
  Without them, the link appears as a plain text URL with no preview —
  significantly reducing click-through rate.

  This component is the single source of truth for those tags. It does
  not hardcode any branding; callers supply the title, description, image
  URL, and canonical URL per page.

  ## Call sites

  The component is mounted once in `layouts/root.html.heex`. LiveView
  mount/handle_params functions set the relevant assigns on the socket,
  and the root layout reads them with `assigns[:key]` fallbacks.

  ## Example — PDP

      # In ProductDetailLive.mount/3:
      socket
      |> assign(:page_title, "\#{product.title} - \#{store.name}")
      |> assign(:meta_description, product.seo_description || product.description)
      |> assign(:og_image, first_product_image_url(product))
      |> assign(:og_type, "product")
      |> assign(:canonical_url, "https://\#{store.slug}.emakola.com/products/\#{product.slug}")
      |> assign(:json_ld, Emakola.SEO.product_json_ld(product, variants, store))
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  @default_description "Your online store powered by Emakola"
  @default_site_name "Emakola"

  @doc """
  Renders the full SEO / Open Graph / Twitter Card / JSON-LD metadata
  block. All fields except `:title` and `:description` are optional and
  degrade gracefully when omitted.
  """
  attr :title, :string, required: true, doc: "Full page title (including store name)"

  attr :description, :string,
    default: @default_description,
    doc: "Meta description, <=160 chars ideally"

  attr :canonical_url, :string,
    default: nil,
    doc: "Absolute URL of the current page. Omitted when nil."

  attr :og_image, :string,
    default: nil,
    doc:
      "Absolute URL of the primary image. Omitted when nil — WhatsApp will fall back to a generic icon."

  attr :og_type, :string,
    default: "website",
    values: ~w(website article product profile),
    doc: "OG type. Use \"product\" for PDPs, \"website\" for everything else by default."

  attr :twitter_card, :string,
    default: "summary_large_image",
    values: ~w(summary summary_large_image app player),
    doc: "Twitter Card type. summary_large_image is the right default for most pages."

  attr :site_name, :string,
    default: @default_site_name,
    doc: "Site name shown in link previews (e.g., \"Emakola\")."

  attr :robots, :string,
    default: "index, follow",
    doc: "Search engine directive. Use \"noindex, nofollow\" for private pages."

  attr :json_ld, :any,
    default: nil,
    doc:
      "Optional JSON-LD structured data map (e.g., from EmakolaWeb.Helpers.SEO.json_ld_product/3). Emitted inside a <script type=\"application/ld+json\"> tag when present."

  def meta_tags(assigns) do
    ~H"""
    <meta name="description" content={@description} />
    <meta name="robots" content={@robots} />
    <link :if={@canonical_url} rel="canonical" href={@canonical_url} />

    <meta property="og:type" content={@og_type} />
    <meta property="og:title" content={@title} />
    <meta property="og:description" content={@description} />
    <meta :if={@og_image} property="og:image" content={@og_image} />
    <meta :if={@canonical_url} property="og:url" content={@canonical_url} />
    <meta property="og:site_name" content={@site_name} />

    <meta name="twitter:card" content={@twitter_card} />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:description" content={@description} />
    <meta :if={@og_image} name="twitter:image" content={@og_image} />

    <%!--
      HEEx treats <script> tag content as raw text — curly-brace
      interpolation ({...}) is NOT processed inside <script>. We use
      <%= ... %> embedded Elixir instead, then pass the encoded JSON
      through Phoenix.HTML.raw/1 so it doesn't get HTML-escaped twice.

      CRITICAL: we encode with `escape: :html_safe` which converts `<`,
      `>`, `&`, `/`, U+2028, U+2029 to their `\u...` forms. Without this,
      merchant-controlled strings (product description, store tagline,
      SKU) containing the literal `</script>` would break out of the
      script tag on the HTML tokenization pass and inject arbitrary HTML
      into the storefront. The JSON parser still decodes the escapes
      back to the original characters in memory, so Google sees the
      intended structured data — but the HTML tokenizer never sees the
      closing tag. See Jason.Encode docs for escape modes.
    --%>
    <script :if={@json_ld} type="application/ld+json">
      <%= raw(Jason.encode!(@json_ld, escape: :html_safe)) %>
    </script>
    """
  end
end
