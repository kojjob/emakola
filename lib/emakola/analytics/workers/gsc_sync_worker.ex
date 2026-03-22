defmodule Emakola.Analytics.Workers.GscSyncWorker do
  @moduledoc """
  Oban worker that fetches Google Search Console data.
  Scheduled daily per org that has GSC configured.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"organisation_id" => org_id}}) do
    Logger.info("GSC sync starting for org #{org_id}")

    {:ok, data} = fetch_gsc_data(org_id)

    Enum.each(data, fn row ->
      Emakola.Analytics.SearchConsoleData
      |> Ash.Changeset.for_create(:create, Map.put(row, :organisation_id, org_id))
      |> Ash.create()
    end)

    Logger.info("GSC sync completed for org #{org_id}: #{length(data)} rows")
    :ok
  end

  defp fetch_gsc_data(_org_id) do
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
