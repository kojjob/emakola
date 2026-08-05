defmodule Emakola.Security.SecretBackfill do
  @moduledoc """
  Bounded, idempotent backfill for encrypted secret shadow columns.

  This module intentionally uses a small fixed target list and parameterized
  values. It runs after the schema-only expand migrations through release-safe
  operational entrypoints, without loading secret values into logs.
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
    before_write = before_compare_and_swap!(opts)

    Map.new(@targets, fn target ->
      {target.table, backfill_target(repo, target, config, before_write, batch_size, 0)}
    end)
  end

  @doc "Re-encrypts shadow values and blind indexes with the configured active keys."
  @spec rotate!(module(), keyword()) :: %{required(String.t()) => non_neg_integer()}
  def rotate!(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    validate_batch_size!(batch_size)
    config = load_config!(opts)
    before_write = before_compare_and_swap!(opts)

    Map.new(@targets, fn target ->
      {target.table, rotate_target(repo, target, config, before_write, batch_size, 0)}
    end)
  end

  @doc "Reconciles shadows after old nodes have drained from a rolling deploy."
  @spec reconcile!(module(), keyword()) :: %{required(String.t()) => non_neg_integer()}
  def reconcile!(repo, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    validate_batch_size!(batch_size)
    config = load_config!(opts)
    before_write = before_compare_and_swap!(opts)

    Map.new(@targets, fn target ->
      {target.table, reconcile_target(repo, target, config, before_write, batch_size, nil, 0)}
    end)
  end

  defp backfill_target(repo, target, config, before_write, batch_size, count) do
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
        updated =
          Enum.count(rows, fn row ->
            state = row_state(row)

            protect_row!(
              repo,
              target,
              state,
              state.plaintext,
              config,
              before_write,
              :backfill
            )
          end)

        backfill_target(repo, target, config, before_write, batch_size, count + updated)
    end
  end

  defp rotate_target(repo, target, config, before_write, batch_size, count) do
    {sql, params} = rotation_batch_query(target, config, batch_size)
    result = repo.query!(sql, params, log: false)

    case result.rows do
      [] ->
        count

      rows ->
        updated =
          Enum.count(rows, &rotate_row!(repo, target, &1, config, before_write))

        rotate_target(repo, target, config, before_write, batch_size, count + updated)
    end
  end

  defp reconcile_target(repo, target, config, before_write, batch_size, last_id, count) do
    result = repo.query!(reconcile_batch_sql(target), [batch_size, last_id], log: false)

    case result.rows do
      [] ->
        count

      rows ->
        updated =
          Enum.count(rows, &reconcile_row!(repo, target, &1, config, before_write, 3))

        next_id = rows |> List.last() |> hd()

        reconcile_target(
          repo,
          target,
          config,
          before_write,
          batch_size,
          next_id,
          count + updated
        )
    end
  end

  # A five-state machine over {plaintext, encrypted, blind_index}. The branch
  # conditions are named rather than inlined so each state reads as what it
  # means, and so the dispatch stays under the complexity gate — the states are
  # irreducible, the predicates are not.
  defp nothing_to_reconcile?(state),
    do: is_nil(state.plaintext) and is_nil(state.encrypted) and is_nil(state.blind_index)

  defp already_encrypted?(state), do: is_nil(state.plaintext) and is_binary(state.encrypted)

  defp orphaned_blind_index?(state), do: is_nil(state.plaintext) and is_nil(state.encrypted)

  defp reconcile_row!(repo, target, row, config, before_write, attempts_left) do
    state = row_state(row)

    cond do
      nothing_to_reconcile?(state) ->
        false

      already_encrypted?(state) ->
        case FieldEncryption.decrypt(
               state.encrypted,
               encrypted_context(target, state.id),
               config: config
             ) do
          {:ok, _plaintext} ->
            reconcile_compare_and_swap(
              repo,
              target,
              state,
              config,
              before_write,
              attempts_left,
              fn -> clear_protected_row!(repo, target, state, before_write) end
            )

          {:error, reason} ->
            raise_backfill_error!(target, reason)
        end

      orphaned_blind_index?(state) ->
        # A blind index cannot be authenticated without its source plaintext.
        # With both the compatibility value and ciphertext absent there is no
        # secret to preserve, so remove the orphaned lookup value.
        reconcile_compare_and_swap(
          repo,
          target,
          state,
          config,
          before_write,
          attempts_left,
          fn -> clear_protected_row!(repo, target, state, before_write) end
        )

      is_binary(state.plaintext) and
          reconciliation_needed?(
            target,
            state.id,
            state.plaintext,
            state.encrypted,
            state.blind_index,
            config
          ) ->
        reconcile_compare_and_swap(
          repo,
          target,
          state,
          config,
          before_write,
          attempts_left,
          fn ->
            protect_row!(
              repo,
              target,
              state,
              state.plaintext,
              config,
              before_write,
              :reconcile
            )
          end
        )

      true ->
        false
    end
  end

  defp reconcile_compare_and_swap(
         repo,
         target,
         state,
         config,
         before_write,
         attempts_left,
         operation
       ) do
    if operation.() do
      true
    else
      retry_reconcile!(repo, target, state.id, config, before_write, attempts_left - 1)
    end
  end

  defp retry_reconcile!(_repo, target, id, _config, _before_write, 0) do
    raise "concurrent writes prevented reconciliation of #{target.table} row #{id}; retry the operation"
  end

  defp retry_reconcile!(repo, target, id, config, before_write, attempts_left) do
    case repo.query!(select_row_sql(target), [id], log: false).rows do
      [] -> false
      [row] -> reconcile_row!(repo, target, row, config, before_write, attempts_left)
    end
  end

  defp rotate_row!(repo, target, row, config, before_write) do
    state = row_state(row)

    case FieldEncryption.decrypt(
           state.encrypted,
           encrypted_context(target, state.id),
           config: config
         ) do
      {:ok, plaintext} when plaintext == state.plaintext ->
        protect_row!(repo, target, state, plaintext, config, before_write, :rotate)

      {:ok, _stale_plaintext} ->
        raise "refusing key rotation for #{target.table} row #{state.id}: " <>
                "encrypted shadow does not match the compatibility value; reconcile first"

      {:error, reason} ->
        raise_backfill_error!(target, reason)
    end
  end

  defp protect_row!(repo, target, state, plaintext, config, before_write, operation) do
    crypto_opts = [config: config]

    encrypted =
      case FieldEncryption.encrypt(
             plaintext,
             encrypted_context(target, state.id),
             crypto_opts
           ) do
        {:ok, encrypted} -> encrypted
        {:error, reason} -> raise_backfill_error!(target, reason)
      end

    before_write.(target.table, state.id, operation)

    if blind_index_column = target[:blind_index] do
      blind_index =
        case FieldEncryption.blind_index(plaintext, target.context, crypto_opts) do
          {:ok, blind_index} -> blind_index
          {:error, reason} -> raise_backfill_error!(target, reason)
        end

      result =
        repo.query!(
          "UPDATE #{target.table} SET #{target.encrypted} = $1, #{blind_index_column} = $2 " <>
            "WHERE id = $3::text::uuid " <>
            "AND #{target.plaintext} IS NOT DISTINCT FROM $4 " <>
            "AND #{target.encrypted} IS NOT DISTINCT FROM $5 " <>
            "AND #{blind_index_column} IS NOT DISTINCT FROM $6",
          [
            encrypted,
            blind_index,
            state.id,
            state.plaintext,
            state.encrypted,
            state.blind_index
          ],
          log: false
        )

      result.num_rows == 1
    else
      result =
        repo.query!(
          "UPDATE #{target.table} SET #{target.encrypted} = $1 WHERE id = $2::text::uuid " <>
            "AND #{target.plaintext} IS NOT DISTINCT FROM $3 " <>
            "AND #{target.encrypted} IS NOT DISTINCT FROM $4",
          [encrypted, state.id, state.plaintext, state.encrypted],
          log: false
        )

      result.num_rows == 1
    end
  end

  defp clear_protected_row!(repo, target, state, before_write) do
    before_write.(target.table, state.id, :reconcile_clear)

    if blind_index_column = target[:blind_index] do
      result =
        repo.query!(
          "UPDATE #{target.table} SET #{target.encrypted} = NULL, #{blind_index_column} = NULL " <>
            "WHERE id = $1::text::uuid " <>
            "AND #{target.plaintext} IS NOT DISTINCT FROM $2 " <>
            "AND #{target.encrypted} IS NOT DISTINCT FROM $3 " <>
            "AND #{blind_index_column} IS NOT DISTINCT FROM $4",
          [state.id, state.plaintext, state.encrypted, state.blind_index],
          log: false
        )

      result.num_rows == 1
    else
      result =
        repo.query!(
          "UPDATE #{target.table} SET #{target.encrypted} = NULL WHERE id = $1::text::uuid " <>
            "AND #{target.plaintext} IS NOT DISTINCT FROM $2 " <>
            "AND #{target.encrypted} IS NOT DISTINCT FROM $3",
          [state.id, state.plaintext, state.encrypted],
          log: false
        )

      result.num_rows == 1
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

    "SELECT #{selected_columns(target)} FROM #{target.table} " <>
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
        "SELECT #{selected_columns(target)} FROM #{target.table} " <>
          "WHERE #{target.encrypted} IS NOT NULL AND " <>
          "(#{encrypted_needs_rotation} OR #{blind_needs_rotation}) " <>
          "ORDER BY id LIMIT $3"

      {sql, [config.active_key_id, config.blind_index_active_key_id, batch_size]}
    else
      sql =
        "SELECT #{selected_columns(target)} FROM #{target.table} " <>
          "WHERE #{target.encrypted} IS NOT NULL AND #{encrypted_needs_rotation} " <>
          "ORDER BY id LIMIT $2"

      {sql, [config.active_key_id, batch_size]}
    end
  end

  defp reconcile_batch_sql(target) do
    "SELECT #{selected_columns(target)} FROM #{target.table} " <>
      "WHERE ($2::text IS NULL OR id > $2::text::uuid) ORDER BY id LIMIT $1"
  end

  defp select_row_sql(target) do
    "SELECT #{selected_columns(target)} FROM #{target.table} WHERE id = $1::text::uuid"
  end

  defp selected_columns(target) do
    if blind_index_column = target[:blind_index],
      do: "id::text, #{target.plaintext}, #{target.encrypted}, #{blind_index_column}",
      else: "id::text, #{target.plaintext}, #{target.encrypted}"
  end

  defp row_state([id, plaintext, encrypted]) do
    %{id: id, plaintext: plaintext, encrypted: encrypted, blind_index: nil}
  end

  defp row_state([id, plaintext, encrypted, blind_index]) do
    %{id: id, plaintext: plaintext, encrypted: encrypted, blind_index: blind_index}
  end

  defp validate_batch_size!(batch_size) do
    unless is_integer(batch_size) and batch_size > 0 do
      raise ArgumentError, "backfill batch_size must be a positive integer"
    end
  end

  defp before_compare_and_swap!(opts) do
    callback = Keyword.get(opts, :before_compare_and_swap, fn _table, _id, _operation -> :ok end)

    if is_function(callback, 3) do
      callback
    else
      raise ArgumentError, "before_compare_and_swap must be a function with arity 3"
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

  @spec raise_backfill_error!(map(), term()) :: no_return()
  defp raise_backfill_error!(target, reason) do
    raise "failed to protect #{target.table}.#{target.plaintext} during backfill: #{reason}"
  end
end
