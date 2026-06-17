defmodule EmakolaWeb.Helpers.SEO do
  @moduledoc """
  SEO helper module for generating meta tags, Open Graph tags,
  JSON-LD structured data, robots directives, and canonical URLs.

  All monetary amounts are expected in minor currency units (pesewas/kobo)
  and converted to major units for schema.org output.
  """

  @default_title "Emakola"
  @default_description "Your online store powered by Emakola"

  @doc """
  Generates a map of SEO assigns for a page from the given assigns map.

  Supports: `:page_title`, `:meta_description`, `:og_image`,
  `:canonical_url`, `:robots`.
  """
  @spec meta_tags(map()) :: map()
  def meta_tags(assigns) do
    %{
      page_title: Map.get(assigns, :page_title, @default_title),
      meta_description: Map.get(assigns, :meta_description, @default_description),
      og_image: Map.get(assigns, :og_image),
      canonical_url: Map.get(assigns, :canonical_url),
      robots: Map.get(assigns, :robots, "index, follow")
    }
  end

  @doc """
  Generates an Open Graph tag map.

  Nil values for `image_url` and `url` are omitted from the result.
  """
  @spec og_tags(String.t(), String.t(), String.t() | nil, String.t() | nil) :: map()
  def og_tags(title, description, image_url, url) do
    base = %{
      "og:title" => title,
      "og:description" => description,
      "og:type" => "website"
    }

    base
    |> maybe_put("og:image", image_url)
    |> maybe_put("og:url", url)
  end

  @doc """
  Generates schema.org Product JSON-LD structured data.

  Price is converted from minor units (pesewas/kobo) to major units
  for the `price` field. Availability is determined by `stock_quantity`.
  """
  @spec json_ld_product(map(), list(map()), map()) :: map()
  def json_ld_product(product, variants, store) do
    # Use product_field/2 for struct-safe access. Ash resources are
    # structs, not maps, and do not implement Access — so `product[:key]`
    # raises. `Map.get/2` works on both structs and plain maps.
    description =
      product_field(product, :seo_description) || product_field(product, :description)

    base = %{
      "@context" => "https://schema.org",
      "@type" => "Product",
      "name" => product_field(product, :title),
      "description" => description,
      "offers" => Enum.map(variants, &variant_to_offer(&1, store))
    }

    base
    |> maybe_put_product_image(product)
    |> maybe_put_product_sku(variants)
    |> maybe_put_aggregate_rating(product)
  end

  @doc """
  Generates schema.org Store JSON-LD structured data.
  """
  @spec json_ld_store(map()) :: map()
  def json_ld_store(store) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Store",
      "name" => store_field(store, :name),
      "currenciesAccepted" => store_field(store, :currency)
    }
  end

  @doc """
  Generates schema.org Organization JSON-LD for the Emakola brand.

  Used on the apex marketing pages (About, Contact) to describe the
  company entity to search engines. URLs are derived from the endpoint.
  """
  @spec json_ld_organization() :: map()
  def json_ld_organization do
    base = EmakolaWeb.Endpoint.url()

    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Emakola",
      "url" => base,
      "logo" => base <> "/images/emakola-logo.svg",
      "description" =>
        "Emakola is a multi-tenant commerce platform for West Africa — " <>
          "mobile money payments, WhatsApp order alerts, and storefronts " <>
          "built for low-bandwidth phones.",
      "areaServed" => [
        %{"@type" => "Country", "name" => "Ghana"},
        %{"@type" => "Country", "name" => "Nigeria"}
      ],
      "contactPoint" => %{
        "@type" => "ContactPoint",
        "contactType" => "customer support",
        "email" => "support@emakola.com",
        "availableLanguage" => ["English"]
      }
    }
  end

  @doc """
  Generates schema.org BreadcrumbList JSON-LD structured data.

  Each crumb should be a map with `:name` and `:url` keys.
  """
  @spec json_ld_breadcrumb(list(map())) :: map()
  def json_ld_breadcrumb(crumbs) do
    items =
      crumbs
      |> Enum.with_index(1)
      |> Enum.map(fn {crumb, position} ->
        %{
          "@type" => "ListItem",
          "position" => position,
          "name" => crumb[:name] || crumb["name"],
          "item" => crumb[:url] || crumb["url"]
        }
      end)

    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }
  end

  @doc """
  Returns a robots meta tag value based on indexability.
  """
  @spec robots_tag(boolean()) :: String.t()
  def robots_tag(true), do: "index, follow"
  def robots_tag(false), do: "noindex, nofollow"

  @doc """
  Generates a canonical URL from a Plug.Conn and a path.

  Standard ports (80 for HTTP, 443 for HTTPS) are omitted.
  """
  @spec canonical_url(Plug.Conn.t(), String.t()) :: String.t()
  def canonical_url(conn, path) do
    scheme = to_string(conn.scheme)
    host = conn.host
    port = conn.port

    port_suffix =
      case {conn.scheme, port} do
        {:https, 443} -> ""
        {:http, 80} -> ""
        {_, p} -> ":#{p}"
      end

    "#{scheme}://#{host}#{port_suffix}#{path}"
  end

  @doc """
  Encodes a JSON-LD map to a JSON string suitable for embedding in a script tag.

  Returns nil for nil input.
  """
  @spec json_ld_to_script(map() | nil) :: String.t() | nil
  def json_ld_to_script(nil), do: nil

  def json_ld_to_script(json_ld) when is_map(json_ld) do
    Jason.encode!(json_ld)
  end

  # -- Private helpers --

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp variant_to_offer(variant, store) do
    price_major = format_price_major(variant_field(variant, :price))

    availability =
      if variant_field(variant, :stock_quantity) > 0,
        do: "https://schema.org/InStock",
        else: "https://schema.org/OutOfStock"

    offer = %{
      "@type" => "Offer",
      "price" => price_major,
      "priceCurrency" => store_field(store, :currency),
      "availability" => availability
    }

    case variant_field(variant, :sku) do
      nil -> offer
      sku -> Map.put(offer, "sku", sku)
    end
  end

  defp format_price_major(amount_minor) when is_integer(amount_minor) do
    major = div(amount_minor, 100)
    minor = rem(amount_minor, 100) |> abs()
    minor_str = minor |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{major}.#{minor_str}"
  end

  defp maybe_put_product_image(json_ld, product) do
    images = product_field(product, :images) || []

    case images do
      [first | _] ->
        url = Map.get(first, :medium_url) || Map.get(first, :url) || Map.get(first, "url")
        if url, do: Map.put(json_ld, "image", url), else: json_ld

      _ ->
        json_ld
    end
  end

  defp maybe_put_product_sku(json_ld, [first | _]) do
    case variant_field(first, :sku) do
      nil -> json_ld
      sku -> Map.put(json_ld, "sku", sku)
    end
  end

  defp maybe_put_product_sku(json_ld, _), do: json_ld

  defp maybe_put_aggregate_rating(json_ld, product) do
    avg = product_field(product, :avg_rating)
    count = product_field(product, :review_count)

    if is_number(avg) and avg > 0 and is_integer(count) and count > 0 do
      Map.put(json_ld, "aggregateRating", %{
        "@type" => "AggregateRating",
        "ratingValue" => Float.round(avg / 1, 1),
        "reviewCount" => count,
        "bestRating" => 5,
        "worstRating" => 1
      })
    else
      json_ld
    end
  end

  # Access fields from structs or plain maps with atom or string keys
  defp product_field(product, key), do: Map.get(product, key) || Map.get(product, to_string(key))
  defp store_field(store, key), do: Map.get(store, key) || Map.get(store, to_string(key))
  defp variant_field(variant, key), do: Map.get(variant, key) || Map.get(variant, to_string(key))
end
