defmodule EmakolaWeb.SEOTest do
  @moduledoc """
  Tests for the SEO meta_tags/1 function component.

  The component is the single source of truth for:
    - Standard <meta name="description"> and <link rel="canonical">
    - Open Graph tags (Facebook / WhatsApp unfurling)
    - Twitter Card tags
    - JSON-LD structured data (Google rich results)

  Critical for WhatsApp share previews — the Makola primary marketing
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

    test "defaults og:type to website and site_name to Makola" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="Home" description="Welcome." />
        """)

      assert html =~ ~s(<meta property="og:type" content="website")
      assert html =~ ~s(<meta property="og:site_name" content="Makola")
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

    # ── JSON-LD XSS regression (P1) ──────────────────────────────────
    #
    # Merchant-controlled fields flow into json_ld via product/store
    # descriptions. If the JSON is encoded with Jason's default `:json`
    # escape mode, a literal `</script>` in any string value breaks out
    # of the <script type="application/ld+json"> tag — arbitrary HTML/JS
    # executes on every customer's device.
    #
    # The fix is Jason.encode!(json_ld, escape: :html_safe), which
    # converts <, >, &, /, U+2028, U+2029 to \u... escapes. The raw HTML
    # bytes then cannot contain </script>, so the HTML tokenizer never
    # finds an early exit sequence. The JSON parser still decodes the
    # escapes back to the original characters in memory, so Google sees
    # the intended structured data.
    #
    # These tests pin the fix by asserting on raw BYTES in the rendered
    # HTML — they would fail (and silently so) under :json escape mode.

    test "json_ld does NOT leak a literal </script> sequence" do
      json_ld = %{
        "@context" => "https://schema.org",
        "@type" => "Product",
        "name" => "Evil Product",
        "description" => "Break out: </script><script>alert('xss')</script>"
      }

      assigns = %{json_ld: json_ld}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" json_ld={@json_ld} />
        """)

      # The script tag opens ONCE — if </script> leaked through, the
      # second injected <script> would appear in the output and we'd
      # see two script tags instead of one.
      script_tag_count =
        html
        |> String.split(~s(<script))
        |> length()
        |> Kernel.-(1)

      assert script_tag_count == 1,
             "expected exactly one <script> tag, got #{script_tag_count}. " <>
               "This means </script> leaked into the JSON-LD block as a raw byte " <>
               "sequence, breaking out of the script tag. Check that Jason.encode! " <>
               "is called with escape: :html_safe."

      # And the literal bytes "</script>" must not appear inside the
      # JSON-LD content — only the escaped \u003C\/script form.
      refute html =~ ~s|</script><script>|

      # The script tag must still close properly at the end.
      assert html =~ ~s|</script>|
    end

    test "json_ld does NOT leak U+2028 or U+2029 (JSON-valid but JS-invalid line separators)" do
      # U+2028 (LINE SEPARATOR) and U+2029 (PARAGRAPH SEPARATOR) are
      # valid JSON but are treated as line terminators by older
      # JavaScript parsers, breaking <script> content if not escaped.
      # `:html_safe` escapes them; `:json` default does not.
      json_ld = %{
        "@context" => "https://schema.org",
        "@type" => "Product",
        "description" => "Line\u2028separator\u2029paragraph"
      }

      assigns = %{json_ld: json_ld}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" json_ld={@json_ld} />
        """)

      # Raw U+2028 / U+2029 must not appear in the output byte stream.
      refute html =~ "\u2028"
      refute html =~ "\u2029"
    end

    test "json_ld escapes < and > to \\u003C and \\u003E" do
      json_ld = %{"name" => "<em>html-in-json</em>"}
      assigns = %{json_ld: json_ld}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" json_ld={@json_ld} />
        """)

      # The raw < and > inside JSON-LD values must be unicode-escaped so
      # they can't ever be interpreted as HTML tags by the tokenizer.
      refute html =~ ~s|"<em>html-in-json</em>"|
      assert html =~ "\\u003C"
    end

    test "legitimate non-hostile JSON-LD still round-trips correctly" do
      # Paranoia check: make sure the html_safe escape mode doesn't
      # corrupt normal content. A Google Rich Results Test round-trip
      # would catch any silent JSON corruption here.
      json_ld = %{
        "@context" => "https://schema.org",
        "@type" => "Product",
        "name" => "Authentic Kente Shirt",
        "description" => "Handwoven in Kumasi by master weavers.",
        "offers" => %{
          "@type" => "Offer",
          "price" => "250.00",
          "priceCurrency" => "GHS",
          "availability" => "https://schema.org/InStock"
        }
      }

      assigns = %{json_ld: json_ld}

      html =
        rendered_to_string(~H"""
        <SEO.meta_tags title="X" description="Y" json_ld={@json_ld} />
        """)

      # Extract the JSON-LD content and parse it — round-trip must match.
      [_full, json_content] = Regex.run(~r|<script[^>]*>(.*?)</script>|s, html)
      decoded = Jason.decode!(json_content)

      assert decoded["@type"] == "Product"
      assert decoded["name"] == "Authentic Kente Shirt"
      assert decoded["description"] == "Handwoven in Kumasi by master weavers."
      assert decoded["offers"]["price"] == "250.00"
      assert decoded["offers"]["priceCurrency"] == "GHS"
      assert decoded["offers"]["availability"] == "https://schema.org/InStock"
    end
  end
end
