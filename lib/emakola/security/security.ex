defmodule Emakola.Security do
  @moduledoc """
  Security domain — the abuse/security event log and its aggregates.

  `record/1` is fire-and-forget (never raises) so instrumentation can't break a
  request or login. `overview/1` rolls the last 24h into the abuse-monitor view
  (counts by type, top-source ranking, anomaly flags).
  """
  use Ash.Domain

  require Ash.Query
  require Logger

  alias Emakola.Security.SecurityEvent

  @window_hours 24
  @anomaly_threshold 10

  resources do
    resource SecurityEvent do
      define(:recent_security_events, action: :recent)
    end
  end

  @doc """
  Records a security event. Never raises — a logging failure must never break the
  request or login being instrumented. Returns `{:ok, event}` or `{:error, _}`.
  """
  def record(attrs) when is_map(attrs) do
    SecurityEvent
    |> Ash.Changeset.for_create(:record, attrs)
    |> Ash.create(authorize?: false)
  rescue
    exception ->
      Logger.error("[Security] record/1 raised: #{Exception.message(exception)}")
      {:error, :record_failed}
  end

  @doc """
  Rolls the trailing #{@window_hours}h (ending at `as_of`) into the abuse-monitor
  overview: total, counts by type, top source IPs / identifiers (with anomaly
  flags), the recent stream, and a total anomaly count.
  """
  def overview(%DateTime{} = as_of) do
    since = DateTime.add(as_of, -@window_hours * 3600, :second)
    events = events_between(since, as_of)

    %{
      total: length(events),
      by_type: %{
        rate_limit_exceeded: Enum.count(events, &(&1.event_type == :rate_limit_exceeded)),
        auth_failed: Enum.count(events, &(&1.event_type == :auth_failed))
      },
      top_ips: top_counts(events, & &1.ip, :ip),
      top_identifiers: top_counts(events, & &1.identifier, :identifier),
      recent: events |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime}) |> Enum.take(50),
      anomaly_count: flagged_count(events, & &1.ip) + flagged_count(events, & &1.identifier)
    }
  end

  defp events_between(since, as_of) do
    SecurityEvent
    |> Ash.Query.filter(inserted_at >= ^since and inserted_at <= ^as_of)
    |> Ash.read!(authorize?: false)
  end

  defp top_counts(events, key_fun, key) do
    events
    |> Enum.map(key_fun)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_value, count} -> -count end)
    |> Enum.take(10)
    |> Enum.map(fn {value, count} ->
      %{key => value, :count => count, :flagged => count >= @anomaly_threshold}
    end)
  end

  defp flagged_count(events, key_fun) do
    events
    |> Enum.map(key_fun)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.count(fn {_value, count} -> count >= @anomaly_threshold end)
  end
end
