defmodule Emakola.AI.PricingTest do
  use ExUnit.Case, async: true

  alias Emakola.AI.Pricing

  # Rates are configured globally in config/config.exs (:ai_model_pricing).
  # Haiku is $1/$5 per MTok → 1 / 5 micro-USD per token.

  test "computes cost in micro-USD from input/output tokens at the model's rates" do
    usage = %{input_tokens: 1000, output_tokens: 200, cache_read: 0, cache_creation: 0}
    # 1000 * 1 + 200 * 5 = 2000 micro-USD
    assert Pricing.cost_microusd("claude-haiku-4-5", usage) == 2000
  end

  test "sonnet costs more per token than haiku for identical usage" do
    usage = %{input_tokens: 1000, output_tokens: 1000}
    haiku = Pricing.cost_microusd("claude-haiku-4-5", usage)
    sonnet = Pricing.cost_microusd("claude-sonnet-4-6", usage)
    assert sonnet > haiku
  end

  test "unknown or nil model costs 0 (still recorded for visibility)" do
    usage = %{input_tokens: 1000, output_tokens: 1000}
    assert Pricing.cost_microusd("not-a-model", usage) == 0
    assert Pricing.cost_microusd(nil, usage) == 0
  end

  test "missing token keys default to 0" do
    assert Pricing.cost_microusd("claude-haiku-4-5", %{}) == 0
  end
end
