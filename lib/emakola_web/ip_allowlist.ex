defmodule EmakolaWeb.IPAllowlist do
  @moduledoc """
  Pure IPv4 allowlist matching used by webhook security plugs.

  Supports two rule shapes parsed from strings:

    * Exact IPv4 — `"203.0.113.5"`
    * IPv4 CIDR  — `"10.0.0.0/24"` (mask bits 0..32 inclusive)

  IPv6 is intentionally unsupported and returns `:error` from `parse/1`.
  Hubtel publishes IPv4-only webhook source ranges, and keeping this
  helper scoped to IPv4 avoids the extra complexity of mixed-family CIDR
  matching for a single-purpose security check.

  Everything here is pure — no IO, no config reads. The plug using this
  module is responsible for loading rules from application config.

  ## Example

      iex> {:ok, rules} = EmakolaWeb.IPAllowlist.parse_all(["10.0.0.0/24", "5.6.7.8"])
      iex> EmakolaWeb.IPAllowlist.allowed?({10, 0, 0, 42}, rules)
      true
      iex> EmakolaWeb.IPAllowlist.allowed?({1, 1, 1, 1}, rules)
      false
  """

  @type rule :: {:ip, :inet.ip4_address()} | {:cidr, :inet.ip4_address(), 0..32}

  @doc """
  Parse a single IPv4 or IPv4-CIDR string into a rule tuple.

  Returns `{:ok, rule}` on success or `:error` on malformed input. Never
  raises — callers pass untrusted config values through this.
  """
  @spec parse(String.t()) :: {:ok, rule()} | :error
  def parse(string) when is_binary(string) do
    string
    |> String.trim()
    |> parse_trimmed()
  end

  def parse(_), do: :error

  defp parse_trimmed(""), do: :error

  defp parse_trimmed(string) do
    case String.split(string, "/", parts: 2) do
      [ip_str] -> parse_ipv4(ip_str)
      [ip_str, mask_str] -> parse_cidr(ip_str, mask_str)
    end
  end

  defp parse_ipv4(ip_str) do
    case :inet.parse_ipv4strict_address(String.to_charlist(ip_str)) do
      {:ok, ip} -> {:ok, {:ip, ip}}
      {:error, _} -> :error
    end
  end

  defp parse_cidr(ip_str, mask_str) do
    with {mask, ""} <- Integer.parse(mask_str),
         true <- mask >= 0 and mask <= 32,
         {:ok, ip} <- :inet.parse_ipv4strict_address(String.to_charlist(ip_str)) do
      {:ok, {:cidr, ip, mask}}
    else
      _ -> :error
    end
  end

  @doc """
  Parse a list of rule strings. Returns `{:ok, rules}` if every entry parses,
  otherwise `{:error, invalid_entries}` listing the strings that failed.
  """
  @spec parse_all([String.t()]) :: {:ok, [rule()]} | {:error, [String.t()]}
  def parse_all(strings) when is_list(strings) do
    {rules, invalid} =
      Enum.reduce(strings, {[], []}, fn str, {acc, bad} ->
        case parse(str) do
          {:ok, rule} -> {[rule | acc], bad}
          :error -> {acc, [str | bad]}
        end
      end)

    case invalid do
      [] -> {:ok, Enum.reverse(rules)}
      bad -> {:error, Enum.reverse(bad)}
    end
  end

  @doc """
  Returns `true` if `remote_ip` (an `:inet.ip_address()` tuple) matches any
  rule in `rules`. IPv6 tuples and empty rule lists always return `false`.
  """
  @spec allowed?(:inet.ip_address(), [rule()]) :: boolean()
  def allowed?({_, _, _, _} = ip, rules) when is_list(rules) do
    Enum.any?(rules, &rule_match?(&1, ip))
  end

  def allowed?(_ip, _rules), do: false

  defp rule_match?({:ip, ip}, ip), do: true
  defp rule_match?({:ip, _}, _), do: false

  defp rule_match?({:cidr, network, mask_bits}, ip) do
    ip_int = ip4_to_int(ip)
    net_int = ip4_to_int(network)
    mask = cidr_mask(mask_bits)

    Bitwise.band(ip_int, mask) == Bitwise.band(net_int, mask)
  end

  defp ip4_to_int({a, b, c, d}) do
    Bitwise.bsl(a, 24) + Bitwise.bsl(b, 16) + Bitwise.bsl(c, 8) + d
  end

  # A CIDR mask of N high bits: e.g. /24 -> 0xFFFFFF00, /0 -> 0x00000000.
  defp cidr_mask(0), do: 0

  defp cidr_mask(bits) when bits in 1..32 do
    Bitwise.bsl(0xFFFFFFFF, 32 - bits) |> Bitwise.band(0xFFFFFFFF)
  end
end
