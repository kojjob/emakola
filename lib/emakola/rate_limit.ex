defmodule Emakola.RateLimit do
  @moduledoc """
  Rate limiter backed by Hammer ETS.

  Provides `check_rate/3` to verify rate limit counters.
  """

  @doc """
  Check if a request should be allowed.

  Returns `{:allow, count}` or `{:deny, limit}`.
  """
  def check_rate(id, limit, window_ms) do
    case Hammer.check_rate(id, window_ms, limit) do
      {:allow, count} -> {:allow, count}
      {:deny, limit} -> {:deny, limit}
    end
  end
end
