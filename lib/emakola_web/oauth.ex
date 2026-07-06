defmodule EmakolaWeb.OAuth do
  @moduledoc """
  Ship-dark registry of social-login providers.

  A provider's button and OAuth routes activate only when its credentials are
  fully configured (`config :emakola, :oauth, ...`, sourced from env in
  `runtime.exs`/`dev.exs`). Until then the provider is invisible and inert — so
  this feature can deploy before any credentials exist and light up
  per-provider as secrets are added (Apple last, since it needs a paid account).

  This module is the single source of truth for "which providers are on"; the
  login/register buttons and the strategy/route wiring all gate on it.
  """

  @providers [:google, :facebook, :apple]

  @doc "Every provider the app knows how to offer, in display order — configured or not."
  @spec providers() :: [atom()]
  def providers, do: @providers

  @doc "Providers whose credentials are fully configured, in display order."
  @spec enabled_providers() :: [atom()]
  def enabled_providers do
    config = Application.get_env(:emakola, :oauth, [])
    Enum.filter(@providers, fn provider -> configured?(provider, config[provider] || %{}) end)
  end

  @doc "Whether a single provider's credentials are fully configured."
  @spec enabled?(atom()) :: boolean()
  def enabled?(provider), do: provider in enabled_providers()

  # Apple authenticates with a signing key (.p8) rather than a client secret.
  defp configured?(:apple, creds) do
    present?(creds[:client_id]) and present?(creds[:team_id]) and
      present?(creds[:private_key_id]) and present?(creds[:private_key_path])
  end

  defp configured?(_provider, creds) do
    present?(creds[:client_id]) and present?(creds[:client_secret])
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
