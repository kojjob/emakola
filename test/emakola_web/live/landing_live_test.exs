defmodule EmakolaWeb.LandingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "hero" do
    test "renders merchant-first hero with rotating words", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "For Ghana&#39;s Merchants" or html =~ "For Ghana's Merchants"
      assert html =~ "Be the next"
      assert html =~ "big name in Accra"
      assert html =~ "household brand"
      assert html =~ "MoMo success story"
      assert html =~ "market leader"
      assert html =~ "Start selling — free"
      assert html =~ "No credit card needed"
    end

    test "has no shopper hero", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      refute html =~ "Shop Trusted Local Businesses"
    end

    test "hero image is preloaded", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(rel="preload")
      assert html =~ "hero-market-woman.jpg"
    end
  end

  describe "nav" do
    test "renders marketing nav with correct links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(phx-hook="ScrollGlass")
      assert html =~ ~s(href="/pricing")
      assert html =~ ~s(href="/stores")
      assert html =~ ~s(href="/auth/login")
      assert html =~ ~s(href="/auth/register")
      assert html =~ ~s(href="/#faq")
    end

    test "mobile menu toggles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      refute render(view) =~ "animate-slide-down"

      assert view |> element("button[phx-click=toggle_mobile_menu]") |> render_click() =~
               "animate-slide-down"
    end
  end

  describe "store wall" do
    test "renders six vertical-diverse example stores", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Stores built on Emakola"
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
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Get paid in seconds"
      assert html =~ "Customers kept in the loop"
      assert html =~ "A storefront that loads fast everywhere"
      assert html =~ "GHS 85.00"
      assert html =~ "Order #1042 confirmed!"
      assert html =~ "story-momo.jpg"
    end
  end

  describe "features grid" do
    test "renders all nine features including dropshipping", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Everything you need to sell"

      for title <- [
            "Dropshipping &amp; suppliers",
            "Storefront themes",
            "Digital products",
            "Inventory tracking",
            "Shipping &amp; delivery",
            "Coupons &amp; discounts",
            "Analytics &amp; reports",
            "Blog &amp; recipes",
            "Multi-store"
          ] do
        assert html =~ title
      end
    end
  end

  describe "growth arc" do
    test "renders start/grow/scale cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

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
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "500+"
      assert html =~ "mobile money networks"
      assert html =~ "from checkout to payout"
    end
  end

  describe "launch steps" do
    test "renders the three launch steps", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Launch before lunch"
      assert html =~ "Add your first product"
      assert html =~ "Share your store link"
      assert html =~ "Get paid with MoMo"
    end
  end

  describe "faq" do
    test "renders seven FAQ entries as details elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Who can sell on Emakola?"
      assert html =~ "What is dropshipping on Emakola?"
      assert length(String.split(html, "<details")) - 1 == 7
    end
  end

  describe "no pricing on landing" do
    test "pricing grid lives on /pricing, not here", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ "Most Popular"
      refute html =~ "GHS 79"
    end
  end

  describe "seo" do
    test "sets merchant-first SEO meta and JSON-LD", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Start Selling Online in Ghana"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      assert html =~ "FAQPage"
      assert html =~ "SoftwareApplication"
      assert html =~ "Organization"
    end
  end

  describe "page chrome" do
    test "ScrollReveal hook and footer render", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(phx-hook="ScrollReveal")
      assert html =~ ~s(href="/pricing")
    end
  end
end
