defmodule EmakolaWeb.Helpers.SEOTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Helpers.SEO

  # -- meta_tags/1 --

  describe "meta_tags/1" do
    test "generates meta tag assigns with all fields" do
      assigns = %{
        page_title: "Cool Product",
        meta_description: "A great product",
        og_image: "https://example.com/image.jpg",
        canonical_url: "https://example.com/products/cool",
        robots: "index, follow"
      }

      result = SEO.meta_tags(assigns)

      assert result.page_title == "Cool Product"
      assert result.meta_description == "A great product"
      assert result.og_image == "https://example.com/image.jpg"
      assert result.canonical_url == "https://example.com/products/cool"
      assert result.robots == "index, follow"
    end

    test "uses defaults when fields are missing" do
      result = SEO.meta_tags(%{})

      assert result.page_title == "Emakola"
      assert result.meta_description == "Your online store powered by Emakola"
      assert result.og_image == nil
      assert result.canonical_url == nil
      assert result.robots == "index, follow"
    end

    test "noindex overrides default robots" do
      result = SEO.meta_tags(%{robots: "noindex, nofollow"})
      assert result.robots == "noindex, nofollow"
    end
  end

  # -- og_tags/4 --

  describe "og_tags/4" do
    test "generates Open Graph tag map" do
      tags =
        SEO.og_tags(
          "Product Title",
          "Product description here",
          "https://example.com/img.jpg",
          "https://example.com/products/1"
        )

      assert tags["og:title"] == "Product Title"
      assert tags["og:description"] == "Product description here"
      assert tags["og:image"] == "https://example.com/img.jpg"
      assert tags["og:url"] == "https://example.com/products/1"
      assert tags["og:type"] == "website"
    end

    test "omits image when nil" do
      tags = SEO.og_tags("Title", "Desc", nil, "https://example.com")
      refute Map.has_key?(tags, "og:image")
    end

    test "omits url when nil" do
      tags = SEO.og_tags("Title", "Desc", nil, nil)
      refute Map.has_key?(tags, "og:url")
    end
  end

  # -- json_ld_product/3 --

  describe "json_ld_product/3" do
    setup do
      store = %{
        name: "Accra Styles",
        slug: "accra-styles",
        currency: "GHS"
      }

      product = %{
        title: "Kente Cloth",
        description: "Traditional Ghanaian textile",
        slug: "kente-cloth",
        seo_description: nil,
        images: [
          %{
            url: "https://example.com/kente.jpg",
            medium_url: nil,
            thumbnail_url: nil,
            alt_text: nil
          }
        ]
      }

      variants = [
        %{sku: "KC-001", price: 15000, stock_quantity: 10},
        %{sku: "KC-002", price: 20000, stock_quantity: 0}
      ]

      %{store: store, product: product, variants: variants}
    end

    test "generates valid Product JSON-LD", %{store: store, product: product, variants: variants} do
      json_ld = SEO.json_ld_product(product, variants, store)

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "Product"
      assert json_ld["name"] == "Kente Cloth"
      assert json_ld["description"] == "Traditional Ghanaian textile"
      assert json_ld["image"] == "https://example.com/kente.jpg"
      assert json_ld["sku"] == "KC-001"
    end

    test "includes offers with correct price in major units", %{
      store: store,
      product: product,
      variants: variants
    } do
      json_ld = SEO.json_ld_product(product, variants, store)
      offers = json_ld["offers"]

      assert is_list(offers)
      assert length(offers) == 2

      first_offer = List.first(offers)
      assert first_offer["@type"] == "Offer"
      assert first_offer["price"] == "150.00"
      assert first_offer["priceCurrency"] == "GHS"
      assert first_offer["sku"] == "KC-001"
      assert first_offer["availability"] == "https://schema.org/InStock"
    end

    test "marks out-of-stock variants correctly", %{
      store: store,
      product: product,
      variants: variants
    } do
      json_ld = SEO.json_ld_product(product, variants, store)
      second_offer = Enum.at(json_ld["offers"], 1)
      assert second_offer["availability"] == "https://schema.org/OutOfStock"
    end

    test "uses seo_description if available", %{store: store, variants: variants} do
      product = %{
        title: "Kente Cloth",
        description: "Basic description",
        slug: "kente-cloth",
        seo_description: "SEO optimized description",
        images: []
      }

      json_ld = SEO.json_ld_product(product, variants, store)
      assert json_ld["description"] == "SEO optimized description"
    end

    test "handles empty variants", %{store: store, product: product} do
      json_ld = SEO.json_ld_product(product, [], store)
      assert json_ld["offers"] == []
    end

    test "handles product with no images", %{store: store, variants: variants} do
      product = %{
        title: "No Image Product",
        description: "Test",
        slug: "no-image",
        seo_description: nil,
        images: []
      }

      json_ld = SEO.json_ld_product(product, variants, store)
      refute Map.has_key?(json_ld, "image")
    end
  end

  # -- json_ld_store/1 --

  describe "json_ld_store/1" do
    test "generates LocalBusiness JSON-LD" do
      store = %{
        name: "Accra Styles",
        slug: "accra-styles",
        currency: "GHS"
      }

      json_ld = SEO.json_ld_store(store)

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "Store"
      assert json_ld["name"] == "Accra Styles"
      assert json_ld["currenciesAccepted"] == "GHS"
    end
  end

  # -- json_ld_breadcrumb/1 --

  describe "json_ld_breadcrumb/1" do
    test "generates BreadcrumbList JSON-LD" do
      crumbs = [
        %{name: "Home", url: "/s/accra-styles"},
        %{name: "Products", url: "/s/accra-styles/products"},
        %{name: "Kente Cloth", url: "/s/accra-styles/products/kente-cloth"}
      ]

      json_ld = SEO.json_ld_breadcrumb(crumbs)

      assert json_ld["@context"] == "https://schema.org"
      assert json_ld["@type"] == "BreadcrumbList"

      items = json_ld["itemListElement"]
      assert length(items) == 3

      first = List.first(items)
      assert first["@type"] == "ListItem"
      assert first["position"] == 1
      assert first["name"] == "Home"
      assert first["item"] == "/s/accra-styles"
    end

    test "handles empty breadcrumbs" do
      json_ld = SEO.json_ld_breadcrumb([])
      assert json_ld["itemListElement"] == []
    end
  end

  # -- robots_tag/1 --

  describe "robots_tag/1" do
    test "returns index for indexable pages" do
      assert SEO.robots_tag(true) == "index, follow"
    end

    test "returns noindex for non-indexable pages" do
      assert SEO.robots_tag(false) == "noindex, nofollow"
    end
  end

  # -- canonical_url/2 --

  describe "canonical_url/2" do
    test "generates canonical URL from conn and path" do
      conn = %Plug.Conn{
        scheme: :https,
        host: "example.com",
        port: 443
      }

      assert SEO.canonical_url(conn, "/s/store/products") ==
               "https://example.com/s/store/products"
    end

    test "includes port if non-standard" do
      conn = %Plug.Conn{
        scheme: :http,
        host: "localhost",
        port: 4000
      }

      assert SEO.canonical_url(conn, "/s/store") == "http://localhost:4000/s/store"
    end

    test "omits standard HTTPS port" do
      conn = %Plug.Conn{
        scheme: :https,
        host: "shop.emakola.com",
        port: 443
      }

      assert SEO.canonical_url(conn, "/products") == "https://shop.emakola.com/products"
    end

    test "omits standard HTTP port" do
      conn = %Plug.Conn{
        scheme: :http,
        host: "shop.emakola.com",
        port: 80
      }

      assert SEO.canonical_url(conn, "/products") == "http://shop.emakola.com/products"
    end
  end

  # -- json_ld_to_script/1 --

  describe "json_ld_to_script/1" do
    test "encodes JSON-LD map to JSON string" do
      json_ld = %{"@context" => "https://schema.org", "@type" => "Store", "name" => "Test"}
      result = SEO.json_ld_to_script(json_ld)
      decoded = Jason.decode!(result)

      assert decoded["@context"] == "https://schema.org"
      assert decoded["@type"] == "Store"
      assert decoded["name"] == "Test"
    end

    test "returns nil for nil input" do
      assert SEO.json_ld_to_script(nil) == nil
    end
  end
end
