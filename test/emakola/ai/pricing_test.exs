defmodule Emakola.AI.PricingTest do
  use ExUnit.Case, async: true

  alias Emakola.AI.{Pricing, Prompts}

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
    sonnet = Pricing.cost_microusd("claude-sonnet-5", usage)
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

  # Tripwire against pricing drift: cost_microusd/2 prices unknown models at 0,
  # so a model migration that forgets the :ai_model_pricing entry would pass the
  # whole suite while silently recording zero spend. Add new features here.
  @features_with_minimal_inputs [
    {:product_description, %{product: %{}, store: %{}}},
    {:seo_meta, %{resource: %{}, store: %{}}},
    {:blog_post, %{topic: "t", store: %{}, type: :guide}},
    {:image_alt_text, %{image_url: "https://example.test/x.jpg"}},
    {:recipe, %{product: %{}, store: %{}}}
  ]

  test "every model used by Prompts has a positive pricing entry" do
    pricing = Application.get_env(:emakola, :ai_model_pricing)

    models =
      @features_with_minimal_inputs
      |> Enum.map(fn {feature, inputs} -> Prompts.build(feature, inputs).model end)
      |> Enum.uniq()

    for model <- models do
      assert %{input: input, output: output} = pricing[model],
             "#{model} is used by Prompts but has no :ai_model_pricing entry — " <>
               "its usage would silently cost 0"

      assert is_integer(input) and input > 0
      assert is_integer(output) and output > 0
    end
  end
end
