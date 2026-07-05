defmodule Emakola.AI.Provider do
  @moduledoc """
  Behaviour for an LLM provider — the swap point for the AI suite.

  One generic, mode-agnostic callback (`complete/1`) carries text, chat, vision,
  and structured-JSON requests alike, so a second provider plugs in with no caller
  changes. The active implementation is configured via `:ai_provider`
  (`Emakola.AI.Providers.Anthropic` in prod, a Mox mock in test), mirroring the
  `Emakola.Payments.Gateway` / `Notifications.*Provider` pattern.

  Ships dark: with no API key the implementation returns `{:error, :not_configured}`.
  """

  @callback complete(Emakola.AI.Request.t()) ::
              {:ok, Emakola.AI.Response.t()} | {:error, term()}
end
