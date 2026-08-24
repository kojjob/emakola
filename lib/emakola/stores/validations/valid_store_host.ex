defmodule Emakola.Stores.Validations.ValidStoreHost do
  @moduledoc """
  Validates a `StoreDomain` host.

  Three rules, in order of severity:

    * it must be a well-formed hostname;
    * it must not be a host the *platform* owns — the apex, the configured
      `PHX_HOST`, any canonical-redirect alias, or anything under the store
      subdomain base. This applies to **every** type. `ResolveStoreByHost` runs
      in the endpoint, before the router's `@apex_hosts` scope, so without this
      guard a `:custom` row for `emakola.fly.dev` would 301 the platform's own
      host to a merchant's store;
    * for `:subdomain` types only, its first label must not be a reserved
      platform word (so nobody claims `admin.makola.io`).

  The reserved-word rule is deliberately **not** applied to `:custom` hosts. It
  exists to protect labels on *our* base, and a merchant owns every label on
  their own domain — `shop.mybrand.com` is the most common custom-domain shape
  there is, and `shop` is a reserved word here.

  The host is normalized (trimmed + downcased) before checking, matching the
  normalization the create action applies before persisting.
  """

  use Ash.Resource.Validation

  # Labels a merchant must never be able to take on `*.makola.io` — they collide
  # with platform infrastructure, the apex's own routes, or common service names.
  @reserved ~w(
    www admin api app mail smtp imap pop ftp ns ns1 ns2 dns mx
    blog shop store dashboard staging stage dev test cdn assets static
    help support docs status billing pay checkout cart account accounts
    login signup signin auth oauth platform internal system root
    media images img video uploads files download downloads
  )

  # RFC-1123-ish: lowercase labels of [a-z0-9-] (no leading/trailing hyphen),
  # at least two dot-separated labels (a bare label is never a valid host here).
  @host_regex ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/

  @apex_hosts Application.compile_env!(:emakola, :apex_hosts)

  @impl true
  def validate(changeset, _opts, _context) do
    host = changeset |> Ash.Changeset.get_attribute(:host) |> normalize()
    type = Ash.Changeset.get_attribute(changeset, :type) || :subdomain

    cond do
      is_nil(host) or host == "" ->
        error(:host, "is required")

      not Regex.match?(@host_regex, host) ->
        error(:host, "is not a valid hostname")

      platform_owned?(host, type) ->
        # Deliberately vague: don't hand an attacker the platform host list.
        error(:host, "is not available")

      type == :subdomain and reserved_label?(host) ->
        error(:host, "uses a reserved subdomain name")

      true ->
        :ok
    end
  end

  @doc """
  Returns true if the host belongs to the platform rather than to a merchant.

  Covers the compile-time apex list, the configured `PHX_HOST` (and its `www.`
  form), every `:canonical_redirect_hosts` alias, and the store subdomain base
  along with everything under it.

  Shared with `EmakolaWeb.OriginChecker`, which uses it as the zero-database
  short-circuit before any host lookup.
  """
  def platform_host?(host) do
    host = normalize(host)
    platform_named_host?(host) or under_subdomain_base?(host)
  end

  # A `:subdomain` row lives UNDER the base by definition, so only the named
  # platform hosts (including the bare base) disqualify it. A `:custom` row has
  # no business anywhere in our namespace.
  defp platform_owned?(host, :custom), do: platform_host?(host)
  defp platform_owned?(host, _type), do: platform_named_host?(host)

  defp platform_named_host?(host) do
    host in @apex_hosts or
      host in endpoint_hosts() or
      host in canonical_redirect_hosts() or
      host == subdomain_base()
  end

  @doc """
  Returns true if the host's first label is a reserved platform word
  (`admin`, `api`, `www`, …). Accepts a bare label too. Shared with
  `EmakolaWeb.Plugs.ResolveStoreByHost` so an implicit `<slug>.<base>` subdomain
  can never shadow a reserved name.
  """
  def reserved_label?(host) do
    host |> String.split(".") |> List.first() |> Kernel.in(@reserved)
  end

  # Read from config rather than calling EmakolaWeb.Endpoint — the domain layer
  # must not depend on the web layer.
  defp endpoint_hosts do
    case get_in(Application.get_env(:emakola, EmakolaWeb.Endpoint, []), [:url, :host]) do
      host when is_binary(host) and host != "" -> [host, "www." <> host]
      _ -> []
    end
  end

  defp canonical_redirect_hosts do
    :emakola
    |> Application.get_env(:canonical_redirect_hosts, [])
    |> Enum.map(&normalize/1)
  end

  defp under_subdomain_base?(host) do
    case subdomain_base() do
      nil -> false
      base -> String.ends_with?(host, "." <> base)
    end
  end

  defp subdomain_base do
    case Application.get_env(:emakola, :store_subdomain_base) do
      base when is_binary(base) and base != "" -> normalize(base)
      _ -> nil
    end
  end

  defp normalize(nil), do: nil
  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()

  defp error(field, message) do
    {:error, Ash.Error.Changes.InvalidAttribute.exception(field: field, message: message)}
  end
end
