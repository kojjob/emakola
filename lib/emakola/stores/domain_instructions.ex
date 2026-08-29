defmodule Emakola.Stores.DomainInstructions do
  @moduledoc """
  Turns a custom domain into the DNS records a merchant must create at their
  registrar. Pure — no database, no network.

  Two shapes, because they need different records:

    * an **apex** domain (`kentekingdom.com`) cannot be a CNAME, so it needs
      `A` + `AAAA` records pointing at the app, plus a `www` CNAME;
    * a **subdomain** (`shop.kentekingdom.com`) needs one CNAME.

  The `AAAA` record on an apex claim is **not optional**. The app's IPv4 is a
  *shared* Fly address, so Fly cannot prove ownership of the hostname from the
  `A` record alone — issuance and renewal need the dedicated IPv6 (or an
  `_acme-challenge` CNAME, or a `_fly-ownership` TXT). Omit it and the
  certificate sits on "Awaiting configuration" forever. It is the single most
  likely reason a merchant's domain never goes live.

  The `www` CNAME ships by default rather than on request: a merchant who wires
  only the apex gets a dead `www.` and will not diagnose it.

  Targets come from `config :emakola, :fly_dns_targets` so they are never
  literals in a template.
  """

  @type dns_record :: %{
          type: String.t(),
          name: String.t(),
          value: String.t(),
          icon: String.t()
        }

  @doc """
  True when the host is a registrable apex (two labels), or the `www.` form of
  one — both get the apex record set.
  """
  @spec apex?(String.t()) :: boolean()
  def apex?(host) do
    host |> normalize() |> labels() |> length() == 2
  end

  @doc """
  The DNS records the merchant must create for `host`.

  Three for an apex domain (`A`, `AAAA`, `CNAME www`), one for a subdomain.
  """
  @spec records_for(String.t()) :: [dns_record()]
  def records_for(host) do
    host = normalize(host)

    if apex?(host) do
      [
        %{type: "A", name: "@", value: target(:a), icon: "hero-globe-alt"},
        %{type: "AAAA", name: "@", value: target(:aaaa), icon: "hero-globe-europe-africa"},
        %{type: "CNAME", name: "www", value: target(:cname), icon: "hero-arrow-right-circle"}
      ]
    else
      [
        %{
          type: "CNAME",
          name: subdomain_prefix(host),
          value: target(:cname),
          icon: "hero-arrow-right-circle"
        }
      ]
    end
  end

  # "shop.kentekingdom.com" -> "shop"; "a.b.kentekingdom.com" -> "a.b".
  # The registrable apex is always the last two labels.
  defp subdomain_prefix(host) do
    host |> labels() |> Enum.drop(-2) |> Enum.join(".")
  end

  # A leading "www." is stripped so www.kentekingdom.com is treated as its apex.
  defp labels(host) do
    case String.split(host, ".") do
      ["www" | rest] when rest != [] -> rest
      labels -> labels
    end
  end

  defp target(key) do
    :emakola
    |> Application.get_env(:fly_dns_targets, [])
    |> Keyword.fetch!(key)
  end

  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()
end
