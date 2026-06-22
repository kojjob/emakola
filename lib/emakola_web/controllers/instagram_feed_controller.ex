defmodule EmakolaWeb.InstagramFeedController do
  @moduledoc """
  Per-store product feed for Instagram Shopping connection.

  Meta's Commerce Manager accepts the Google Merchant Center XML format
  (RSS 2.0 + the `g:` namespace) when connecting a product catalog by
  scheduled feed URL. Merchants paste this URL into Commerce Manager and
  Meta polls it on its own schedule (default daily) to mirror products.

  Endpoint:

      GET /s/:store_slug/feed/instagram.xml

  Required `g:` fields per Meta:

    * `g:id` — stable retailer id (we use product UUID)
    * `g:title`, `g:description`, `g:link`
    * `g:image_link`
    * `g:price` — major-units string with currency code
    * `g:availability` — "in stock" / "out of stock"
    * `g:brand`, `g:condition`

  ## Why this lives outside the LiveView pipeline

  This is a polled XML endpoint, not a user-facing page. Lives in the
  `:seo` pipeline alongside sitemap.xml so it can be aggressively cached
  and isn't gated by browser-only plugs (auth, CSRF, etc.).
  """
  use EmakolaWeb, :controller

  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  def show(conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        xml = build_feed(store, conn)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, xml)

      {:error, _} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  # ── Feed XML generation ──────────────────────────────────────────

  defp build_feed(store, conn) do
    base = base_url(conn)
    products = load_products(store)
    items = Enum.map_join(products, "\n", &item_xml(&1, store, base))

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">
      <channel>
        <title>#{xml_escape(store.name)} — Product Feed</title>
        <link>#{base}/s/#{store.slug}</link>
        <description>Instagram Shopping product feed for #{xml_escape(store.name)}</description>
    #{items}
      </channel>
    </rss>
    """
  end

  defp item_xml(product, store, base) do
    variant = first_variant(product)
    image = first_image_url(product)
    currency = Map.get(store, :currency) || "GHS"
    link = "#{base}/s/#{store.slug}/products/#{product.slug}"

    """
        <item>
          <g:id>#{xml_escape(product.id)}</g:id>
          <g:title>#{xml_escape(product.title)}</g:title>
          <g:description>#{xml_escape(product.description || product.title)}</g:description>
          <g:link>#{xml_escape(link)}</g:link>
          <g:image_link>#{xml_escape(image || "")}</g:image_link>
          <g:availability>#{availability(variant)}</g:availability>
          <g:price>#{format_price(variant_price(variant), currency)}</g:price>
          <g:brand>#{xml_escape(store.name)}</g:brand>
          <g:condition>new</g:condition>
        </item>
    """
  end

  # ── Data loading ─────────────────────────────────────────────────

  defp load_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.load([:variants, :images])
    |> Ash.Query.sort(updated_at: :desc)
    |> Ash.Query.limit(1000)
    |> Ash.read!(authorize?: false)
  end

  defp first_variant(%{variants: [v | _]}), do: v
  defp first_variant(_), do: nil

  defp first_image_url(%{images: [%{url: url} | _]}) when is_binary(url), do: url
  defp first_image_url(%{images: [%{thumbnail_url: url} | _]}) when is_binary(url), do: url
  defp first_image_url(_), do: nil

  defp variant_price(%{price: price}) when is_integer(price), do: price
  defp variant_price(_), do: 0

  defp availability(%{stock_quantity: qty}) when is_integer(qty) and qty > 0, do: "in stock"
  defp availability(_), do: "out of stock"

  defp format_price(minor, currency) do
    major = div(minor, 100)
    cents = rem(abs(minor), 100)
    "#{major}.#{String.pad_leading(Integer.to_string(cents), 2, "0")} #{currency}"
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp base_url(conn) do
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

  defp xml_escape(nil), do: ""

  defp xml_escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp xml_escape(other), do: xml_escape(to_string(other))
end
