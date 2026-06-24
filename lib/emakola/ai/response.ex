defmodule Emakola.AI.Response do
  @moduledoc """
  A provider-agnostic LLM response.

  `text` is the first text block, trimmed. `parsed` is the decoded JSON object
  when the request asked for `response_format: :json` (nil otherwise, or when the
  model's output couldn't be parsed). `usage` carries the token counts the
  provider reported — the basis for cost tracking (`Emakola.AI.Pricing`).
  """

  @type usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          cache_read: non_neg_integer(),
          cache_creation: non_neg_integer()
        }

  @type t :: %__MODULE__{
          text: String.t() | nil,
          parsed: map() | nil,
          model: String.t() | nil,
          usage: usage(),
          raw: map() | nil
        }

  defstruct text: nil,
            parsed: nil,
            model: nil,
            usage: %{input_tokens: 0, output_tokens: 0, cache_read: 0, cache_creation: 0},
            raw: nil
end
