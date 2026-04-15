defmodule EmakolaWeb.SEOTest do
  @moduledoc """
  Tests for the SEO meta_tags/1 function component.

  The component is the single source of truth for:
    - Standard <meta name="description"> and <link rel="canonical">
    - Open Graph tags (Facebook / WhatsApp unfurling)
    - Twitter Card tags
    - JSON-LD structured data (Google rich results)

  Critical for WhatsApp share previews — the Emakola primary marketing
  channel for West African merchants. A missing og:image means shared
  product links appear as plain text URLs with no preview.
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  alias EmakolaWeb.SEO

  describe "meta_tags/1 — minimum required" do
    test "renders title and description only" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="Kente Shirt - Amara Studio" description="Handwoven in Kumasi." />
        """)

      assert html =~ ~s(<meta name="description" content="Handwoven in Kumasi.")
      assert html =~ ~s(<meta property="og:title" content="Kente Shirt - Amara Studio")
      assert html =~ ~s(<meta property="og:description" content="Handwoven in Kumasi.")
      assert html =~ ~s(<meta name="twitter:title" content="Kente Shirt - Amara Studio")
    end

    test "defaults og:type to website and site_name to Emakola" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="Home" description="Welcome." />
        """)

      assert html =~ ~s(<meta property="og:type" content="website")
      assert html =~ ~s(<meta property="og:site_name" content="Emakola")
    end

    test "defaults twitter:card to summary_large_image" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" />
        """)

      assert html =~ ~s(<meta name="twitter:card" content="summary_large_image")
    end

    test "defaults robots to index, follow" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" />
        """)

      assert html =~ ~s(<meta name="robots" content="index, follow")
    end
  end

  describe "meta_tags/1 — optional fields" do
    test "renders canonical_url as link tag AND og:url" do
      assigns = %{url: "https://amara.emakola.com/products/kente"}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" canonical_url={@url} />
        """)

      assert html =~ ~s(<link rel="canonical" href="https://amara.emakola.com/products/kente")

      assert html =~
               ~s(<meta property="og:url" content="https://amara.emakola.com/products/kente")
    end

    test "omits canonical link and og:url when canonical_url is nil" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" />
        """)

      refute html =~ ~s(<link rel="canonical")
      refute html =~ ~s(<meta property="og:url")
    end

    test "renders og:image and twitter:image when provided" do
      assigns = %{img: "https://cdn.emakola.com/products/kente-640.jpg"}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" og_image={@img} />
        """)

      assert html =~
               ~s(<meta property="og:image" content="https://cdn.emakola.com/products/kente-640.jpg")

      assert html =~
               ~s(<meta name="twitter:image" content="https://cdn.emakola.com/products/kente-640.jpg")
    end

    test "omits og:image and twitter:image when nil" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" />
        """)

      refute html =~ ~s(<meta property="og:image")
      refute html =~ ~s(<meta name="twitter:image")
    end

    test "og_type can be set to product" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" og_type="product" />
        """)

      assert html =~ ~s(<meta property="og:type" content="product")
    end

    test "site_name can be overridden" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" site_name="Amara Studio" />
        """)

      assert html =~ ~s(<meta property="og:site_name" content="Amara Studio")
    end

    test "robots can be set to noindex for private pages" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="Private" description="X" robots="noindex, nofollow" />
        """)

      assert html =~ ~s(<meta name="robots" content="noindex, nofollow")
    end
  end

  describe "meta_tags/1 — JSON-LD structured data" do
    test "renders json_ld inside script tag when provided" do
      json_ld = %{
        "@context" => "https://schema.org",
        "@type" => "Product",
        "name" => "Kente Shirt",
        "offers" => %{
          "@type" => "Offer",
          "price" => "250.00",
          "priceCurrency" => "GHS"
        }
      }

      assigns = %{json_ld: json_ld}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" json_ld={@json_ld} />
        """)

      assert html =~ ~s(<script type="application/ld+json">)
      assert html =~ ~s("@type":"Product")
      assert html =~ ~s("name":"Kente Shirt")
      assert html =~ ~s("price":"250.00")
      assert html =~ ~s("priceCurrency":"GHS")
    end

    test "omits script tag entirely when json_ld is nil" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" />
        """)

      refute html =~ ~s(<script type="application/ld+json")
    end
  end

  describe "meta_tags/1 — security" do
    test "escapes HTML in title and description" do
      # Untrusted input (a merchant's store name, product title) should
      # never produce an XSS via meta tag injection.
      assigns = %{
        title: ~s|Evil "><script>alert(1)</script>|,
        description: ~s|Evil "><script>alert(1)</script>|
      }

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title={@title} description={@description} />
        """)

      refute html =~ ~s|<script>alert(1)</script>|
      assert html =~ "&quot;"
    end
  end
end
