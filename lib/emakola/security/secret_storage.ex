defmodule Emakola.Security.SecretStorage do
  @moduledoc """
  Dual-read accessors for sensitive fields during the expand/backfill rollout.

  Encrypted shadows are authenticated before use. During the rolling-deploy
  expand phase, an authenticated-but-stale shadow may disagree with a write
  made by an old node; in that case the still-authoritative compatibility
  column wins until the post-rollout reconciliation task catches it up. A
  shadow that fails authentication never downgrades to plaintext.
  """

  alias Emakola.Security.FieldEncryption

  @totp_context "users.totp_secret"
  @webhook_context "outbound_webhooks.secret"
  @device_context "device_tokens.token"

  @spec user_totp_secret(map()) :: {:ok, binary() | nil} | {:error, FieldEncryption.error()}
  def user_totp_secret(user) do
    read_shadow(user, :totp_secret_encrypted, :totp_secret, @totp_context)
  end

  @spec outbound_webhook_secret(map()) ::
          {:ok, binary() | nil} | {:error, FieldEncryption.error()}
  def outbound_webhook_secret(webhook) do
    read_shadow(webhook, :secret_encrypted, :secret, @webhook_context)
  end

  @spec device_token(map()) :: {:ok, binary() | nil} | {:error, FieldEncryption.error()}
  def device_token(device_token) do
    read_shadow(device_token, :token_encrypted, :token, @device_context)
  end

  @spec totp_configured?(map()) :: boolean()
  def totp_configured?(user) do
    case Map.get(user, :totp_secret) do
      %Ash.NotLoaded{} -> loaded_binary?(Map.get(user, :totp_secret_encrypted))
      nil -> false
      value when is_binary(value) -> true
      _other -> loaded_binary?(Map.get(user, :totp_secret_encrypted))
    end
  end

  defp read_shadow(record, encrypted_field, legacy_field, context) do
    encrypted = Map.get(record, encrypted_field)
    legacy = Map.get(record, legacy_field)
    record_id = Map.get(record, :id)

    cond do
      loaded_binary?(encrypted) and is_binary(record_id) ->
        decrypt_and_reconcile(encrypted, legacy, encrypted_context(context, record_id))

      loaded_binary?(encrypted) ->
        {:error, :invalid_context}

      is_nil(encrypted) or not_loaded?(encrypted) ->
        {:ok, legacy_value(legacy)}

      true ->
        {:error, :invalid_envelope}
    end
  end

  defp decrypt_and_reconcile(encrypted, legacy, context) do
    case FieldEncryption.decrypt(encrypted, context) do
      {:ok, decrypted} -> {:ok, compatibility_value(decrypted, legacy)}
      {:error, reason} -> {:error, reason}
    end
  end

  # The compatibility column remains authoritative only for the expand phase.
  # This mismatch path is what lets an old node rotate/clear a secret while new
  # nodes are joining the cluster. The contract release removes this branch
  # together with the plaintext columns.
  defp compatibility_value(decrypted, %Ash.NotLoaded{}), do: decrypted
  defp compatibility_value(decrypted, legacy) when legacy == decrypted, do: decrypted

  defp compatibility_value(_decrypted, legacy) when is_binary(legacy) or is_nil(legacy),
    do: legacy

  defp compatibility_value(decrypted, _legacy), do: decrypted

  defp encrypted_context(context, record_id), do: "#{context}:#{record_id}"

  defp loaded_binary?(value), do: is_binary(value)
  defp not_loaded?(%Ash.NotLoaded{}), do: true
  defp not_loaded?(_value), do: false

  defp legacy_value(%Ash.NotLoaded{}), do: nil
  defp legacy_value(value), do: value
end
