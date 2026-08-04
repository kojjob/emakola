defmodule EmakolaWeb.LandingControllerTest do
  use EmakolaWeb.ConnCase, async: true

  describe "hero" do
    test "renders merchant-first hero with rotating words", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "For Ghana&#39;s Merchants" or html =~ "For Ghana's Merchants"
      assert html =~ "Be the next"
      assert html =~ "big name"
      # The hero speaks to all of West Africa, not one city — a rotating word
      # naming Accra excludes Kumasi, Takoradi and everywhere Makola expands to.
      refute html =~ "big name in Accra"
      assert html =~ "household brand"
      assert html =~ "MoMo success story"
      assert html =~ "market leader"
      assert html =~ "Start selling — free"
      assert html =~ "No credit card needed"
    end

    # Cold-traffic repositioning: the page led with generic ecommerce features
    # (Discounts, Reports, Blog) while the differentiators shipped in #363/#364/
    # #367/#372-374 were invisible. Every claim below maps to shipped code.
    test "sells the differentiators, not just table stakes", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Pay Links"
      assert html =~ "Buyer Protection"
      assert html =~ "Susu"
      assert html =~ "MoMo"
      assert html =~ "Start with nothing"
      # Merchants here read less, so the film is the real explainer — it must
      # be reachable from the pitch, not buried in the nav.
      assert html =~ "/how-it-works/tour"
    end

    # These merchants are not strong readers. Card copy has to stay scannable;
    # the previous version averaged 20 words per card, which is a wall of text.
    test "differentiator copy stays short enough to scan", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      for phrase <- [
            "Send a link. Get paid on MoMo.",
            "We hold the money until they get it.",
            "Let them pay small amounts over time.",
            "No stock. No capital. Start today."
          ] do
        assert html =~ phrase
        assert length(String.split(phrase, " ")) <= 8, "#{phrase} is too long to scan"
      end
    end

    test "makes no stale claim about the theme count", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      # There are 21 selectable themes, not 14. Hardcoded counts rot silently,
      # so the copy carries no number at all.
      refute html =~ "14 beautiful looks"
      refute html =~ "14 themes"
    end

    test "has no shopper hero", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)
      refute html =~ "Shop Trusted Local Businesses"
    end

    test "hero image is preloaded", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)
      assert html =~ ~s(rel="preload")
      assert html =~ "hero-market-woman.jpg"
    end
  end

  describe "nav" do
    test "renders marketing nav with correct links", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(data-scroll-glass)
      assert html =~ ~s(href="/pricing")
      assert html =~ ~s(href="/stores")
      assert html =~ ~s(href="/auth/login")
      assert html =~ ~s(href="/auth/register")
      assert html =~ ~s(href="/#faq")
    end

    test "mobile menu is client-side toggled", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)
      document = LazyHTML.from_document(html)

      # The menu ships hidden and the button flips it purely client-side
      # (Phoenix.LiveView.JS commands) — no server event, no LiveView process.
      assert html =~ ~s(id="landing-mobile-menu")
      assert html =~ "animate-slide-down"
      assert html =~ ~s(id="landing-menu-button")

      assert document
             |> LazyHTML.query("#landing-menu-button[aria-expanded=false]")
             |> Enum.any?()

      assert document
             |> LazyHTML.query("#landing-menu-closed-icon[aria-hidden=true] .hero-bars-3")
             |> Enum.any?()

      assert document
             |> LazyHTML.query("#landing-menu-open-icon[aria-hidden=true] .hero-x-mark")
             |> Enum.any?()

      refute html =~ "toggle_mobile_menu"
    end
  end

  describe "store wall" do
    test "renders six vertical-diverse example stores", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Stores built on Makola"
      assert html =~ "Mansa Fresh"
      assert html =~ "Yaa Braids"
      assert html =~ "Adwoa Glow"
      assert html =~ "Efua&#39;s Kitchen" or html =~ "Efua's Kitchen"
      assert html =~ "Kojo the Tailor"
      assert html =~ "Kwaku Cuts"
      assert html =~ "GHS 150"
      assert html =~ "store-hair.jpg"
      assert html =~ "store-barber.jpg"
      assert html =~ "seamstresses"
    end
  end

  describe "feature stories" do
    test "renders three stories with floating UI copy", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Get paid in seconds"
      assert html =~ "Customers kept in the loop"
      assert html =~ "A storefront that loads fast everywhere"
      assert html =~ "GHS 85.00"
      assert html =~ "Order #1042 confirmed!"
      assert html =~ "story-momo.jpg"
    end
  end

  describe "features grid" do
    test "renders nine photo-led features with short titles", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Everything you need to sell"

      for title <- [
            "Dropshipping",
            "Themes",
            "Digital goods",
            "Stock",
            "Delivery",
            "Discounts",
            "Reports",
            "Blog &amp; recipes",
            "Many stores"
          ] do
        assert html =~ title
      end
    end

    test "features carry photos and color badges", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      for img <- [
            "feature-dropship.jpg",
            "feature-digital.jpg",
            "feature-stock.jpg",
            "feature-delivery.jpg",
            "feature-reports.jpg"
          ] do
        assert html =~ img
      end

      assert html =~ ~s(alt="Man pushing a cart stacked with boxes through the street")
      assert html =~ "bg-violet-500"
      assert html =~ "stagger-grid"
    end
  end

  describe "growth arc" do
    test "renders start/grow/scale cards", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "From first sale to household name"
      assert html =~ "START"
      assert html =~ "GROW"
      assert html =~ "SCALE"
      assert html =~ "Makola Market"
      assert html =~ "all 16 regions"
    end
  end

  describe "stats band" do
    test "renders cited stats", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "500+"
      assert html =~ "mobile money networks"
      assert html =~ "from checkout to payout"
    end
  end

  describe "launch steps" do
    test "renders the three photo step cards with number badges", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Launch before lunch"
      assert html =~ "Most merchants go live in under an hour."
      assert html =~ "Add your first product"
      assert html =~ "Share your store link"
      assert html =~ "Get paid with MoMo"
      assert html =~ "Snap it, price it, done"
      assert html =~ "WhatsApp it to your customers"
      assert html =~ "Money straight to your wallet"
      assert html =~ "step-add-product.jpg"
      assert html =~ "step-share-link.jpg"
      assert html =~ "step-get-paid.jpg"
      assert html =~ "bg-sky-500"
    end
  end

  describe "faq" do
    test "renders seven FAQ entries as details elements", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Who can sell on Makola?"
      assert html =~ "What is dropshipping on Makola?"

      faq_html =
        html
        |> String.split(~s(id="faq"))
        |> List.last()
        |> then(&String.slice(&1, 0, :binary.match(&1, "</section>") |> elem(0)))

      assert length(String.split(faq_html, "<details")) - 1 == 7
    end
  end

  describe "no pricing on landing" do
    test "pricing grid lives on /pricing, not here", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      refute html =~ "Most Popular"
      refute html =~ "GHS 79"
    end
  end

  describe "seo" do
    test "sets merchant-first SEO meta and JSON-LD", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ "Start Selling Online in Ghana"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      assert html =~ "FAQPage"
      assert html =~ "SoftwareApplication"
      assert html =~ "Organization"
    end

    test "JSON-LD graph decodes with offers and FAQ entries", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      [_, payload] =
        Regex.run(~r{<script type="application/ld\+json">\s*(.*?)\s*</script>}s, html)

      %{"@graph" => graph} = Jason.decode!(payload)

      software_app = Enum.find(graph, &(&1["@type"] == "SoftwareApplication"))
      faq_page = Enum.find(graph, &(&1["@type"] == "FAQPage"))

      assert length(software_app["offers"]) == 3
      assert length(faq_page["mainEntity"]) == 7
    end
  end

  describe "page chrome" do
    test "scroll-reveal binding and footer render", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ ~s(data-scroll-reveal)
      assert html =~ ~s(href="/pricing")
    end
  end
end
