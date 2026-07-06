defmodule Emakola.Content.RateLimiterTest do
  # async: true is safe — every test uses a unique store_id, so the shared ETS
  # counter never collides across tests.
  use ExUnit.Case, async: true

  alias Emakola.Content.RateLimiter

  defp store_id, do: "store-#{System.unique_integer([:positive])}"

  test "allows up to the limit, then rejects" do
    store = store_id()

    for _ <- 1..3 do
      assert RateLimiter.check_and_increment(store, 3) == :ok
    end

    assert RateLimiter.check_and_increment(store, 3) == {:error, :rate_limit_exceeded}
  end

  test "usage/1 reports the running count" do
    store = store_id()
    assert RateLimiter.usage(store) == 0

    RateLimiter.check_and_increment(store, 50)
    RateLimiter.check_and_increment(store, 50)

    assert RateLimiter.usage(store) == 2
  end

  test "stores have independent daily budgets" do
    a = store_id()
    b = store_id()

    assert RateLimiter.check_and_increment(a, 1) == :ok
    assert RateLimiter.check_and_increment(a, 1) == {:error, :rate_limit_exceeded}

    assert RateLimiter.check_and_increment(b, 1) == :ok
  end

  test "default_limit/0 reads the configured cap" do
    assert RateLimiter.default_limit() == 50
  end
end
