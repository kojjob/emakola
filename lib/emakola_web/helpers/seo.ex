defmodule EmakolaWeb.Helpers.SEO do
  @moduledoc """
  SEO helper module for generating meta tags, Open Graph tags,
  JSON-LD structured data, robots directives, and canonical URLs.

  All monetary amounts are expected in minor currency units (pesewas/kobo)
  and converted to major units for schema.org output.
  """

  @default_title "Makola"
  @default_description "Your online store powered by Makola"

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
  Generates schema.org Organization JSON-LD for the Makola brand.

  Used on the apex marketing pages (About, Contact) to describe the
  company entity to search engines. URLs are derived from the endpoint.
  """
  @spec json_ld_organization() :: map()
  def json_ld_organization do
    base = EmakolaWeb.Endpoint.url()

    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "Makola",
      "url" => base,
      "logo" => base <> "/images/emakola-logo.svg",
      "description" =>
        "Makola is a multi-tenant commerce platform for West Africa — " <>
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
  Generates schema.org BlogPosting JSON-LD for a content post.

  `description` prefers `seo_description`, falling back to `excerpt`. Image and
  `datePublished` are omitted when absent. The URL is pinned to the apex via
  `EmakolaWeb.SEO.Canonical`, never the request host.
  """
  @spec json_ld_article(map(), map()) :: map()
  def json_ld_article(post, store) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => post_field(post, :title),
      "url" => EmakolaWeb.SEO.Canonical.blog_url(store, post),
      "author" => %{"@type" => "Organization", "name" => store_field(store, :name)}
    }
    |> maybe_put("description", article_description(post))
    |> maybe_put("image", post_field(post, :featured_image_url))
    |> maybe_put("datePublished", iso8601(post_field(post, :published_at)))
  end

  @doc """
  Generates schema.org Recipe JSON-LD from a recipe post and its `recipe_meta`.

  Ingredients (`%{item:, quantity:}`) become `"<quantity> <item>"` strings,
  instructions become `HowToStep`s, and prep/cook minutes become ISO-8601
  durations. Timing and yield fields are omitted when absent — a recipe with
  rich structured data is a major SERP win for food/grocery merchants.
  """
  @spec json_ld_recipe(map(), map()) :: map()
  def json_ld_recipe(post, store) do
    meta = post_field(post, :recipe_meta) || %{}
    prep = recipe_field(meta, :prep_time)
    cook = recipe_field(meta, :cook_time)

    %{
      "@context" => "https://schema.org",
      "@type" => "Recipe",
      "name" => post_field(post, :title),
      "url" => EmakolaWeb.SEO.Canonical.recipe_url(store, post),
      "author" => %{"@type" => "Organization", "name" => store_field(store, :name)},
      "recipeIngredient" =>
        Enum.map(recipe_field(meta, :ingredients) || [], &ingredient_to_string/1),
      "recipeInstructions" =>
        Enum.map(recipe_field(meta, :instructions) || [], fn step ->
          %{"@type" => "HowToStep", "text" => step}
        end)
    }
    |> maybe_put("description", article_description(post))
    |> maybe_put("image", post_field(post, :featured_image_url))
    |> maybe_put("datePublished", iso8601(post_field(post, :published_at)))
    |> maybe_put("prepTime", iso8601_minutes(prep))
    |> maybe_put("cookTime", iso8601_minutes(cook))
    |> maybe_put("totalTime", iso8601_minutes(sum_minutes(prep, cook)))
    |> maybe_put("recipeYield", yield_string(recipe_field(meta, :servings)))
  end

  @doc """
  Generates schema.org FAQPage JSON-LD from a list of `%{question:, answer:}`
  maps (atom or string keys). Drives the FAQ rich result + AI-citation answers.
  """
  @spec json_ld_faq(list(map())) :: map()
  def json_ld_faq(faqs) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" =>
        Enum.map(faqs, fn faq ->
          %{
            "@type" => "Question",
            "name" => faq[:question] || faq["question"],
            "acceptedAnswer" => %{
              "@type" => "Answer",
              "text" => faq[:answer] || faq["answer"]
            }
          }
        end)
    }
  end

  @doc """
  Generates schema.org LocalBusiness JSON-LD from a store's existing
  city/region/address/phone/socials.

  This is the single biggest free local-pack + AI-SEO lever — it tells search
  engines this is a real business serving a real place. Address and `sameAs`
  are omitted when no data is present; `addressCountry` is derived from currency.
  """
  @spec json_ld_local_business(map()) :: map()
  def json_ld_local_business(store) do
    %{
      "@context" => "https://schema.org",
      "@type" => "LocalBusiness",
      "name" => store_field(store, :name),
      "url" => EmakolaWeb.SEO.Canonical.store_url(store),
      "currenciesAccepted" => store_field(store, :currency)
    }
    |> maybe_put("description", store_field(store, :description) || store_field(store, :tagline))
    |> maybe_put("image", store_field(store, :logo_url) || store_field(store, :cover_image_url))
    |> maybe_put("telephone", store_field(store, :contact_phone))
    |> maybe_put("email", store_field(store, :contact_email))
    |> maybe_put("address", postal_address(store))
    |> maybe_put("sameAs", social_profiles(store))
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

  defp article_description(post),
    do: post_field(post, :seo_description) || post_field(post, :excerpt)

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  # ISO-8601 duration from a minute count; nil for non-positive/absent values.
  defp iso8601_minutes(n) when is_integer(n) and n > 0, do: "PT#{n}M"
  defp iso8601_minutes(_), do: nil

  defp sum_minutes(a, b), do: minutes(a) + minutes(b)
  defp minutes(n) when is_integer(n), do: n
  defp minutes(_), do: 0

  defp yield_string(n) when is_integer(n) and n > 0, do: Integer.to_string(n)
  defp yield_string(_), do: nil

  defp ingredient_to_string(ing) when is_binary(ing), do: ing

  defp ingredient_to_string(ing) when is_map(ing) do
    item = recipe_field(ing, :item) || recipe_field(ing, :name)
    quantity = recipe_field(ing, :quantity)

    [quantity, item]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp postal_address(store) do
    street = store_field(store, :address)
    city = store_field(store, :city)
    region = store_field(store, :region)

    if street || city || region do
      %{
        "@type" => "PostalAddress",
        "addressCountry" => country_from_currency(store_field(store, :currency))
      }
      |> maybe_put("streetAddress", street)
      |> maybe_put("addressLocality", city)
      |> maybe_put("addressRegion", region)
    end
  end

  defp country_from_currency("NGN"), do: "NG"
  defp country_from_currency(_), do: "GH"

  defp social_profiles(store) do
    [:instagram_url, :facebook_url, :tiktok_url, :youtube_url, :x_url]
    |> Enum.map(&store_field(store, &1))
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> nil
      urls -> urls
    end
  end

  # Access fields from structs or plain maps with atom or string keys
  defp post_field(post, key), do: Map.get(post, key) || Map.get(post, to_string(key))
  defp recipe_field(meta, key), do: Map.get(meta, key) || Map.get(meta, to_string(key))
  defp product_field(product, key), do: Map.get(product, key) || Map.get(product, to_string(key))
  defp store_field(store, key), do: Map.get(store, key) || Map.get(store, to_string(key))
  defp variant_field(variant, key), do: Map.get(variant, key) || Map.get(variant, to_string(key))
end
