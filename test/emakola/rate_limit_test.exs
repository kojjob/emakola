defmodule Emakola.RateLimitTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Emakola.RateLimit
  alias Emakola.RateLimit.Local

  test "a local hit is counted exactly once" do
    key = "distributed-local-#{System.unique_integer([:positive])}"

    assert {:allow, 1} = RateLimit.hit(key, 60_000, 10)
    assert Local.get(key, 60_000) == 1
  end

  test "the listener applies a hit received from another node" do
    key = "distributed-remote-#{System.unique_integer([:positive])}"

    send(Emakola.RateLimit.Listener, {:inc, key, 60_000, 2})
    _state = :sys.get_state(Emakola.RateLimit.Listener)

    assert Local.get(key, 60_000) == 2
  end
end
