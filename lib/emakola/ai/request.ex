defmodule Emakola.AI.Request do
  @moduledoc """
  A single, provider- and mode-agnostic LLM request.

  Content is carried as `messages` whose `content` is either a plain string
  (text task) or a list of content blocks (`%{type: :text, ...}` /
  `%{type: :image, url: ...}` for vision) — so text, chat, and vision tasks
  all use the same shape. `response_format: :json` asks the provider to return
  a decoded JSON object in `Emakola.AI.Response.parsed`. `thinking: :disabled`
  opts a request out of model-side reasoning — set it on models that think by
  default (Sonnet 5+), where thinking tokens bill against `max_tokens` and an
  unbounded think could truncate the output. The provider translates this
  neutral struct into its own wire format.

  Built by `Emakola.AI.Prompts.build/2`; dispatched by `Emakola.AI.generate/3`.
  """

  @type content_block ::
          %{type: :text, text: String.t()}
          | %{type: :image, url: String.t()}

  @type message :: %{role: :user | :assistant, content: String.t() | [content_block()]}

  @type t :: %__MODULE__{
          model: String.t() | nil,
          system: String.t() | nil,
          messages: [message()],
          max_tokens: pos_integer(),
          response_format: nil | :json,
          thinking: nil | :disabled,
          feature: atom() | nil,
          store_id: String.t() | nil,
          actor_id: String.t() | nil,
          metadata: map()
        }

  defstruct model: nil,
            system: nil,
            messages: [],
            max_tokens: 1024,
            response_format: nil,
            thinking: nil,
            feature: nil,
            store_id: nil,
            actor_id: nil,
            metadata: %{}
end
