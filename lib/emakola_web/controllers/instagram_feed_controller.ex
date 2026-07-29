defmodule EmakolaWeb.InstagramFeedController do
  @moduledoc """
  Per-store Google Merchant-compatible product feed.

  Meta's Commerce Manager accepts the Google Merchant Center XML format
  (RSS 2.0 + the `g:` namespace) when connecting a product catalog by
  scheduled feed URL. The generic endpoint can also be submitted to Google
  Merchant Center; the legacy Instagram URL remains available.

  Endpoint:

      GET /s/:store_slug/feed/products.xml
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
  alias EmakolaWeb.SEO.Canonical

  def show(conn, %{"store_slug" => slug}) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        xml = build_feed(store)

        conn
        |> put_resp_content_type("application/xml")
        |> put_resp_header("cache-control", "public, max-age=900")
        |> send_resp(200, xml)

      {:error, _} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Store not found")
    end
  end

  # ── Feed XML generation ──────────────────────────────────────────

  defp build_feed(store) do
    store_url = Canonical.store_url(store)
    products = load_products(store)

    items =
      products
      |> Enum.filter(&(present?(first_image_url(&1)) and not is_nil(first_variant(&1))))
      |> Enum.map_join("\n", &item_xml(&1, store))

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">
      <channel>
        <title>#{xml_escape(store.name)} — Product Feed</title>
        <link>#{store_url}</link>
        <description>Shopping product feed for #{xml_escape(store.name)}</description>
    #{items}
      </channel>
    </rss>
    """
  end

  defp item_xml(product, store) do
    variant = first_variant(product)
    image = first_image_url(product)
    currency = Map.get(store, :currency) || "GHS"
    link = Canonical.product_url(store, product)

    """
        <item>
          <g:id>#{xml_escape(product.id)}</g:id>
          <g:title>#{xml_escape(product.title)}</g:title>
          <g:description>#{xml_escape(product.seo_description || product.description || product.title)}</g:description>
          <g:link>#{xml_escape(link)}</g:link>
          <g:image_link>#{xml_escape(image)}</g:image_link>
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

  defp first_variant(%{variants: variants}) when is_list(variants) and variants != [] do
    Enum.min_by(variants, &Map.get(&1, :position, 0))
  end

  defp first_variant(_), do: nil

  defp first_image_url(%{images: images}) when is_list(images) and images != [] do
    image = Enum.min_by(images, &Map.get(&1, :position, 0))
    image.medium_url || image.url || image.thumbnail_url
  end

  defp first_image_url(_), do: nil

  defp variant_price(%{price: price}) when is_integer(price), do: price
  defp variant_price(_), do: 0

  defp availability(%{available: false}), do: "out of stock"
  defp availability(%{track_inventory: false}), do: "in stock"
  defp availability(%{stock_quantity: qty}) when is_integer(qty) and qty > 0, do: "in stock"
  defp availability(_), do: "out of stock"

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp format_price(minor, currency) do
    major = div(minor, 100)
    cents = rem(abs(minor), 100)
    "#{major}.#{String.pad_leading(Integer.to_string(cents), 2, "0")} #{currency}"
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
