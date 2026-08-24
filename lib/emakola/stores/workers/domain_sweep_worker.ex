defmodule Emakola.Stores.Workers.DomainSweepWorker do
  @moduledoc """
  Cron sweep over every custom domain still waiting to go live.

  Two jobs. It re-checks each one's certificate, and it retires the ones whose
  DNS was never connected — which is both the answer to "what happens to a
  domain nobody finishes setting up" and the release valve for squatting: an
  expired row drops out of the partial unique index, so the hostname becomes
  claimable again.

  Cron rather than self-rescheduling, matching every other poller here — no
  worker in this codebase uses `{:snooze, _}`.
  """

  use Oban.Worker, queue: :domains, max_attempts: 1

  require Ash.Query
  require Logger

  alias Emakola.Stores
  alias Emakola.Stores.Domains
  alias Emakola.Stores.Workers.DomainCertificateWorker

  @default_deadline_days 7

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {:ok, domains} = Stores.list_verifying_domains(authorize?: false)
    Enum.each(domains, &sweep/1)
    :ok
  end

  defp sweep(domain) do
    if overdue?(domain) do
      retire(domain)
    else
      DomainCertificateWorker.new(%{"store_domain_id" => domain.id}) |> Oban.insert()
    end
  end

  defp retire(domain) do
    Logger.info("[domain_sweep] retiring #{domain.host} — never connected")
    Domains.expire(domain, "Your domain was not connected in time. You can try again.")
  end

  defp overdue?(%{verifying_since: nil}), do: false

  defp overdue?(%{verifying_since: since}) do
    DateTime.diff(DateTime.utc_now(), since, :day) >= deadline_days()
  end

  defp deadline_days,
    do: Application.get_env(:emakola, :custom_domain_verify_days, @default_deadline_days)
end
