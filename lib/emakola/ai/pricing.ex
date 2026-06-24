defmodule Emakola.AI.Pricing do
  @moduledoc """
  Converts token usage into a cost in integer **micro-USD** (millionths of a
  dollar) — money as integers, never floats (project rule).

  Prices come from the `:ai_model_pricing` config map, expressed as micro-USD
  **per token** for input and output. A model's per-MTok USD price maps directly:
  `$1.00 / 1M tokens = 1 micro-USD / token`. Prompt caching is not yet used by any
  prompt (cache tokens are 0), so only input+output are billed here; add cache
  pricing when a prompt introduces a cached prefix.
  """

  alias Emakola.AI.Response

  @doc """
  Cost in micro-USD for `usage` at `model`'s rates. Unknown models cost 0
  (logged at debug) — usage is still recorded for visibility.
  """
  @spec cost_microusd(String.t() | nil, Response.usage() | map()) :: non_neg_integer()
  def cost_microusd(model, usage) do
    case pricing(model) do
      nil ->
        0

      %{input: in_rate, output: out_rate} ->
        input = Map.get(usage, :input_tokens, 0)
        output = Map.get(usage, :output_tokens, 0)
        input * in_rate + output * out_rate
    end
  end

  defp pricing(nil), do: nil

  defp pricing(model) do
    :emakola
    |> Application.get_env(:ai_model_pricing, %{})
    |> Map.get(model)
  end
end
