defmodule EmakolaWeb.Plugs.CanonicalHostTest do
  @moduledoc """
  301-redirects non-canonical alias hosts (emakola.com, www, the Fly default)
  to the canonical apex, so SEO link equity and visitors consolidate on one host.
  Ships dark: with no configured redirect hosts it is a pure pass-through, so it
  can be wired into the pipeline before the emakola.io DNS/cert cutover.
  """
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias EmakolaWeb.Plugs.CanonicalHost

  defp call(host, path, opts) do
    conn(:get, path) |> Map.put(:host, host) |> CanonicalHost.call(CanonicalHost.init(opts))
  end

  test "301-redirects a configured alias host to the apex, preserving path + query" do
    conn =
      call("emakola.com", "/@shop/products/x?ref=wa",
        hosts: ["emakola.com"],
        apex: "https://emakola.io"
      )

    assert conn.halted
    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://emakola.io/@shop/products/x?ref=wa"]
  end

  test "redirect without a query string omits the trailing ?" do
    conn =
      call("www.emakola.com", "/pricing", hosts: ["www.emakola.com"], apex: "https://emakola.io")

    assert get_resp_header(conn, "location") == ["https://emakola.io/pricing"]
  end

  test "passes through the canonical apex host" do
    conn = call("emakola.io", "/pricing", hosts: ["emakola.com"], apex: "https://emakola.io")

    refute conn.halted
    assert conn.status == nil
  end

  test "passes through an unknown host (e.g. a future merchant subdomain) — never redirects it" do
    conn =
      call("yourshop.emakola.io", "/@shop", hosts: ["emakola.com"], apex: "https://emakola.io")

    refute conn.halted
  end

  test "ships dark: no redirect hosts configured ⇒ pure pass-through" do
    conn = call("emakola.com", "/", hosts: [], apex: "https://emakola.io")

    refute conn.halted
  end
end
