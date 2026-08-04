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
end
