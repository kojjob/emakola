defmodule Emakola.MetricsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  test "records bounded HTTP status and duration counters" do
    before = Emakola.Metrics.snapshot()
    duration = System.convert_time_unit(10, :millisecond, :native)

    :telemetry.execute(
      [:phoenix, :endpoint, :stop],
      %{duration: duration},
      %{conn: %{status: 204}}
    )

    after_snapshot = Emakola.Metrics.snapshot()

    assert after_snapshot.http_requests["2xx"] == before.http_requests["2xx"] + 1

    assert after_snapshot.http_duration_microseconds >=
             before.http_duration_microseconds + 10_000

    assert after_snapshot.http_duration_count == before.http_duration_count + 1
  end
end
