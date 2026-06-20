defmodule Emakola.OAuthConfig do
  @moduledoc """
  Reads social-login (OAuth) credentials from application config
  (`config :emakola, :oauth, ...` and `:oauth_redirect_base`) for use as
  AshAuthentication strategy secrets.

  Returns `{:ok, value}` / `:error` to match the secret-fn contract (the same
  shape as `Application.fetch_env/2`), so a missing credential leaves the
  strategy inert rather than crashing — keeping unconfigured providers
  ship-dark. See `EmakolaWeb.OAuth` for the display/enabled side.
  """

  @doc "Fetch a provider credential, e.g. `fetch(:google, :client_id)`."
  @spec fetch(atom(), atom()) :: {:ok, String.t()} | :error
  def fetch(provider, key) do
    Application.get_env(:emakola, :oauth, [])
    |> Keyword.get(provider, %{})
    |> Map.get(key)
    |> ok_or_error()
  end

  @doc "The OAuth redirect base URI, e.g. `https://makola.io/oauth`."
  @spec redirect_uri() :: {:ok, String.t()} | :error
  def redirect_uri do
    Application.get_env(:emakola, :oauth_redirect_base) |> ok_or_error()
  end

  defp ok_or_error(value) when is_binary(value) and value != "", do: {:ok, value}
  defp ok_or_error(_), do: :error
end
