defmodule Emakola.RateLimit do
  @moduledoc """
  Rate limiter backed by Hammer ETS.

  Provides `check_rate/3` to verify rate limit counters.
  Must be added to the application supervision tree.
  """

  use Hammer, backend: :ets

  @doc """
  Check if a request should be allowed.

  Returns `{:allow, count}` or `{:deny, retry_after_ms}`.
  """
  def check_rate(id, limit, window_ms) do
    hit(id, window_ms, limit)
  end
end
