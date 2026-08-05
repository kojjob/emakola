defmodule EmakolaWeb.AiGate do
  @moduledoc """
  Whether AI content generation is switched on for this deployment (an
  `ANTHROPIC_API_KEY` is configured). Shared by every AI-gated admin surface
  (SEO dashboard, snap-to-shop entry) so there is one definition of "on".
  """

  @doc "True when an Anthropic API key is configured."
  @spec enabled?() :: boolean()
  def enabled?, do: not is_nil(Application.get_env(:emakola, :anthropic_api_key))
end
