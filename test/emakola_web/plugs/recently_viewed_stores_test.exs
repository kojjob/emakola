defmodule EmakolaWeb.Plugs.RecentlyViewedStoresTest do
  @moduledoc """
  Pins the contract for `RecentlyViewedStores`:

    * Visiting `/@<slug>` prepends the slug to the cookie
    * Subsequent visits to a NEW slug push it to the front (LRU order)
    * Re-visiting an existing slug dedupes — moves it to front, no duplicate
    * The list is capped at 8 entries (oldest fall off)
    * Non-storefront paths (`/`, `/admin/...`, `/products`) leave the cookie alone
    * Slugs containing `..`, `;`, `%`, or empty are rejected (no cookie change)
    * `list_from_cookie/1` parses the cookie value, capping at 8 slugs
  """
  use EmakolaWeb.ConnCase, async: true

  alias EmakolaWeb.Plugs.RecentlyViewedStores

  @cookie_name "recently_viewed_stores"

  # Helper: run the plug for `path`, threading any existing cookies in.
  # Returns the conn after fetch_cookies/1 so callers can read
  # `conn.cookies` to assert what the response set.
  defp visit(path, prior_cookie \\ nil) do
    conn = Plug.Test.conn(:get, path)

    conn =
      case prior_cookie do
        nil -> conn
        val -> Plug.Test.put_req_cookie(conn, @cookie_name, val)
      end

    conn
    |> RecentlyViewedStores.call([])
    |> Plug.Conn.fetch_cookies()
    |> apply_resp_cookies()
  end

  # Simulates the round-trip: merges any response cookies the plug just
  # set into `conn.cookies` so assertions can read the post-plug state
  # whether the plug took a no-op branch (no resp_cookies) or set one.
  defp apply_resp_cookies(conn) do
    merged = Map.merge(conn.cookies, simple_resp_cookies(conn))
    Map.put(conn, :cookies, merged)
  end

  defp simple_resp_cookies(conn) do
    for {name, %{value: value}} <- conn.resp_cookies, into: %{}, do: {name, value}
  end

  describe "call/2 — storefront slug capture" do
    test "first visit to /@foo sets the cookie to \"foo\"" do
      conn = visit("/@foo")

      assert conn.cookies[@cookie_name] == "foo"
      assert %{value: "foo", http_only: true, same_site: "Lax"} = conn.resp_cookies[@cookie_name]
    end

    test "captures slug ignoring trailing path segments" do
      conn = visit("/@foo/products/123")

      assert conn.cookies[@cookie_name] == "foo"
    end

    test "subsequent visit to /@bar prepends to the existing cookie" do
      conn = visit("/@bar", "foo")

      assert conn.cookies[@cookie_name] == "bar,foo"
    end

    test "re-visiting an existing store dedupes and moves it to the front" do
      conn = visit("/@foo", "bar,foo")

      assert conn.cookies[@cookie_name] == "foo,bar"
    end

    test "re-visiting a slug already at the front leaves the order unchanged" do
      conn = visit("/@foo", "foo,bar,baz")

      assert conn.cookies[@cookie_name] == "foo,bar,baz"
    end

    test "caps the list at 8 entries (oldest dropped)" do
      prior = "s7,s6,s5,s4,s3,s2,s1,s0"
      conn = visit("/@s8", prior)

      slugs = String.split(conn.cookies[@cookie_name], ",")

      assert length(slugs) == 8
      assert hd(slugs) == "s8"
      # s0 (oldest) dropped
      refute "s0" in slugs
      assert "s7" in slugs
    end

    test "sets cookie attributes: http_only, same_site=Lax, 30-day max-age, unsigned" do
      conn = visit("/@foo")
      cookie = conn.resp_cookies[@cookie_name]

      assert cookie.http_only == true
      assert cookie.same_site == "Lax"
      assert cookie.max_age == 60 * 60 * 24 * 30
      assert Map.get(cookie, :sign, false) == false
    end
  end

  describe "call/2 — non-storefront paths are no-ops" do
    for path <- ["/", "/admin/dashboard", "/products", "/auth/login", "/stores"] do
      test "leaves the cookie untouched on #{path}" do
        conn = visit(unquote(path), "foo,bar")

        # No new cookie set on the response
        refute Map.has_key?(conn.resp_cookies, @cookie_name)
        # And the request cookie value is preserved
        assert conn.cookies[@cookie_name] == "foo,bar"
      end
    end

    test "no cookie is set when there was none and path is not storefront" do
      conn = visit("/admin/dashboard")

      refute Map.has_key?(conn.resp_cookies, @cookie_name)
    end
  end

  describe "call/2 — slug sanitization" do
    for {label, path} <- [
          {"path traversal", "/@../etc/passwd"},
          {"semicolon injection", "/@foo;bar"},
          {"uppercase letters", "/@Foo"},
          {"empty slug after /@", "/@"},
          {"trailing slash with empty slug", "/@/products"},
          {"percent-encoded dot-dot", "/@%2E%2E"},
          {"underscore (not in allowlist)", "/@foo_bar"},
          {"slug starting with hyphen", "/@-foo"},
          {"slug with whitespace", "/@foo bar"}
        ] do
      test "rejects #{label} (#{path}) — cookie unchanged" do
        conn = visit(unquote(path), "previous")

        # No response cookie written for invalid slugs
        refute Map.has_key?(conn.resp_cookies, @cookie_name)
        assert conn.cookies[@cookie_name] == "previous"
      end
    end

    test "accepts a 63-char slug (boundary)" do
      slug = String.duplicate("a", 63)
      conn = visit("/@" <> slug)

      assert conn.cookies[@cookie_name] == slug
    end

    test "rejects a 64-char slug (over boundary) — cookie unchanged" do
      slug = String.duplicate("a", 64)
      conn = visit("/@" <> slug, "kept")

      refute Map.has_key?(conn.resp_cookies, @cookie_name)
      assert conn.cookies[@cookie_name] == "kept"
    end
  end

  describe "list_from_cookie/1" do
    test "returns [] when the cookie is absent" do
      assert RecentlyViewedStores.list_from_cookie(%{}) == []
    end

    test "returns [] when the cookie is empty" do
      assert RecentlyViewedStores.list_from_cookie(%{@cookie_name => ""}) == []
    end

    test "splits and returns the slugs in order" do
      assert RecentlyViewedStores.list_from_cookie(%{@cookie_name => "foo,bar,baz"}) ==
               ["foo", "bar", "baz"]
    end

    test "caps at 8 entries even if the cookie has more" do
      cookies = %{@cookie_name => "a,b,c,d,e,f,g,h,i,j"}

      assert RecentlyViewedStores.list_from_cookie(cookies) ==
               ["a", "b", "c", "d", "e", "f", "g", "h"]
    end

    test "drops empty entries between commas" do
      assert RecentlyViewedStores.list_from_cookie(%{@cookie_name => "foo,,bar"}) ==
               ["foo", "bar"]
    end

    test "returns [] when called with a non-map" do
      assert RecentlyViewedStores.list_from_cookie(nil) == []
      assert RecentlyViewedStores.list_from_cookie("not-a-map") == []
    end
  end

  describe "cookie_name/0" do
    test "returns the cookie name constant" do
      assert RecentlyViewedStores.cookie_name() == @cookie_name
    end
  end
end
