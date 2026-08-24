defmodule Emakola.Stores.DomainInstructionsTest do
  use ExUnit.Case, async: true

  alias Emakola.Stores.DomainInstructions

  describe "apex?/1" do
    test "two labels is an apex domain" do
      assert DomainInstructions.apex?("kentekingdom.com")
      assert DomainInstructions.apex?("kentekingdom.io")
    end

    test "three or more labels is a subdomain" do
      refute DomainInstructions.apex?("shop.kentekingdom.com")
      refute DomainInstructions.apex?("a.b.kentekingdom.com")
    end

    test "a www. host is treated as its apex" do
      assert DomainInstructions.apex?("www.kentekingdom.com")
    end

    test "normalizes case and whitespace" do
      assert DomainInstructions.apex?("  KenteKingdom.COM  ")
    end
  end

  describe "records_for/1 on an apex domain" do
    setup do
      {:ok, records: DomainInstructions.records_for("kentekingdom.com")}
    end

    test "returns exactly three records", %{records: records} do
      assert length(records) == 3
      assert Enum.map(records, & &1.type) == ["A", "AAAA", "CNAME"]
    end

    test "the A record points at the configured IPv4", %{records: records} do
      a = Enum.find(records, &(&1.type == "A"))
      assert a.name == "@"
      assert a.value == "66.241.124.228"
    end

    # Not optional: the app's IPv4 is SHARED, so Fly cannot prove ownership from
    # the A record alone and the certificate hangs on "Awaiting configuration".
    # The dedicated IPv6 is what satisfies issuance and renewal.
    test "the AAAA record points at the dedicated IPv6", %{records: records} do
      aaaa = Enum.find(records, &(&1.type == "AAAA"))
      assert aaaa.name == "@"
      assert aaaa.value == "2a09:8280:1::126:6f75:0"
    end

    test "a www CNAME ships by default", %{records: records} do
      cname = Enum.find(records, &(&1.type == "CNAME"))
      assert cname.name == "www"
      assert cname.value == "emakola.fly.dev"
    end

    test "every record carries an icon for non-reading merchants", %{records: records} do
      assert Enum.all?(records, &(is_binary(&1.icon) and &1.icon != ""))
    end
  end

  describe "records_for/1 on a subdomain" do
    test "returns a single CNAME using the leading label" do
      assert [record] = DomainInstructions.records_for("shop.kentekingdom.com")
      assert record.type == "CNAME"
      assert record.name == "shop"
      assert record.value == "emakola.fly.dev"
    end

    test "uses the full prefix for a deeper subdomain" do
      assert [record] = DomainInstructions.records_for("a.b.kentekingdom.com")
      assert record.name == "a.b"
    end
  end

  describe "records_for/1 on a www host" do
    test "gives the apex treatment, not a lone CNAME" do
      records = DomainInstructions.records_for("www.kentekingdom.com")
      assert length(records) == 3
      assert Enum.map(records, & &1.type) == ["A", "AAAA", "CNAME"]
    end
  end

  describe "targets come from config" do
    test "reads :fly_dns_targets rather than hardcoding" do
      original = Application.get_env(:emakola, :fly_dns_targets)

      Application.put_env(:emakola, :fly_dns_targets,
        a: "1.2.3.4",
        aaaa: "::1",
        cname: "other.fly.dev"
      )

      on_exit(fn -> Application.put_env(:emakola, :fly_dns_targets, original) end)

      records = DomainInstructions.records_for("kentekingdom.com")
      assert Enum.map(records, & &1.value) == ["1.2.3.4", "::1", "other.fly.dev"]
    end
  end
end
