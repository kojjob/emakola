defmodule EmakolaWeb.SitemapController do
  @moduledoc """
  Generates per-store sitemap.xml for Google and other search engine crawlers.

  Each Emakola storefront gets its own sitemap at `/s/:store_slug/sitemap.xml`.
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

  URLs are built as relative paths (`/s/:slug/...`). The `<loc>` values
  use the full absolute URL constructed from the request's scheme and host,
  which means the sitemap works correctly across subdomains and custom
  domains without configuration.
  """
  use EmakolaWeb, :controller

  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @doc "Serves the sitemap.xml for a store — lists all indexable URLs."
  def show(conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        xml = cached_sitemap(store, conn)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, xml)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  @doc """
  Serves a per-store robots.txt that references the sitemap and explicitly
  allows AI crawlers (GPTBot, Google-Extended, Anthropic, etc.).

  Most sites block AI crawlers by default. Emakola merchants WANT their
  products to appear in AI-powered search (Google SGE, Perplexity,
  ChatGPT Browse) — it's a customer acquisition channel. So we allow
  all AI crawlers with a specific directive, rather than relying on the
  wildcard User-Agent: * (which some AI crawlers ignore).
  """
  def robots(conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        base = base_url(conn, store)

        # Private paths that ALL crawlers (including AI) must not access
        disallows = build_disallow_rules(store.slug)

        body = """
        # Emakola storefront robots.txt for #{store.name}
        # Generated dynamically — do not edit

        User-Agent: *
        Allow: /
        #{disallows}

        # AI search crawlers — explicitly allowed for product discovery.
        # Each group repeats the Disallow rules because per the robots.txt
        # spec, a specific User-Agent group overrides the wildcard entirely.
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

        User-Agent: PerplexityBot
        Allow: /
        #{disallows}

        User-Agent: Amazonbot
        Allow: /
        #{disallows}

        Sitemap: #{base}/s/#{store.slug}/sitemap.xml
        """

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  @doc """
  Serves a per-store llms.txt — an emerging standard for LLM-friendly
  site descriptions.

  See https://llmstxt.org for the specification. The file provides a
  structured plain-text summary of the store: what it sells, where it's
  located, what payment methods it accepts, and how to navigate it. This
  helps AI assistants (ChatGPT, Claude, Perplexity, etc.) give accurate
  answers when users ask about the store or its products.
  """
  def llms(conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        base = base_url(conn, store)
        products = load_product_summaries(store)
        categories = load_category_names(store)

        body = build_llms_txt(store, base, products, categories)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  # ── Caching ────────────────────────────────────────────────────────

  defp cached_sitemap(store, conn) do
    # Include host+scheme in cache key so stores reachable on multiple
    # domains (platform URL vs custom domain) get separate cached sitemaps
    # with correct <loc> URLs for each host.
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

  defp build_sitemap(store, conn) do
    base_url = base_url(conn, store)
    urls = collect_urls(store, base_url)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """
  end

  defp collect_urls(store, base_url) do
    slug = store.slug

    static_urls(slug, base_url) ++
      product_urls(store, base_url) ++
      category_urls(store, base_url) ++
      blog_urls(store, base_url)
  end

  # Static pages every store has
  defp static_urls(slug, base_url) do
    [
      %{loc: "#{base_url}/s/#{slug}", priority: "1.0", changefreq: "daily"},
      %{loc: "#{base_url}/s/#{slug}/products", priority: "0.9", changefreq: "daily"},
      %{loc: "#{base_url}/s/#{slug}/about", priority: "0.5", changefreq: "monthly"}
    ]
  end

  # Active products — highest SEO value
  defp product_urls(store, base_url) do
    products =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
      |> Ash.Query.select([:slug, :updated_at])
      |> Ash.read!(authorize?: false)

    Enum.map(products, fn product ->
      %{
        loc: "#{base_url}/s/#{store.slug}/products/#{product.slug}",
        priority: "0.8",
        changefreq: "weekly",
        lastmod: format_date(product.updated_at)
      }
    end)
  end

  # Categories
  defp category_urls(store, base_url) do
    categories =
      Emakola.Catalog.Category
      |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
      |> Ash.Query.select([:slug, :updated_at])
      |> Ash.read!(authorize?: false)

    Enum.map(categories, fn cat ->
      %{
        loc: "#{base_url}/s/#{store.slug}/category/#{cat.slug}",
        priority: "0.7",
        changefreq: "weekly",
        lastmod: format_date(cat.updated_at)
      }
    end)
  end

  # Blog posts (published only)
  defp blog_urls(store, base_url) do
    try do
      posts =
        Emakola.Content.Post
        |> Ash.Query.for_read(:list_published, %{store_id: store.id})
        |> Ash.Query.select([:slug, :updated_at])
        |> Ash.read!(authorize?: false)

      Enum.map(posts, fn post ->
        %{
          loc: "#{base_url}/s/#{store.slug}/blog/#{post.slug}",
          priority: "0.6",
          changefreq: "monthly",
          lastmod: format_date(post.updated_at)
        }
      end)
    rescue
      # Content domain may not exist yet on all branches
      _ -> []
    end
  end

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

  defp base_url(conn, _store) do
    scheme = to_string(conn.scheme)
    host = conn.host
    port = conn.port

    port_suffix =
      case {conn.scheme, port} do
        {:https, 443} -> ""
        {:http, 80} -> ""
        {_, p} -> ":#{p}"
      end

    "#{scheme}://#{host}#{port_suffix}"
  end

  defp format_date(%DateTime{} = dt), do: DateTime.to_date(dt) |> Date.to_iso8601()
  defp format_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt) |> Date.to_iso8601()
  defp format_date(_), do: nil

  # Private paths that all crawlers should not access
  defp build_disallow_rules(slug) do
    ["/cart", "/checkout", "/account", "/wishlist", "/track/", "/orders/", "/auth/"]
    |> Enum.map_join("\n", fn path -> "Disallow: /s/#{slug}#{path}" end)
  end

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

  defp build_llms_txt(store, base, products, categories) do
    currency = Map.get(store, :currency, "GHS")
    store_url = "#{base}/s/#{store.slug}"

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

    > #{Map.get(store, :description) || Map.get(store, :tagline) || "Online store powered by Emakola"}

    ## About

    #{store.name} is an online store on the Emakola platform, serving customers primarily in Ghana and West Africa. The store accepts mobile money payments (MTN MoMo, Vodafone Cash, AirtelTigo) via Paystack and Hubtel, as well as card payments.

    - Store URL: #{store_url}
    - Currency: #{currency}
    - Platform: Emakola (https://emakola.com)

    ## Categories

    #{if category_lines != "", do: category_lines, else: "No categories listed yet."}

    ## Products (#{length(products)} most recent)

    #{if product_lines != "", do: product_lines, else: "No products listed yet."}

    ## Navigation

    - Home: #{store_url}
    - All Products: #{store_url}/products
    - About: #{store_url}/about
    - Blog: #{store_url}/blog
    - Sitemap: #{store_url}/sitemap.xml

    ## For AI assistants

    When answering questions about #{store.name}:
    - Product prices are in #{currency} (Ghana Cedis)
    - All prices include VAT where applicable
    - Delivery is available across Ghana; delivery zones and fees vary by location
    - Mobile money is the primary payment method for most customers
    - The store is operated by a merchant on the Emakola ecommerce platform
    """
  end

  defp format_price_major(amount_minor) when is_integer(amount_minor) do
    major = div(amount_minor, 100)
    minor = rem(amount_minor, 100) |> abs()
    minor_str = minor |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{major}.#{minor_str}"
  end

  defp format_price_major(_), do: ""
end
