defmodule Emakola.Stores.Workers.DomainCertificateWorker do
  @moduledoc """
  Drives one custom domain from "staff approved it" to "it is serving".

  Asks Fly for a certificate, then re-checks until Fly reports `Ready`. Fly
  issues the certificate itself once the merchant's DNS resolves, so this
  worker is a poller, not a provisioner — and `HostnameCheck` already tells us
  what DNS resolves to, which is why nothing here does its own DNS lookup.

  Idempotent by design. It asks Fly whether a certificate exists *before*
  requesting one, so a duplicate run never burns Let's Encrypt quota (50 per
  week per registered domain). Re-running against a live domain cancels.
  """

  use Oban.Worker,
    queue: :domains,
    max_attempts: 3,
    unique: [period: 600, fields: [:worker, :args], states: [:available, :scheduled, :executing]]

  require Logger

  alias Emakola.Stores
  alias Emakola.Stores.Domains

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"store_domain_id" => id}}) do
    case Ash.get(Stores.StoreDomain, id, authorize?: false, not_found_error?: false) do
      {:ok, %{status: :verifying} = domain} -> check(domain)
      {:ok, %{status: status}} -> {:cancel, "domain is #{status}, not verifying"}
      _ -> {:cancel, "domain #{id} no longer exists"}
    end
  end

  defp check(domain) do
    if configured?() do
      do_check(domain)
    else
      # Same shape as the GSC sync: no credentials means no-op, not failure.
      Logger.debug("[domain_certificate] Fly not configured, skipping #{domain.host}")
      :ok
    end
  end

  defp do_check(domain) do
    case fly().get_certificate(domain.host) do
      {:ok, nil} -> request(domain)
      {:ok, status} -> record(domain, status)
      {:error, reason} -> cancel(domain, reason)
    end
  end

  defp request(domain) do
    case fly().add_certificate(domain.host) do
      {:ok, status} -> record(domain, status)
      {:error, reason} -> cancel(domain, reason)
    end
  end

  defp record(domain, %{ready?: true}) do
    case Domains.mark_active(domain) do
      {:ok, _} ->
        Logger.info("[domain_certificate] #{domain.host} is live")
        :ok

      {:error, reason} ->
        {:cancel, "could not activate #{domain.host}: #{inspect(reason)}"}
    end
  end

  defp record(domain, status) do
    _ = Stores.record_domain_check(domain, %{message: explain(status)}, authorize?: false)
    :ok
  end

  # Merchant-facing. Whatever Fly is unhappy about is what the merchant has to
  # fix at their registrar, so say it plainly rather than echoing a status code.
  defp explain(%{rate_limited_until: until}) when is_binary(until) and until != "",
    do: "Too many certificate attempts. Try again after #{until}."

  defp explain(%{validation_errors: [_ | _] = errors}), do: Enum.join(errors, "; ")
  defp explain(%{client_status: status}) when is_binary(status), do: status
  defp explain(_), do: "Checking your domain."

  defp cancel(domain, reason) do
    Logger.error("[domain_certificate] #{domain.host} failed: #{inspect(reason)}")
    {:cancel, "Fly returned #{inspect(reason)} for #{domain.host}"}
  end

  defp fly, do: Application.get_env(:emakola, :fly_certs, Emakola.Infra.FlyCerts)

  defp configured?,
    do: Application.get_env(:emakola, :fly_certs) != nil or Emakola.Infra.FlyCerts.configured?()
end
