defmodule EmakolaWeb.PricingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "pricing page" do
    test "renders all four plans with GHS amounts and rates", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ "Simple, Transparent Pricing"
      assert html =~ "Starter"
      assert html =~ "Growth"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
      assert html =~ "GHS 29"
      assert html =~ "GHS 79"
      assert html =~ "3.5% per sale"
      assert html =~ "1.2% per sale"
    end

    test "highlights the Pro plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")
      assert html =~ "Most Popular"
    end

    test "renders shared nav and footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(href="/stores")
      assert html =~ ~s(href="/auth/login")
      assert html =~ "Help Center"
    end

    test "registration CTAs point to /auth/register", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")
      assert html =~ ~s(href="/auth/register")
    end

    test "sets SEO title, canonical URL, and Offer JSON-LD", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pricing")

      assert html =~ "Pricing — Emakola"
      assert html =~ ~s(rel="canonical")
      assert html =~ "application/ld+json"
      assert html =~ "SoftwareApplication"
      assert html =~ ~s("priceCurrency":"GHS")
    end

    test "mobile menu toggles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pricing")

      refute render(view) =~ "animate-slide-down"

      assert view |> element("button[phx-click=toggle_mobile_menu]") |> render_click() =~
               "animate-slide-down"
    end
  end
end
