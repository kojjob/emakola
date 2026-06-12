defmodule Emakola.Accounts.ApiTokens do
  @moduledoc """
  Issues, rotates, and revokes bearer token pairs for the mobile/JSON API.

  Access tokens are standard AshAuthentication user tokens (purpose `"user"`,
  15 minutes) so `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3`
  validates them with presence + revocation checks against the tokens table.

  Refresh tokens carry purpose `"emakola_api_refresh"` (30 days) and are
  rotated on every exchange: the presented token's jti is revoked (upserted
  to purpose `"revoked"`) before a new pair is issued, so replay fails.
  """

  alias AshAuthentication.{Jwt, TokenResource.Actions}
  alias Emakola.Accounts.{Merchant, Token}

  @refresh_purpose "emakola_api_refresh"
  @refresh_purpose_atom :emakola_api_refresh
  @access_lifetime {15, :minutes}
  @refresh_lifetime {30, :days}
  @access_lifetime_seconds 900

  @spec issue_pair(struct()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t(), expires_in: pos_integer()}}
          | {:error, :token_generation_failed}
  def issue_pair(%Merchant{} = merchant) do
    with {:ok, access, _claims} <-
           Jwt.token_for_user(merchant, %{"purpose" => "user"}, token_lifetime: @access_lifetime),
         {:ok, refresh, _claims} <-
           Jwt.token_for_user(merchant, %{"purpose" => @refresh_purpose},
             purpose: @refresh_purpose_atom,
             token_lifetime: @refresh_lifetime
           ) do
      {:ok,
       %{
         access_token: access,
         refresh_token: refresh,
         expires_in: @access_lifetime_seconds
       }}
    else
      _ -> {:error, :token_generation_failed}
    end
  end

  @spec exchange_refresh(String.t()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t(), expires_in: pos_integer()}}
          | {:error, :invalid_refresh_token}
  def exchange_refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, %{"purpose" => @refresh_purpose, "jti" => jti, "sub" => subject}, Merchant} <-
           Jwt.verify(refresh_token, :emakola),
         {:ok, [_live_record]} <-
           Actions.get_token(Token, %{"jti" => jti, "purpose" => @refresh_purpose}),
         {:ok, merchant} <- AshAuthentication.subject_to_user(subject, Merchant),
         :ok <- Actions.revoke(Token, refresh_token),
         {:ok, pair} <- issue_pair(merchant) do
      {:ok, pair}
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  @spec revoke(String.t()) :: :ok
  def revoke(token) when is_binary(token) do
    case Actions.revoke(Token, token) do
      :ok -> :ok
      # Revoking an invalid/garbage token is a no-op success: the caller is
      # discarding credentials; there is nothing to protect.
      {:error, _} -> :ok
    end
  end
end
