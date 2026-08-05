defmodule Emakola.Metrics.Prometheus do
  @moduledoc """
  Renders a small, dependency-free Prometheus text exposition.

  Metrics intentionally use bounded operational labels only. Store, merchant,
  customer, request-path, and payload data are never exported.
  """

  import Ecto.Query

  alias Emakola.Repo

  @incomplete_job_states ~w(available scheduled executing retryable)

  @doc "Returns the current application metrics in Prometheus 0.0.4 format."
  @spec render() :: String.t()
  def render do
    {database_up, oban_lines} = database_metrics()

    [
      gauge("emakola_up", "Whether the application process is running", 1),
      gauge("emakola_database_up", "Whether the primary database is reachable", database_up),
      vm_metrics(),
      http_metrics(),
      oban_lines
    ]
    |> List.flatten()
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp vm_metrics do
    memory_lines =
      for {kind, bytes} <- :erlang.memory() do
        "emakola_vm_memory_bytes{kind=\"#{kind}\"} #{bytes}"
      end

    [
      "# HELP emakola_vm_memory_bytes BEAM memory usage by category",
      "# TYPE emakola_vm_memory_bytes gauge",
      memory_lines,
      gauge(
        "emakola_vm_process_count",
        "Current number of BEAM processes",
        system_info(:process_count)
      ),
      gauge(
        "emakola_vm_process_limit",
        "Maximum number of BEAM processes",
        system_info(:process_limit)
      ),
      gauge(
        "emakola_vm_run_queue",
        "Current BEAM scheduler run queue",
        :erlang.statistics(:run_queue)
      ),
      gauge(
        "emakola_cluster_nodes",
        "Number of connected application nodes including this node",
        length(Node.list()) + 1
      )
    ]
  end

  defp http_metrics do
    snapshot = Emakola.Metrics.snapshot()

    request_lines =
      for {status_class, count} <- snapshot.http_requests do
        "emakola_http_requests_total{status_class=\"#{status_class}\"} #{count}"
      end

    [
      "# HELP emakola_http_requests_total Completed Phoenix endpoint requests",
      "# TYPE emakola_http_requests_total counter",
      request_lines,
      counter(
        "emakola_http_request_duration_seconds_sum",
        "Cumulative Phoenix endpoint request duration in seconds",
        snapshot.http_duration_microseconds / 1_000_000
      ),
      counter(
        "emakola_http_request_duration_seconds_count",
        "Number of requests included in the duration metric",
        snapshot.http_duration_count
      )
    ]
  end

  defp database_metrics do
    with {:ok, _result} <- Repo.query("SELECT 1"),
         jobs <- oban_job_counts() do
      {1, oban_metrics(1, jobs)}
    else
      _error -> {0, oban_metrics(0, [])}
    end
  rescue
    _error -> {0, oban_metrics(0, [])}
  catch
    :exit, _reason -> {0, oban_metrics(0, [])}
  end

  defp oban_job_counts do
    Oban.Job
    |> where([job], job.state in ^@incomplete_job_states)
    |> group_by([job], [job.queue, job.state])
    |> select([job], {job.queue, job.state, count(job.id)})
    |> Repo.all()
  end

  defp oban_metrics(up, jobs) do
    job_lines =
      Enum.map(jobs, fn {queue, state, count} ->
        "emakola_oban_jobs{queue=\"#{label(queue)}\",state=\"#{label(state)}\"} #{count}"
      end)

    [
      gauge("emakola_oban_metrics_up", "Whether Oban job metrics could be queried", up),
      "# HELP emakola_oban_jobs Incomplete Oban jobs by queue and state",
      "# TYPE emakola_oban_jobs gauge",
      job_lines
    ]
  end

  defp label(value) do
    value
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_.:-]/u, "_")
  end

  defp system_info(key), do: :erlang.system_info(key)

  defp gauge(name, help, value), do: metric(name, help, "gauge", value)
  defp counter(name, help, value), do: metric(name, help, "counter", value)

  defp metric(name, help, type, value) do
    ["# HELP #{name} #{help}", "# TYPE #{name} #{type}", "#{name} #{value}"]
  end
end
