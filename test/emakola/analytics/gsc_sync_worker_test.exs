defmodule Emakola.Analytics.GscSyncWorkerTest do
  @moduledoc """
  The GSC sync worker is useless unless something runs it. Wiring
  `:gsc_credentials` without a schedule yields a fetcher nobody calls, which
  looks identical to "Google returned no data" — hence this guard.
  """
  use ExUnit.Case, async: true

  alias Emakola.Analytics.Workers.GscSyncWorker

  test "the worker is scheduled in Oban's crontab" do
    crontab =
      :emakola
      |> Application.fetch_env!(Oban)
      |> Keyword.fetch!(:plugins)
      |> Enum.find_value(fn
        {Oban.Plugins.Cron, opts} -> Keyword.fetch!(opts, :crontab)
        _ -> nil
      end)

    assert GscSyncWorker in Enum.map(crontab, fn {_schedule, worker} -> worker end),
           "GscSyncWorker is not in the Oban crontab — GSC data would never sync"
  end

  # Oban.Plugins.Cron enqueues with args: %{} unless the crontab entry says
  # otherwise. The worker's only clause required an "organisation_id" key, so
  # the nightly job raised FunctionClauseError, burned all 3 attempts and died
  # — while the crontab-membership test above still passed.
  test "the job the cron actually enqueues (empty args) runs instead of crashing" do
    assert :ok = GscSyncWorker.perform(%Oban.Job{args: %{}})
  end

  test "an explicit organisation_id is still honoured" do
    assert :ok =
             GscSyncWorker.perform(%Oban.Job{args: %{"organisation_id" => Ecto.UUID.generate()}})
  end
end
