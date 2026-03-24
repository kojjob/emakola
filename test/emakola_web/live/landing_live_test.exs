defmodule EmakolaWeb.LandingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "landing page" do
    test "renders with Emakola branding and key content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Emakola"
      assert html =~ "Launch Your Online Store in Ghana"
      assert html =~ "Shop Trusted Local Businesses"
    end

    test "renders navigation with correct links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Features"
      assert html =~ "Pricing"
      assert html =~ "How It Works"
      assert html =~ "Get Started"
      assert html =~ "Login"
    end

    test "nav has ScrollGlass hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(phx-hook="ScrollGlass")
    end

    test "page has ScrollReveal hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(phx-hook="ScrollReveal")
    end

    test "does NOT have ThemeToggle hook", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      refute html =~ ~s(phx-hook="ThemeToggle")
    end

    test "renders hero section with dual CTAs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Start Selling"
      assert html =~ "Browse Stores"
      assert html =~ "FOR MERCHANTS"
      assert html =~ "FOR SHOPPERS"
    end

    test "renders trust bar with payment partners", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Trusted by"
      assert html =~ "MTN MoMo"
      assert html =~ "Vodafone Cash"
      assert html =~ "Paystack"
      assert html =~ "Hubtel"
      assert html =~ "AirtelTigo"
    end

    test "renders how it works section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "How It Works"
      assert html =~ "Create Your Store"
      assert html =~ "Add Products"
      assert html =~ "Pay with MoMo"
    end

    test "renders features section with Emakola features", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Mobile Money Payments"
      assert html =~ "WhatsApp Notifications"
      assert html =~ "Merchant Dashboard"
      assert html =~ "Multi-Store Management"
      assert html =~ "Inventory Tracking"
      assert html =~ "Shipping"
    end

    test "renders pricing section with GHS amounts", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Starter"
      assert html =~ "Growth"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
      assert html =~ "GHS 29"
      assert html =~ "GHS 79"
      assert html =~ "3.5%"
      assert html =~ "Most Popular"
    end

    test "renders testimonials section with merchant stories", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Ama Mensah"
      assert html =~ "Kwame Asante"
      assert html =~ "Efua Owusu"
      assert html =~ "Accra"
      assert html =~ "Kumasi"
      assert html =~ "Takoradi"
    end

    test "renders footer with Emakola links", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Privacy Policy"
      assert html =~ "Terms of Service"
      assert html =~ "Help Center"
    end

    test "sets correct SEO meta tags", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Emakola"
      assert html =~ "Online Stores for Ghana"
    end

    test "hero images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "hero-merchant.jpg"
      assert html =~ "hero-shopper.jpg"
    end

    test "testimonial images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "testimonial-1.jpg"
      assert html =~ "testimonial-2.jpg"
      assert html =~ "testimonial-3.jpg"
    end

    test "product card images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "product-kente.jpg"
      assert html =~ "product-shea.jpg"
      assert html =~ "product-ankara.jpg"
    end

    test "feature and how-it-works images are referenced", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "feature-mobile-money.jpg"
      assert html =~ "feature-multi-store.jpg"
      assert html =~ "how-merchant.jpg"
      assert html =~ "how-shopper.jpg"
    end
  end
end
