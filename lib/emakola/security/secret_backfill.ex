defmodule Emakola.Security.SecretBackfill do
  @moduledoc """
  Bounded, idempotent backfill for encrypted secret shadow columns.

  This module intentionally uses a small fixed target list and parameterized
  values. It is called by the expand migration and may also be invoked by
  operational verification tooling without loading secret values into logs.
  """

  alias Emakola.Security.EncryptionConfig
  alias Emakola.Security.FieldEncryption

  @default_batch_size 500

  @targets [
    %{
      table: "users",
      plaintext: "totp_secret",
      encrypted: "totp_secret_encrypted",
      context: "users.totp_secret"
    },
    %{
      table: "outbound_webhooks",
      plaintext: "secret",
      encrypted: "secret_encrypted",
      context: "outbound_webhooks.secret"
    },
    %{
      table: "device_tokens",
      plaintext: "token",
      encrypted: "token_encrypted",
      blind_index: "token_blind_index",
      context: "device_tokens.token"
    }
  ]

  @spec run!(module(), keyword()) :: %{required(String.t()) => non_neg_integer()}
  def run!(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    validate_batch_size!(batch_size)
    config = load_config!(opts)

    Map.new(@targets, fn target ->
      {target.table, backfill_target(repo, target, config, batch_size, 0)}
    end)
  end

  @doc "Re-encrypts shadow values and blind indexes with the configured active keys."
  @spec rotate!(module(), keyword()) :: %{required(String.t()) => non_neg_integer()}
  def rotate!(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    validate_batch_size!(batch_size)
    config = load_config!(opts)

    Map.new(@targets, fn target ->
      {target.table, rotate_target(repo, target, config, batch_size, 0)}
    end)
  end

  @doc "Reconciles shadows after old nodes have drained from a rolling deploy."
  @spec reconcile!(module(), keyword()) :: %{required(String.t()) => non_neg_integer()}
  def reconcile!(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    validate_batch_size!(batch_size)
    config = load_config!(opts)

    Map.new(@targets, fn target ->
      {target.table, reconcile_target(repo, target, config, batch_size, 0, 0)}
    end)
  end

  defp backfill_target(repo, target, config, batch_size, count) do
    result =
      repo.query!(
        select_batch_sql(target),
        [batch_size],
        log: false
      )

    case result.rows do
      [] ->
        count

      rows ->
        Enum.each(rows, &protect_row!(repo, target, &1, config))
        backfill_target(repo, target, config, batch_size, count + length(rows))
    end
  end

  defp rotate_target(repo, target, config, batch_size, count) do
    {sql, params} = rotation_batch_query(target, config, batch_size)
    result = repo.query!(sql, params, log: false)

    case result.rows do
      [] ->
        count

      rows ->
        Enum.each(rows, &rotate_row!(repo, target, &1, config))
        rotate_target(repo, target, config, batch_size, count + length(rows))
    end
  end

  defp reconcile_target(repo, target, config, batch_size, offset, count) do
    result = repo.query!(reconcile_batch_sql(target), [batch_size, offset], log: false)

    case result.rows do
      [] ->
        count

      rows ->
        updated = Enum.count(rows, &reconcile_row!(repo, target, &1, config))
        reconcile_target(repo, target, config, batch_size, offset + length(rows), count + updated)
    end
  end

  defp reconcile_row!(repo, target, [id, plaintext, encrypted], config) do
    reconcile_row!(repo, target, [id, plaintext, encrypted, nil], config)
  end

  defp reconcile_row!(repo, target, [id, nil, encrypted, blind_index], _config) do
    if is_nil(encrypted) and is_nil(blind_index) do
      false
    else
      clear_protected_row!(repo, target, id)
      true
    end
  end

  defp reconcile_row!(repo, target, [id, plaintext, encrypted, blind_index], config)
       when is_binary(plaintext) do
    if reconciliation_needed?(target, id, plaintext, encrypted, blind_index, config) do
      protect_row!(repo, target, [id, plaintext], config)
      true
    else
      false
    end
  end

  defp reconcile_row!(_repo, _target, _row, _config), do: false

  defp rotate_row!(repo, target, [id, encrypted], config) do
    case FieldEncryption.decrypt(encrypted, encrypted_context(target, id), config: config) do
      {:ok, plaintext} -> protect_row!(repo, target, [id, plaintext], config)
      {:error, reason} -> raise_backfill_error!(target, reason)
    end
  end

  defp protect_row!(repo, target, [id, plaintext], config) do
    crypto_opts = [config: config]

    encrypted =
      case FieldEncryption.encrypt(plaintext, encrypted_context(target, id), crypto_opts) do
        {:ok, encrypted} -> encrypted
        {:error, reason} -> raise_backfill_error!(target, reason)
      end

    if blind_index_column = target[:blind_index] do
      blind_index =
        case FieldEncryption.blind_index(plaintext, target.context, crypto_opts) do
          {:ok, blind_index} -> blind_index
          {:error, reason} -> raise_backfill_error!(target, reason)
        end

      repo.query!(
        "UPDATE #{target.table} SET #{target.encrypted} = $1, #{blind_index_column} = $2 " <>
          "WHERE id = $3::text::uuid",
        [encrypted, blind_index, id],
        log: false
      )
    else
      repo.query!(
        "UPDATE #{target.table} SET #{target.encrypted} = $1 WHERE id = $2::text::uuid",
        [encrypted, id],
        log: false
      )
    end
  end

  defp clear_protected_row!(repo, target, id) do
    if blind_index_column = target[:blind_index] do
      repo.query!(
        "UPDATE #{target.table} SET #{target.encrypted} = NULL, #{blind_index_column} = NULL " <>
          "WHERE id = $1::text::uuid",
        [id],
        log: false
      )
    else
      repo.query!(
        "UPDATE #{target.table} SET #{target.encrypted} = NULL WHERE id = $1::text::uuid",
        [id],
        log: false
      )
    end
  end

  defp reconciliation_needed?(target, id, plaintext, encrypted, blind_index, config) do
    encrypted_mismatch? =
      case encrypted do
        nil ->
          true

        encrypted when is_binary(encrypted) ->
          case FieldEncryption.decrypt(encrypted, encrypted_context(target, id), config: config) do
            {:ok, decrypted} -> decrypted != plaintext
            {:error, reason} -> raise_backfill_error!(target, reason)
          end

        _other ->
          true
      end

    encrypted_mismatch? or blind_index_mismatch?(target, plaintext, blind_index, config)
  end

  defp blind_index_mismatch?(target, plaintext, blind_index, config) do
    if target[:blind_index] do
      case FieldEncryption.blind_index(plaintext, target.context, config: config) do
        {:ok, expected} -> expected != blind_index
        {:error, reason} -> raise_backfill_error!(target, reason)
      end
    else
      false
    end
  end

  defp select_batch_sql(target) do
    missing =
      if blind_index_column = target[:blind_index],
        do: "(#{target.encrypted} IS NULL OR #{blind_index_column} IS NULL)",
        else: "#{target.encrypted} IS NULL"

    "SELECT id::text, #{target.plaintext} FROM #{target.table} " <>
      "WHERE #{target.plaintext} IS NOT NULL AND #{missing} ORDER BY id LIMIT $1"
  end

  defp rotation_batch_query(target, config, batch_size) do
    encrypted_needs_rotation =
      "(split_part(#{target.encrypted}, '.', 1) <> 'emkenc' OR " <>
        "split_part(#{target.encrypted}, '.', 2) <> 'v1' OR " <>
        "split_part(#{target.encrypted}, '.', 3) <> $1)"

    if blind_index_column = target[:blind_index] do
      blind_needs_rotation =
        "(#{blind_index_column} IS NULL OR " <>
          "split_part(#{blind_index_column}, '.', 1) <> 'emkidx' OR " <>
          "split_part(#{blind_index_column}, '.', 2) <> 'v1' OR " <>
          "split_part(#{blind_index_column}, '.', 3) <> $2)"

      sql =
        "SELECT id::text, #{target.encrypted} FROM #{target.table} " <>
          "WHERE #{target.encrypted} IS NOT NULL AND " <>
          "(#{encrypted_needs_rotation} OR #{blind_needs_rotation}) " <>
          "ORDER BY id LIMIT $3"

      {sql, [config.active_key_id, config.blind_index_active_key_id, batch_size]}
    else
      sql =
        "SELECT id::text, #{target.encrypted} FROM #{target.table} " <>
          "WHERE #{target.encrypted} IS NOT NULL AND #{encrypted_needs_rotation} " <>
          "ORDER BY id LIMIT $2"

      {sql, [config.active_key_id, batch_size]}
    end
  end

  defp reconcile_batch_sql(target) do
    columns =
      if blind_index_column = target[:blind_index],
        do: "id::text, #{target.plaintext}, #{target.encrypted}, #{blind_index_column}",
        else: "id::text, #{target.plaintext}, #{target.encrypted}"

    "SELECT #{columns} FROM #{target.table} ORDER BY id LIMIT $1 OFFSET $2"
  end

  defp validate_batch_size!(batch_size) do
    unless is_integer(batch_size) and batch_size > 0 do
      raise ArgumentError, "backfill batch_size must be a positive integer"
    end
  end

  defp load_config!(opts) do
    configured_keyring =
      case Keyword.fetch(opts, :config) do
        {:ok, config} -> EncryptionConfig.load(config)
        :error -> EncryptionConfig.load()
      end

    case configured_keyring do
      {:ok, config} -> config
      {:error, reason} -> raise "field encryption configuration is invalid: #{reason}"
    end
  end

  defp encrypted_context(target, record_id), do: "#{target.context}:#{record_id}"

  defp raise_backfill_error!(target, reason) do
    raise "failed to protect #{target.table}.#{target.plaintext} during backfill: #{reason}"
  end
end
