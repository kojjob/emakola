defmodule Emakola.Metrics do
  @moduledoc """
  Low-overhead application counters used by the Prometheus exporter.

  The telemetry callback writes directly to an ETS table, avoiding a
  GenServer call on every HTTP response. Labels are deliberately bounded to
  status classes so request paths, tenant ids, and other high-cardinality or
  sensitive values never enter the metrics stream.
  """

  use GenServer

  @table :emakola_metrics
  @handler_id "emakola-prometheus-http"
  @status_classes ~w(1xx 2xx 3xx 4xx 5xx unknown)

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the current HTTP counters as a map."
  @spec snapshot() :: map()
  def snapshot do
    counts = Map.new(@status_classes, &{&1, counter({:http_requests, &1})})

    %{
      http_requests: counts,
      http_duration_microseconds: counter(:http_duration_microseconds),
      http_duration_count: counter(:http_duration_count)
    }
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :telemetry.detach(@handler_id)

    :ok =
      :telemetry.attach(
        @handler_id,
        [:phoenix, :endpoint, :stop],
        &__MODULE__.handle_http_stop/4,
        nil
      )

    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach(@handler_id)
    :ok
  end

  @doc false
  def handle_http_stop(_event, measurements, metadata, _config) do
    status_class = metadata |> status() |> status_class()
    duration = Map.get(measurements, :duration, 0)
    duration_us = System.convert_time_unit(duration, :native, :microsecond)

    increment({:http_requests, status_class}, 1)
    increment(:http_duration_microseconds, duration_us)
    increment(:http_duration_count, 1)
  end

  defp status(%{conn: %{status: status}}), do: status
  defp status(_metadata), do: nil

  defp status_class(status) when status in 100..599, do: "#{div(status, 100)}xx"
  defp status_class(_status), do: "unknown"

  defp increment(key, amount) do
    :ets.update_counter(@table, key, {2, amount}, {key, 0})
  rescue
    ArgumentError -> 0
  end

  defp counter(key) do
    :ets.lookup_element(@table, key, 2)
  rescue
    ArgumentError -> 0
  end
end
