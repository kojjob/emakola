defmodule Emakola.Stores.Domains do
  @moduledoc """
  Coordinates the multi-step parts of custom-domain management, so the
  LiveViews and the verification workers all go through one place.

  The interesting one is `claim/3`. An apex claim is really *two* rows — the
  apex itself, and a `www.` sibling that redirects to it. A merchant who wires
  only the apex would otherwise end up with a dead `www.` and, given the
  audience, would not diagnose it. The pair is created in a transaction: a
  half-wired domain is worse than none.
  """

  alias Emakola.Repo
  alias Emakola.Stores
  alias Emakola.Stores.DomainInstructions
  alias Emakola.Stores.DomainResolver

  @doc """
  Claims a custom domain for a store.

  Returns `{:ok, [apex, www_alias]}` for an apex domain and `{:ok, [domain]}`
  for a subdomain. A leading `www.` is treated as the apex form.
  """
  @spec claim(struct(), String.t(), keyword()) :: {:ok, [struct()]} | {:error, term()}
  def claim(store, host, opts \\ []) do
    host = normalize(host)

    if DomainInstructions.apex?(host) do
      claim_apex_pair(store, strip_www(host), opts)
    else
      with {:ok, domain} <- claim_custom(store, host, opts), do: {:ok, [domain]}
    end
  end

  @doc "Staff approval: moves a pending domain into verification."
  @spec request_verification(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def request_verification(domain, opts \\ []) do
    Stores.request_domain_verification(domain, Keyword.put_new(opts, :authorize?, false))
  end

  @doc "The certificate is issued and the host is live."
  @spec mark_active(struct(), keyword()) :: {:ok, struct()} | {:error, term()}
  def mark_active(domain, opts \\ []) do
    Stores.mark_domain_active(domain, Keyword.put_new(opts, :authorize?, false))
  end

  @doc """
  Retires a domain, releasing the hostname for anyone else to claim.

  Used both by the sweeper, when DNS was never connected, and by staff
  revoking a domain.
  """
  @spec expire(struct(), String.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def expire(domain, reason, opts \\ []) do
    Stores.expire_store_domain(
      domain,
      %{reason: reason},
      Keyword.put_new(opts, :authorize?, false)
    )
  end

  @doc "Staff rejecting a request. Same terminal state as an expiry."
  @spec revoke(struct(), String.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def revoke(domain, reason, opts \\ []), do: expire(domain, reason, opts)

  defp claim_apex_pair(store, apex, opts) do
    result =
      Repo.transaction(fn ->
        with {:ok, apex_domain} <- claim_custom(store, apex, opts),
             {:ok, alias_domain} <- claim_alias(store, "www." <> apex, opts) do
          [apex_domain, alias_domain]
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    # The resource's own invalidation hook fired inside the transaction above,
    # i.e. before the commit. Clear again now that the rows are really there.
    Enum.each([apex, "www." <> apex], &DomainResolver.invalidate/1)
    DomainResolver.invalidate_slug(store.slug)

    result
  end

  defp claim_custom(store, host, opts) do
    Stores.claim_custom_domain(
      %{store_id: store.id, host: host},
      Keyword.put_new(opts, :authorize?, false)
    )
  end

  defp claim_alias(store, host, opts) do
    Stores.claim_custom_domain_alias(
      %{store_id: store.id, host: host},
      Keyword.put_new(opts, :authorize?, false)
    )
  end

  defp strip_www("www." <> rest), do: rest
  defp strip_www(host), do: host

  defp normalize(host), do: host |> to_string() |> String.trim() |> String.downcase()
end
