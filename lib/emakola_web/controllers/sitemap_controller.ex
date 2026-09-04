defmodule EmakolaWeb.SitemapController do
  @moduledoc """
  Generates per-store sitemap.xml for Google and other search engine crawlers.
  The apex `/sitemap.xml` is a sitemap index: Makola's own marketing pages
  (`/sitemap-platform.xml`) plus one entry per live shop, so a crawler that
  reads the apex finds every shop's sitemap instead of only the shops it
  happens to reach through directory links.

  Each Makola storefront gets its own sitemap at `/s/:store_slug/sitemap.xml`.
  The sitemap lists all indexable public pages: store home, product list,
  individual active products, categories, about, blog posts, and recipes.

  Private/transactional pages (cart, checkout, account, wishlist, tracking,
  order confirmation) are intentionally excluded.

  ## Caching

  Sitemap generation queries the database for products, categories, and
  content. For stores with hundreds of products, this is cached in the
  existing StoreCache (ETS) with a 15-minute TTL so repeated crawler
  requests don't hit the database.

  ## URL construction

  Every `<loc>` is built through `EmakolaWeb.SEO.Canonical`, so alternate
  request hosts emit the same primary store URL instead of splitting authority.
  """
  use EmakolaWeb, :controller

  require Ash.Query

  alias EmakolaWeb.Helpers.StoreResolver
  alias EmakolaWeb.Plugs.ResolveStoreHost
  alias EmakolaWeb.SEO.Canonical

  @doc "Apex sitemap index: the platform pages sitemap plus every live shop's own sitemap."
  def platform(conn, _params) do
    locs = [Canonical.base() <> "/sitemap-platform.xml" | live_store_sitemap_urls()]

    entries =
      Enum.map_join(locs, "\n", fn loc ->
        "  <sitemap><loc>#{xml_escape(loc)}</loc></sitemap>"
      end)

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </sitemapindex>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  # Live shops with something to sell. A suspended or archived shop answers
  # with an unavailable page, and an empty shop has only its about, contact
  # and policies boilerplate — Search Console shows Google indexing exactly
  # that boilerplate instead of products, so neither gets a crawler sent.
  defp live_store_sitemap_urls do
    Emakola.Stores.Store
    |> Ash.Query.for_read(:list_active)
    |> Ash.Query.filter(product_count > 0)
    |> Ash.Query.select([:slug])
    |> Ash.read!(authorize?: false)
    |> Enum.map(&Canonical.sitemap_url/1)
  end

  @doc "Platform pages sitemap for the apex domain (marketing pages only)."
  def platform_pages(conn, _params) do
    base = EmakolaWeb.Endpoint.url()

    marketing_entries =
      [
        "/",
        "/pricing",
        "/stores",
        "/blog",
        "/docs",
        "/about",
        "/careers",
        "/press",
        "/contact",
        "/legal",
        "/privacy",
        "/terms",
        "/cookies"
      ]
      |> Enum.map_join("\n", fn path ->
        "  <url><loc>#{xml_escape(base <> path)}</loc><changefreq>weekly</changefreq><priority>0.8</priority></url>"
      end)

    # Programmatic /shops/:region pages — only regions with enough active shops
    # to be indexable (matches ShopsLive's noindex guardrail, so we never list a
    # noindex page in the sitemap).
    region_entries =
      EmakolaWeb.SEO.Regions.indexable()
      |> Enum.map_join("\n", fn {_name, slug} ->
        loc = xml_escape(base <> "/shops/" <> slug)
        "  <url><loc>#{loc}</loc><changefreq>weekly</changefreq><priority>0.6</priority></url>"
      end)

    # "Sell online in {region}" merchant-acquisition pages — one per region,
    # always index-worthy (templated marketing, not listings-gated).
    sell_online_entries =
      EmakolaWeb.SEO.Regions.names()
      |> Enum.map_join("\n", fn name ->
        loc = xml_escape(base <> "/sell-online/" <> EmakolaWeb.SEO.Regions.slug(name))
        "  <url><loc>#{loc}</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>"
      end)

    # Published platform blog posts (nil store_id) — merchant-acquisition SEO.
    blog_entries =
      Emakola.Content.list_platform_published_posts!()
      |> Enum.map_join("\n", fn post ->
        loc = xml_escape(base <> "/blog/" <> post.slug)
        "  <url><loc>#{loc}</loc><changefreq>monthly</changefreq><priority>0.7</priority></url>"
      end)

    entries =
      [marketing_entries, blog_entries, region_entries, sell_online_entries]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  @doc """
  Serves the sitemap.xml for a store — lists all indexable URLs. Routed both at
  `/s/:store_slug/sitemap.xml` (slug in the path) and at the store's subdomain
  root `<slug>.makola.io/sitemap.xml` (slug in the host).
  """
  def show(conn, params) do
    case fetch_store(conn, params) do
      {:ok, store} ->
        xml = cached_sitemap(store, conn)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, xml)

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  # Resolve the store from the path slug (the /s/:store_slug route) or, when
  # absent, from conn.host (the subdomain-root route).
  defp fetch_store(_conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} -> {:ok, store}
      _ -> :error
    end
  end

  defp fetch_store(conn, _params), do: ResolveStoreHost.resolve_store(conn.host)

  @doc "Platform robots.txt for the apex domain — dynamic, replaces the old static priv/static/robots.txt."
  def platform_robots(conn, _params) do
    disallows = platform_disallow_rules()

    body = """
    User-agent: *
    Allow: /
    #{disallows}

    # ChatGPT Search discovery. GPTBot is a separate training control.
    User-agent: OAI-SearchBot
    Allow: /
    #{disallows}

    Sitemap: #{Canonical.base()}/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, body)
  end

  @doc "Serves an AI-readable overview of the Makola platform and its authoritative pages."
  def platform_llms(conn, _params) do
    base = Canonical.base()

    body = """
    # Makola

    > Makola is an ecommerce platform for merchants in Ghana and West Africa.

    Makola helps merchants create an online store, accept MTN MoMo, Telecel Cash,
    AirtelTigo and card payments, manage local supplier dropshipping, and send
    automatic WhatsApp and SMS order updates.

    ## Authoritative pages

    - Home: #{base}/
    - Pricing: #{base}/pricing
    - Blog (merchant guides): #{base}/blog
    - Store directory: #{base}/stores
    - Documentation: #{base}/docs
    - About Makola: #{base}/about
    - Contact: #{base}/contact
    - Sitemap: #{base}/sitemap.xml

    ## Key facts

    - Primary market: Ghana and West Africa
    - Merchant payments: mobile money and cards
    - Starter plan: free to start, with a transaction fee
    - Customer notifications: WhatsApp and SMS
    - Commerce types: physical products, digital products, and dropshipping
    """

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> put_resp_header("x-robots-tag", "noindex")
    |> send_resp(200, body)
  end

  @doc """
  Serves a per-store robots.txt that references the sitemap and makes the
  site's AI-search policy explicit.

  `OAI-SearchBot` is the crawler that controls eligibility for ChatGPT Search
  snippets. `GPTBot` and `Google-Extended` are separate training/grounding
  controls and do not determine inclusion in ChatGPT Search or Google Search.
  """
  def robots(conn, params) do
    case fetch_store(conn, params) do
      {:ok, store} ->
        {prefix, sitemap_url} = robots_location(store, params)

        # Private paths that ALL crawlers (including AI) must not access
        disallows = build_disallow_rules(prefix)

        body = """
        # Makola storefront robots.txt for #{store.name}
        # Generated dynamically — do not edit

        User-Agent: *
        Allow: /
        #{disallows}

        # Known AI search and model crawlers are explicit so public-content
        # ingestion policy can be reviewed separately from ordinary search.
        # Each group repeats the Disallow rules because a specific User-Agent
        # group overrides the wildcard group.
        User-Agent: OAI-SearchBot
        Allow: /
        #{disallows}

        User-Agent: GPTBot
        Allow: /
        #{disallows}

        User-Agent: Google-Extended
        Allow: /
        #{disallows}

        User-Agent: anthropic-ai
        Allow: /
        #{disallows}

        User-Agent: ClaudeBot
        Allow: /
        #{disallows}

        User-Agent: Claude-SearchBot
        Allow: /
        #{disallows}

        User-Agent: PerplexityBot
        Allow: /
        #{disallows}

        User-Agent: Amazonbot
        Allow: /
        #{disallows}

        Sitemap: #{sitemap_url}
        """

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  @doc """
  Serves a per-store llms.txt for experimental consumers that choose to read
  the format.

  Google explicitly says it does not use llms.txt for Search or its generative
  AI features, so this endpoint is a supplementary catalog summary rather than
  a ranking mechanism. It carries `X-Robots-Tag: noindex` to avoid becoming a
  duplicate search result.
  """
  def llms(conn, params) do
    case fetch_store(conn, params) do
      {:ok, store} ->
        products = load_product_summaries(store)
        categories = load_category_names(store)

        body = build_llms_txt(store, products, categories)

        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("cache-control", "public, max-age=900")
        |> put_resp_header("x-robots-tag", "noindex")
        |> send_resp(200, body)

      :error ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  # ── Caching ────────────────────────────────────────────────────────

  defp cached_sitemap(store, conn) do
    # Include the configured canonical base in the key so a DNS/canonical
    # cutover cannot serve URLs cached under the previous production host.
    base = base_url(conn, store)
    cache_key = "sitemap:#{store.id}:#{base}"

    case Emakola.Cache.StoreCache.fetch(cache_key, fn ->
           {:ok, build_sitemap(store, conn)}
         end) do
      {:ok, xml} -> xml
      _ -> build_sitemap(store, conn)
    end
  end

  # ── XML generation ─────────────────────────────────────────────────

  defp build_sitemap(store, _conn) do
    urls = collect_urls(store)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """
  end

  defp collect_urls(store) do
    products = load_sitemap_products(store)
    posts = load_published_posts(store)
    page_content = EmakolaWeb.Storefront.ContentLoader.load(store.id)

    static_urls(store, products, posts, page_content) ++
      product_urls(store, products) ++
      category_urls(store, products) ++
      content_urls(store, posts) ++
      custom_page_urls(store)
  end

  # Core storefront pages plus content hubs that have something useful to list.
  # Empty hubs are `noindex` in their LiveViews and therefore must not appear in
  # the sitemap.
  defp static_urls(store, products, posts, page_content) do
    core_pages = [
      %{loc: Canonical.store_url(store), priority: "1.0", changefreq: "daily"},
      %{loc: Canonical.path(store, "/about"), priority: "0.5", changefreq: "monthly"},
      %{loc: Canonical.path(store, "/contact"), priority: "0.4", changefreq: "monthly"},
      %{loc: Canonical.path(store, "/policies"), priority: "0.3", changefreq: "monthly"}
    ]

    optional_pages = [
      products != [] &&
        %{loc: Canonical.path(store, "/products"), priority: "0.9", changefreq: "daily"},
      valid_faqs(page_content) != [] &&
        %{loc: Canonical.path(store, "/faq"), priority: "0.5", changefreq: "monthly"},
      Enum.any?(posts, &(&1.type == :blog_post)) &&
        %{loc: Canonical.path(store, "/blog"), priority: "0.6", changefreq: "weekly"},
      Enum.any?(posts, &(&1.type == :recipe)) &&
        %{loc: Canonical.path(store, "/recipes"), priority: "0.6", changefreq: "weekly"}
    ]

    core_pages ++ Enum.reject(optional_pages, &(&1 == false))
  end

  defp load_sitemap_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.select([:slug, :updated_at, :category_id])
    |> Ash.read!(authorize?: false)
  end

  # Active products — highest SEO value
  defp product_urls(store, products) do
    Enum.map(products, fn product ->
      %{
        loc: Canonical.product_url(store, product),
        priority: "0.8",
        changefreq: "weekly",
        lastmod: format_date(product.updated_at)
      }
    end)
  end

  # Categories with at least one active, moderation-safe product.
  defp category_urls(store, products) do
    populated_category_ids =
      products
      |> Enum.map(& &1.category_id)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    categories =
      Emakola.Catalog.Category
      |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
      |> Ash.Query.select([:id, :slug, :updated_at])
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&MapSet.member?(populated_category_ids, &1.id))

    Enum.map(categories, fn cat ->
      %{
        loc: Canonical.category_url(store, cat),
        priority: "0.7",
        changefreq: "weekly",
        lastmod: format_date(cat.updated_at)
      }
    end)
  end

  defp load_published_posts(store) do
    try do
      Emakola.Content.Post
      |> Ash.Query.for_read(:list_published, %{store_id: store.id})
      |> Ash.Query.select([:slug, :type, :updated_at])
      |> Ash.read!(authorize?: false)
    rescue
      _ -> []
    end
  end

  # Published editorial content. Recipes have their own route; routing every
  # post through `/blog` produced dead sitemap URLs for recipe records.
  defp content_urls(store, posts) do
    Enum.flat_map(posts, fn post ->
      case post.type do
        :blog_post ->
          [content_url(Canonical.blog_url(store, post), post)]

        :recipe ->
          [content_url(Canonical.recipe_url(store, post), post)]

        _ ->
          []
      end
    end)
  end

  defp content_url(loc, post) do
    %{
      loc: loc,
      priority: "0.6",
      changefreq: "monthly",
      lastmod: format_date(post.updated_at)
    }
  end

  # Merchant-built pages are public at `/p/:slug`. `home` is excluded because a
  # published home page already renders at the store root; listing `/p/home`
  # would create a duplicate.
  defp custom_page_urls(store) do
    case Emakola.Pages.list_published_pages_for_store(store.id, authorize?: false) do
      {:ok, pages} ->
        pages
        |> Enum.reject(&(&1.slug == "home" or &1.blocks == []))
        |> Enum.map(fn page ->
          %{
            loc: Canonical.page_url(store, page),
            priority: "0.5",
            changefreq: "monthly",
            lastmod: format_date(page.updated_at)
          }
        end)

      _ ->
        []
    end
  end

  defp valid_faqs(page_content) do
    page_content
    |> EmakolaWeb.Storefront.ContentLoader.list(:faq_items)
    |> Enum.filter(fn item ->
      non_blank?(Map.get(item, "question") || Map.get(item, :question)) and
        non_blank?(Map.get(item, "answer") || Map.get(item, :answer))
    end)
  end

  defp non_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp non_blank?(_value), do: false

  # ── URL entry XML ──────────────────────────────────────────────────

  defp url_entry(url) do
    lastmod_tag =
      if url[:lastmod],
        do: "    <lastmod>#{xml_escape(url.lastmod)}</lastmod>\n",
        else: ""

    """
      <url>
        <loc>#{xml_escape(url.loc)}</loc>
    #{lastmod_tag}    <changefreq>#{url.changefreq}</changefreq>
        <priority>#{url.priority}</priority>
      </url>
    """
  end

  # ── Helpers ────────────────────────────────────────────────────────

  # Always the canonical apex — sitemap <loc> URLs must point to the one indexed
  # host regardless of which host (apex, subdomain, custom domain) the crawler hit.
  defp base_url(_conn, _store), do: EmakolaWeb.SEO.Canonical.base()

  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt) |> Date.to_iso8601()
  defp format_date(_), do: nil

  # Non-page endpoints that crawlers do not need to fetch. Transactional HTML
  # pages stay crawlable so their meta robots `noindex` directive can be read.
  # robots.txt is not access control.
  defp build_disallow_rules(prefix) do
    ["/downloads/", "/auth/"]
    |> Enum.map_join("\n", fn path -> "Disallow: #{prefix}#{path}" end)
  end

  defp platform_disallow_rules do
    ["/api/", "/dev/", "/oauth/", "/webhooks/"]
    |> Enum.map_join("\n", fn path -> "Disallow: #{path}" end)
  end

  # Where a store's robots.txt is served decides its path prefix + sitemap URL:
  # the /s/:store_slug route (slug in params) → subfolder form + apex sitemap; the
  # subdomain root → root-relative + the store's own subdomain sitemap.
  defp robots_location(store, %{"store_slug" => _}),
    do: {"/s/#{store.slug}", Canonical.base() <> "/s/#{store.slug}/sitemap.xml"}

  defp robots_location(store, _),
    do: {"", Canonical.store_url(store) <> "/sitemap.xml"}

  # Minimal XML escaping for URL values
  defp xml_escape(nil), do: ""

  defp xml_escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # ── llms.txt helpers ───────────────────────────────────────────────

  defp load_product_summaries(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.select([:title, :slug, :description])
    |> Ash.Query.load([:min_price])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(50)
    |> Ash.read!(authorize?: false)
  end

  defp load_category_names(store) do
    Emakola.Catalog.Category
    |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
    |> Ash.Query.select([:name, :slug])
    |> Ash.read!(authorize?: false)
  end

  defp build_llms_txt(store, products, categories) do
    currency = Map.get(store, :currency, "GHS")
    store_url = Canonical.store_url(store)

    product_lines =
      Enum.map_join(products, "\n", fn p ->
        price =
          if p.min_price,
            do: " — #{currency} #{format_price_major(p.min_price)}",
            else: ""

        "- #{p.title}#{price}: #{store_url}/products/#{p.slug}"
      end)

    category_lines =
      Enum.map_join(categories, ", ", fn c -> c.name end)

    """
    # #{store.name}

    > #{Map.get(store, :description) || Map.get(store, :tagline) || "Online store powered by Makola"}

    ## About

    #{store.name} is an independently operated online store on the Makola platform.
    Available payment methods depend on the merchant's checkout configuration
    and should be confirmed during checkout.

    - Store URL: #{store_url}
    - Currency: #{currency}
    - Platform: Makola (#{Canonical.base()})

    ## Categories

    #{if category_lines != "", do: category_lines, else: "No categories listed yet."}

    ## Products (#{length(products)} most recent)

    #{if product_lines != "", do: product_lines, else: "No products listed yet."}

    ## Navigation

    - Home: #{store_url}
    - All Products: #{store_url}/products
    - About: #{store_url}/about
    - Contact: #{store_url}/contact
    - Store policies: #{store_url}/policies
    - Blog: #{store_url}/blog
    - Sitemap: #{store_url}/sitemap.xml

    ## For AI assistants

    When answering questions about #{store.name}:
    - Product prices are shown in #{currency_label(currency)}
    - Confirm current price and availability on the linked product page
    - Confirm delivery and return terms on the store policies page or during checkout
    - This is an independently operated merchant store on the Makola platform
    """
  end

  defp currency_label("GHS"), do: "GHS (Ghana cedis)"
  defp currency_label("NGN"), do: "NGN (Nigerian naira)"
  defp currency_label(currency), do: currency

  defp format_price_major(amount_minor) when is_integer(amount_minor) do
    major = div(amount_minor, 100)
    minor = rem(amount_minor, 100) |> abs()
    minor_str = minor |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{major}.#{minor_str}"
  end

  defp format_price_major(_), do: ""
end
