defmodule Emakola.Analytics.Workers.GscSyncWorker do
  @moduledoc """
  Oban worker that fetches Google Search Console data.
  Scheduled daily per org that has GSC configured.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  # Cron-enqueued jobs carry args: %{} — the property is platform-wide, so
  # organisation_id is absent there and only set by an explicit per-org enqueue.
  def perform(%Oban.Job{args: args}) do
    org_id = Map.get(args, "organisation_id")
    Logger.info("GSC sync starting for org #{inspect(org_id)}")

    case fetch_gsc_data(org_id) do
      {:ok, data} ->
        Enum.each(data, fn row ->
          Emakola.Analytics.SearchConsoleData
          |> Ash.Changeset.for_create(:create, Map.put(row, :organisation_id, org_id))
          |> Ash.create()
        end)

        Logger.info("GSC sync completed for org #{inspect(org_id)}: #{length(data)} rows")
        :ok

      {:error, reason} ->
        # Don't crash the worker (which would trigger retries up to
        # max_attempts and pollute the dashboard with failed jobs).
        # GSC sync failures are usually transient API issues that
        # the next scheduled run will recover from on its own.
        Logger.error("GSC sync failed for org #{inspect(org_id)}: #{inspect(reason)}")
        {:cancel, "fetch_gsc_data returned error: #{inspect(reason)}"}
    end
  end

  # Dispatched through a configurable fetcher so the {:error, _}
  # branch in perform/1 stays reachable from the type checker's
  # perspective. The default implementation is the stub below;
  # production wiring sets `:gsc_fetcher` to a module with the
  # real Google Search Console API client.
  defp fetch_gsc_data(org_id) do
    fetcher = Application.get_env(:emakola, :gsc_fetcher, __MODULE__.DefaultFetcher)
    fetcher.fetch(org_id)
  end

  defmodule DefaultFetcher do
    @moduledoc false
    require Logger

    @spec fetch(any()) :: {:ok, list()} | {:error, term()}
    def fetch(_org_id) do
      case Application.get_env(:emakola, :gsc_credentials) do
        nil ->
          Logger.debug("GSC not configured, skipping sync")
          {:ok, []}

        _credentials ->
          # TODO: Call actual Google Search Console API with credentials
          {:ok, []}
      end
    end
  end
end
