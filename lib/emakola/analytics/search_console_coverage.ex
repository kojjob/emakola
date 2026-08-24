defmodule Emakola.Analytics.SearchConsoleCoverage do
  @moduledoc """
  Which hostnames our Search Console property actually reports on.

  The property is a Google **Domain** property (`sc-domain:makola.io`), so it
  covers the apex and every `*.makola.io` subdomain — including every store
  subdomain — in one place. A merchant's own domain is a *different* property
  and returns nothing.

  That matters because the failure is silent and looks like bad news: a
  merchant who moves to `hotdeals.africa` would see zero impressions on their
  SEO page and read it as "nobody is finding my shop", when in fact we are
  simply looking at the wrong property. Making the gap queryable lets the
  merchant and platform surfaces say so plainly instead.

  Closing the gap for real means each merchant verifying their own domain in
  Search Console and granting our service account access — a per-store
  property, which is its own piece of work. This module is the honest
  statement of the boundary until then.
  """

  alias Emakola.Stores.DomainResolver

  @doc """
  True when Search Console reports on `host`.

  False when GSC is unconfigured — we would rather report "unknown coverage"
  than claim data we do not have.
  """
  @spec covered?(String.t() | nil) :: boolean()
  def covered?(nil), do: false

  def covered?(host) do
    case property_domain() do
      nil -> false
      domain -> host == domain or String.ends_with?(normalize(host), "." <> domain)
    end
  end

  @doc """
  The store's primary host when that host falls **outside** the property, else
  `nil`. Surfaces are expected to warn when this returns a host.
  """
  @spec store_uncovered_host(String.t()) :: String.t() | nil
  def store_uncovered_host(slug) do
    case DomainResolver.primary_host(slug) do
      host when is_binary(host) -> unless covered?(host), do: host
      _ -> nil
    end
  end

  # "sc-domain:makola.io" -> "makola.io"; a URL-prefix property has no
  # subdomain coverage, so only its exact host counts.
  defp property_domain do
    case Application.get_env(:emakola, :gsc_site_url) do
      "sc-domain:" <> domain -> normalize(domain)
      url when is_binary(url) and url != "" -> url |> URI.parse() |> Map.get(:host)
      _ -> nil
    end
  end

  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()
end
