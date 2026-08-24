defmodule EmakolaWeb.OriginChecker do
  @moduledoc """
  Decides which origins may open a LiveView socket.

  Phoenix's `:check_origin` was a static list, which cannot express merchant
  custom domains — they are rows in a table, not config. This replaces it with
  an MFA.

  ## Why the order matters

  This runs on **every** socket connect, against a Fly `soft_limit` of 100, and
  anyone can probe it with an arbitrary `Host` header. So the checks run
  cheapest-first:

    1. scheme must be https — no lookup;
    2. platform hosts (apex, `www.`, `*.<subdomain base>`, canonical aliases) —
       no lookup, and this covers every ordinary storefront;
    3. an active `StoreDomain` row, served from ETS and with **misses cached
       too**, so an unknown host costs one lookup per minute rather than one
       per probe.

  Only `:active` domains get a socket. A pending or retired one must not.

  ## The failure mode this guards

  A rejected origin does not error visibly. The page renders fine over HTTP,
  LiveView silently falls back to long-polling, and long-polling then breaks
  across two Fly machines — so the symptom is an intermittently broken shop,
  days later, with green tests. Any change here should be verified with a real
  `wss://` handshake (`curl --http1.1`), not a status code.
  """

  alias Emakola.Stores.DomainResolver
  alias Emakola.Stores.Validations.ValidStoreHost

  @doc "True when `uri` may open a socket. Phoenix passes the parsed origin."
  @spec allowed?(URI.t()) :: boolean()
  def allowed?(%URI{scheme: "https", host: host}) when is_binary(host) and host != "" do
    ValidStoreHost.platform_host?(host) or active_custom_domain?(host)
  end

  def allowed?(_uri), do: false

  defp active_custom_domain?(host) do
    match?({:ok, %{status: :active}}, DomainResolver.lookup(host))
  end
end
