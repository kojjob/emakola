defmodule Emakola.Accounts.ApiTokens do
  @moduledoc """
  Issues, rotates, and revokes bearer token pairs for the mobile/JSON API.

  Access tokens are standard AshAuthentication user tokens (purpose `"user"`,
  15 minutes) so `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3`
  validates them with presence + revocation checks against the tokens table.

  Refresh tokens carry purpose `"emakola_api_refresh"` (30 days) and are
  rotated on every exchange: the presented token's jti is revoked (upserted
  to purpose `"revocation"`) before a new pair is issued, so replay fails.
  """

  require Logger

  alias AshAuthentication.{Jwt, TokenResource.Actions}
  alias Emakola.Accounts.{Merchant, Token}

  @refresh_purpose "emakola_api_refresh"
  @refresh_purpose_atom :emakola_api_refresh
  @access_lifetime {15, :minutes}
  @refresh_lifetime {30, :days}
  @access_lifetime_seconds 15 * 60

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
          | {:error, :token_generation_failed}
  def exchange_refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, %{"purpose" => @refresh_purpose, "jti" => jti, "sub" => subject}, Merchant} <-
           Jwt.verify(refresh_token, :emakola),
         {:ok, [_live_record]} <-
           Actions.get_token(Token, %{"jti" => jti, "purpose" => @refresh_purpose}),
         {:ok, merchant} <- AshAuthentication.subject_to_user(subject, Merchant) do
      # Wrap revoke + issue atomically so a failed issue_pair cannot burn the
      # refresh token without producing a new one.
      #
      # An exclusive advisory lock on the jti hash serialises concurrent
      # exchanges of the same token at the DB level (production multi-connection
      # scenario). The re-check after lock acquisition also guards the race
      # window between the outer get_token call above and the transaction:
      # whoever runs second inside the transaction will see the token already
      # gone and abort rather than double-issuing.
      Emakola.Repo.transaction(fn ->
        Ecto.Adapters.SQL.query!(
          Emakola.Repo,
          "SELECT pg_advisory_xact_lock(hashtext($1))",
          [jti]
        )

        case Actions.get_token(Token, %{"jti" => jti, "purpose" => @refresh_purpose}) do
          {:ok, [_]} ->
            with :ok <- Actions.revoke(Token, refresh_token),
                 {:ok, pair} <- issue_pair(merchant) do
              {:ok, pair}
            else
              {:error, :token_generation_failed} = err -> Emakola.Repo.rollback(err)
              _ -> Emakola.Repo.rollback(:exchange_failed)
            end

          _ ->
            Emakola.Repo.rollback(:already_redeemed)
        end
      end)
      |> case do
        {:ok, {:ok, pair}} -> {:ok, pair}
        {:error, {:error, :token_generation_failed}} -> {:error, :token_generation_failed}
        _ -> {:error, :invalid_refresh_token}
      end
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  @spec revoke(String.t()) :: :ok
  def revoke(token) when is_binary(token) do
    case Actions.revoke(Token, token) do
      :ok ->
        :ok

      {:error, reason} ->
        # Token may be invalid, expired, already revoked, or a transient DB error.
        # The caller is discarding credentials; there is nothing left to protect.
        Logger.warning("ApiTokens.revoke/1 silenced an error: #{inspect(reason)}")
        :ok
    end
  end
end
