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

      assert result.page_title == "Makola"
      assert result.meta_description == "Your online store powered by Makola"
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

  # -- json_ld_article/2 --

  describe "json_ld_article/2" do
    setup do
      store = %{slug: "ama-kitchen", name: "Ama's Kitchen"}

      post = %{
        type: :blog_post,
        title: "5 Jollof Tips",
        slug: "5-jollof-tips",
        excerpt: "Make better jollof.",
        seo_description: "The secret to smoky party jollof, step by step.",
        featured_image_url: "https://cdn.example.com/jollof.jpg",
        published_at: ~U[2026-06-01 09:00:00.000000Z]
      }

      %{store: store, post: post}
    end

    test "builds BlogPosting structured data", %{store: store, post: post} do
      result = SEO.json_ld_article(post, store)

      assert result["@context"] == "https://schema.org"
      assert result["@type"] == "BlogPosting"
      assert result["headline"] == "5 Jollof Tips"
      assert result["url"] == "http://localhost:4000/s/ama-kitchen/blog/5-jollof-tips"
      assert result["image"] == "https://cdn.example.com/jollof.jpg"
      assert result["datePublished"] == "2026-06-01T09:00:00.000000Z"
    end

    test "prefers seo_description over excerpt", %{store: store, post: post} do
      assert SEO.json_ld_article(post, store)["description"] ==
               "The secret to smoky party jollof, step by step."
    end

    test "falls back to excerpt when seo_description is nil", %{store: store, post: post} do
      result = SEO.json_ld_article(%{post | seo_description: nil}, store)
      assert result["description"] == "Make better jollof."
    end

    test "names the store as author", %{store: store, post: post} do
      assert SEO.json_ld_article(post, store)["author"] ==
               %{"@type" => "Organization", "name" => "Ama's Kitchen"}
    end

    test "omits image and datePublished when absent", %{store: store, post: post} do
      bare = %{post | featured_image_url: nil, published_at: nil}
      result = SEO.json_ld_article(bare, store)
      refute Map.has_key?(result, "image")
      refute Map.has_key?(result, "datePublished")
    end
  end

  # -- json_ld_recipe/2 --

  describe "json_ld_recipe/2" do
    setup do
      store = %{slug: "ama-kitchen", name: "Ama's Kitchen"}

      post = %{
        type: :recipe,
        title: "Ghana Jollof Rice",
        slug: "ghana-jollof-rice",
        seo_description: "Authentic smoky Ghana jollof.",
        excerpt: "Party jollof.",
        featured_image_url: "https://cdn.example.com/jollof.jpg",
        published_at: ~U[2026-06-01 09:00:00.000000Z],
        recipe_meta: %{
          prep_time: 20,
          cook_time: 40,
          servings: 6,
          ingredients: [
            %{item: "Rice", quantity: "2 cups"},
            %{item: "Tomatoes", quantity: "4 large"}
          ],
          instructions: ["Blend the tomatoes.", "Fry the paste.", "Add rice and stock."]
        }
      }

      %{store: store, post: post}
    end

    test "builds Recipe structured data", %{store: store, post: post} do
      result = SEO.json_ld_recipe(post, store)

      assert result["@context"] == "https://schema.org"
      assert result["@type"] == "Recipe"
      assert result["name"] == "Ghana Jollof Rice"
      assert result["url"] == "http://localhost:4000/s/ama-kitchen/recipes/ghana-jollof-rice"
      assert result["image"] == "https://cdn.example.com/jollof.jpg"
      assert result["description"] == "Authentic smoky Ghana jollof."
    end

    test "maps quantity and item into recipeIngredient strings", %{store: store, post: post} do
      assert SEO.json_ld_recipe(post, store)["recipeIngredient"] ==
               ["2 cups Rice", "4 large Tomatoes"]
    end

    test "maps instructions into HowToStep list", %{store: store, post: post} do
      assert SEO.json_ld_recipe(post, store)["recipeInstructions"] == [
               %{"@type" => "HowToStep", "text" => "Blend the tomatoes."},
               %{"@type" => "HowToStep", "text" => "Fry the paste."},
               %{"@type" => "HowToStep", "text" => "Add rice and stock."}
             ]
    end

    test "encodes durations as ISO-8601 and yield as a string", %{store: store, post: post} do
      result = SEO.json_ld_recipe(post, store)
      assert result["prepTime"] == "PT20M"
      assert result["cookTime"] == "PT40M"
      assert result["totalTime"] == "PT60M"
      assert result["recipeYield"] == "6"
    end

    test "omits timing fields when recipe_meta lacks them", %{store: store, post: post} do
      sparse = %{post | recipe_meta: %{ingredients: [], instructions: []}}
      result = SEO.json_ld_recipe(sparse, store)
      refute Map.has_key?(result, "prepTime")
      refute Map.has_key?(result, "totalTime")
      refute Map.has_key?(result, "recipeYield")
    end
  end

  # -- json_ld_faq/1 --

  describe "json_ld_faq/1" do
    test "builds FAQPage with question/answer entities" do
      faqs = [
        %{question: "Do you deliver?", answer: "Yes, across Accra."},
        %{question: "What payments?", answer: "MTN MoMo and cards."}
      ]

      result = SEO.json_ld_faq(faqs)

      assert result["@context"] == "https://schema.org"
      assert result["@type"] == "FAQPage"

      assert result["mainEntity"] == [
               %{
                 "@type" => "Question",
                 "name" => "Do you deliver?",
                 "acceptedAnswer" => %{"@type" => "Answer", "text" => "Yes, across Accra."}
               },
               %{
                 "@type" => "Question",
                 "name" => "What payments?",
                 "acceptedAnswer" => %{"@type" => "Answer", "text" => "MTN MoMo and cards."}
               }
             ]
    end

    test "accepts string keys too" do
      faqs = [%{"question" => "Q?", "answer" => "A."}]
      [entity] = SEO.json_ld_faq(faqs)["mainEntity"]
      assert entity["name"] == "Q?"
      assert entity["acceptedAnswer"]["text"] == "A."
    end
  end

  # -- json_ld_local_business/1 --

  describe "json_ld_local_business/1" do
    setup do
      store = %{
        slug: "ama-kitchen",
        name: "Ama's Kitchen",
        currency: "GHS",
        description: "Home-cooked Ghanaian meals.",
        logo_url: "https://cdn.example.com/logo.png",
        contact_phone: "+233200000000",
        contact_email: "hello@ama.example",
        address: "12 Oxford St",
        city: "Accra",
        region: "Greater Accra",
        instagram_url: "https://instagram.com/amakitchen",
        facebook_url: "https://facebook.com/amakitchen"
      }

      %{store: store}
    end

    test "builds LocalBusiness with core identity", %{store: store} do
      result = SEO.json_ld_local_business(store)

      assert result["@context"] == "https://schema.org"
      assert result["@type"] == "LocalBusiness"
      assert result["name"] == "Ama's Kitchen"
      assert result["url"] == "http://localhost:4000/s/ama-kitchen"
      assert result["image"] == "https://cdn.example.com/logo.png"
      assert result["telephone"] == "+233200000000"
      assert result["email"] == "hello@ama.example"
    end

    test "builds a PostalAddress with country derived from currency", %{store: store} do
      assert SEO.json_ld_local_business(store)["address"] == %{
               "@type" => "PostalAddress",
               "streetAddress" => "12 Oxford St",
               "addressLocality" => "Accra",
               "addressRegion" => "Greater Accra",
               "addressCountry" => "GH"
             }
    end

    test "derives Nigeria country code from NGN currency", %{store: store} do
      result = SEO.json_ld_local_business(%{store | currency: "NGN"})
      assert result["address"]["addressCountry"] == "NG"
    end

    test "collects social profiles into sameAs", %{store: store} do
      assert SEO.json_ld_local_business(store)["sameAs"] == [
               "https://instagram.com/amakitchen",
               "https://facebook.com/amakitchen"
             ]
    end

    test "omits address, sameAs, and telephone when no data present", %{store: _store} do
      bare = %{slug: "x", name: "X", currency: "GHS"}
      result = SEO.json_ld_local_business(bare)
      refute Map.has_key?(result, "address")
      refute Map.has_key?(result, "sameAs")
      refute Map.has_key?(result, "telephone")
    end
  end
end
