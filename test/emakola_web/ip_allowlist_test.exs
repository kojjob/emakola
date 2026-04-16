defmodule EmakolaWeb.IPAllowlistTest do
  @moduledoc """
  Unit tests for the IPv4 allowlist helper used by HubtelAllowlist plug.

  The helper supports:
    * Exact IPv4 match    — e.g. "1.2.3.4"
    * IPv4 CIDR match     — e.g. "10.0.0.0/24"

  IPv6 is not supported and must be rejected by `parse/1` with `:error`.
  Hubtel uses IPv4 and this helper is scoped to that use case.
  """
  use ExUnit.Case, async: true

  alias EmakolaWeb.IPAllowlist

  describe "parse/1" do
    test "parses a bare IPv4 address" do
      assert {:ok, {:ip, {1, 2, 3, 4}}} = IPAllowlist.parse("1.2.3.4")
    end

    test "parses a CIDR range" do
      assert {:ok, {:cidr, {10, 0, 0, 0}, 24}} = IPAllowlist.parse("10.0.0.0/24")
    end

    test "parses /32 as a single-host CIDR" do
      assert {:ok, {:cidr, {192, 168, 1, 1}, 32}} = IPAllowlist.parse("192.168.1.1/32")
    end

    test "parses /0 as a match-all CIDR" do
      assert {:ok, {:cidr, {0, 0, 0, 0}, 0}} = IPAllowlist.parse("0.0.0.0/0")
    end

    test "rejects malformed IPv4 address" do
      assert :error = IPAllowlist.parse("not-an-ip")
      assert :error = IPAllowlist.parse("999.0.0.1")
      assert :error = IPAllowlist.parse("1.2.3")
    end

    test "rejects out-of-range CIDR mask" do
      assert :error = IPAllowlist.parse("10.0.0.0/33")
      assert :error = IPAllowlist.parse("10.0.0.0/-1")
    end

    test "rejects IPv6 address" do
      assert :error = IPAllowlist.parse("::1")
      assert :error = IPAllowlist.parse("2001:db8::1")
    end

    test "rejects empty string" do
      assert :error = IPAllowlist.parse("")
    end

    test "trims whitespace before parsing" do
      assert {:ok, {:ip, {1, 2, 3, 4}}} = IPAllowlist.parse("  1.2.3.4  ")
    end
  end

  describe "parse_all/1" do
    test "parses a list of valid rules" do
      assert {:ok, rules} = IPAllowlist.parse_all(["1.2.3.4", "10.0.0.0/8"])
      assert length(rules) == 2
    end

    test "returns error with a list of invalid entries" do
      assert {:error, invalid} = IPAllowlist.parse_all(["1.2.3.4", "bogus", "10.0.0.0/33"])
      assert invalid == ["bogus", "10.0.0.0/33"]
    end

    test "empty list is ok" do
      assert {:ok, []} = IPAllowlist.parse_all([])
    end
  end

  describe "allowed?/2 — exact IP match" do
    setup do
      {:ok, rules} = IPAllowlist.parse_all(["1.2.3.4", "5.6.7.8"])
      {:ok, rules: rules}
    end

    test "matches an allowed IP", %{rules: rules} do
      assert IPAllowlist.allowed?({1, 2, 3, 4}, rules)
      assert IPAllowlist.allowed?({5, 6, 7, 8}, rules)
    end

    test "rejects a non-listed IP", %{rules: rules} do
      refute IPAllowlist.allowed?({9, 9, 9, 9}, rules)
      refute IPAllowlist.allowed?({1, 2, 3, 5}, rules)
    end
  end

  describe "allowed?/2 — CIDR match" do
    setup do
      {:ok, rules} = IPAllowlist.parse_all(["10.0.0.0/24", "192.168.0.0/16"])
      {:ok, rules: rules}
    end

    test "matches IPs within /24 range", %{rules: rules} do
      assert IPAllowlist.allowed?({10, 0, 0, 0}, rules)
      assert IPAllowlist.allowed?({10, 0, 0, 1}, rules)
      assert IPAllowlist.allowed?({10, 0, 0, 127}, rules)
      assert IPAllowlist.allowed?({10, 0, 0, 255}, rules)
    end

    test "rejects IPs just outside /24 range", %{rules: rules} do
      refute IPAllowlist.allowed?({10, 0, 1, 0}, rules)
      refute IPAllowlist.allowed?({9, 255, 255, 255}, rules)
    end

    test "matches IPs within /16 range", %{rules: rules} do
      assert IPAllowlist.allowed?({192, 168, 0, 1}, rules)
      assert IPAllowlist.allowed?({192, 168, 100, 200}, rules)
      assert IPAllowlist.allowed?({192, 168, 255, 255}, rules)
    end

    test "rejects IPs just outside /16 range", %{rules: rules} do
      refute IPAllowlist.allowed?({192, 167, 255, 255}, rules)
      refute IPAllowlist.allowed?({192, 169, 0, 0}, rules)
    end
  end

  describe "allowed?/2 — edge cases" do
    test "/32 is equivalent to exact match" do
      {:ok, rules} = IPAllowlist.parse_all(["203.0.113.5/32"])

      assert IPAllowlist.allowed?({203, 0, 113, 5}, rules)
      refute IPAllowlist.allowed?({203, 0, 113, 4}, rules)
      refute IPAllowlist.allowed?({203, 0, 113, 6}, rules)
    end

    test "/0 matches every IPv4 address" do
      {:ok, rules} = IPAllowlist.parse_all(["0.0.0.0/0"])

      assert IPAllowlist.allowed?({0, 0, 0, 0}, rules)
      assert IPAllowlist.allowed?({255, 255, 255, 255}, rules)
      assert IPAllowlist.allowed?({8, 8, 8, 8}, rules)
    end

    test "empty rule list rejects everything" do
      assert IPAllowlist.allowed?({1, 2, 3, 4}, []) == false
    end

    test "IPv6 remote_ip tuple is never allowed (no matching rule shape)" do
      {:ok, rules} = IPAllowlist.parse_all(["0.0.0.0/0"])

      ipv6 = {0, 0, 0, 0, 0, 0, 0, 1}
      refute IPAllowlist.allowed?(ipv6, rules)
    end
  end
end
