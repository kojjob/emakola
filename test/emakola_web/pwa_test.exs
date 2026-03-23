defmodule EmakolaWeb.PWATest do
  @moduledoc """
  Tests for Progressive Web App (PWA) support.
  Tagged :pending — requires root layout to include PWA meta tags.
  """
  use EmakolaWeb.ConnCase, async: true

  describe "manifest.json" do
    test "is accessible and returns valid JSON", %{conn: conn} do
      conn = get(conn, "/manifest.json")
      assert response_content_type(conn, :json) || conn.status == 200

      body = json_response(conn, 200)
      assert body["name"] == "Emakola"
      assert body["short_name"] == "Emakola"
      assert body["display"] == "standalone"
      assert body["start_url"] == "/"
      assert body["theme_color"] == "#0C1F17"
      assert body["background_color"] == "#FAFAF9"
    end

    test "includes required icon entries", %{conn: conn} do
      body = conn |> get("/manifest.json") |> json_response(200)

      icons = body["icons"]
      assert is_list(icons)
      assert length(icons) >= 2

      sizes = Enum.map(icons, & &1["sizes"])
      assert "192x192" in sizes
      assert "512x512" in sizes
    end

    test "includes a maskable icon", %{conn: conn} do
      body = conn |> get("/manifest.json") |> json_response(200)

      maskable = Enum.find(body["icons"], fn icon -> icon["purpose"] == "maskable" end)
      assert maskable, "Expected at least one maskable icon"
      assert maskable["sizes"] == "512x512"
    end

    test "includes categories", %{conn: conn} do
      body = conn |> get("/manifest.json") |> json_response(200)
      assert "shopping" in body["categories"]
    end
  end

  describe "service worker (sw.js)" do
    test "is accessible and returns JavaScript", %{conn: conn} do
      conn = get(conn, "/sw.js")
      assert conn.status == 200

      content_type = Plug.Conn.get_resp_header(conn, "content-type") |> List.first()
      assert content_type =~ "javascript" or content_type =~ "text/javascript"
    end

    test "contains cache strategy code", %{conn: conn} do
      conn = get(conn, "/sw.js")
      body = conn.resp_body

      assert body =~ "install"
      assert body =~ "activate"
      assert body =~ "fetch"
      assert body =~ "caches"
    end

    test "references offline fallback page", %{conn: conn} do
      conn = get(conn, "/sw.js")
      assert conn.resp_body =~ "offline.html"
    end
  end

  describe "offline.html" do
    test "is accessible and contains offline messaging", %{conn: conn} do
      conn = get(conn, "/offline.html")
      assert conn.status == 200

      body = conn.resp_body
      assert body =~ "offline"
      assert body =~ "Emakola"
    end

    test "contains a retry mechanism", %{conn: conn} do
      conn = get(conn, "/offline.html")
      body = conn.resp_body

      # Should have a retry button or link
      assert body =~ "retry" or body =~ "Retry" or body =~ "Try Again" or body =~ "try again"
    end

    test "uses inline styles (no external stylesheet dependencies)", %{conn: conn} do
      conn = get(conn, "/offline.html")
      body = conn.resp_body

      assert body =~ "<style"
      # Should NOT reference external stylesheets
      refute body =~ ~r/<link[^>]+rel=["']stylesheet["'][^>]+href=["']http/
    end
  end

  describe "PWA meta tags in root layout" do
    test "root layout includes manifest link", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ ~r/<link[^>]+rel=["']manifest["'][^>]+href=["'][^"']*manifest\.json["']/
    end

    test "root layout includes theme-color meta tag", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ ~r/<meta[^>]+name=["']theme-color["'][^>]+content=["']#0C1F17["']/
    end

    test "root layout includes apple-mobile-web-app-capable", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ "apple-mobile-web-app-capable"
    end

    test "root layout includes service worker registration script", %{conn: conn} do
      conn = get(conn, "/")
      body = html_response(conn, 200)

      assert body =~ "serviceWorker"
      assert body =~ "sw.js"
    end
  end

  describe "PWA headers plug" do
    test "manifest.json has appropriate cache headers", %{conn: conn} do
      conn = get(conn, "/manifest.json")

      cache_control = Plug.Conn.get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control, "Expected cache-control header on manifest.json"
    end
  end
end
