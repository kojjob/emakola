defmodule EmakolaWeb.LandingLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /" do
    test "renders landing page with key content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Emakola"
      assert html =~ "Ship Your SaaS"
      assert html =~ "Get Started Free"
    end

    test "nav has ScrollGlass hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(id="main-nav")
      assert html =~ ~s(phx-hook="ScrollGlass")
    end

    test "page wrapper has ScrollReveal hook attached", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(phx-hook="ScrollReveal")
    end

    test "sections have data-reveal attributes for scroll animations", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(data-reveal)
    end

    test "includes scrolled CSS styles for glass nav effect", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "#main-nav.scrolled"
      assert html =~ "backdrop-filter"
    end

    test "renders features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Features"
      assert html =~ "AI Agent Orchestration"
      assert html =~ "Stripe Billing"
    end

    test "renders pricing section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Pricing"
      assert html =~ "Free"
      assert html =~ "Pro"
      assert html =~ "Enterprise"
    end

    test "renders testimonials section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Testimonials"
      assert html =~ "Loved by founders"
    end
  end
end
