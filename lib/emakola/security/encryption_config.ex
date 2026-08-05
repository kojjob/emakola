defmodule Emakola.Security.EncryptionConfig do
  @moduledoc """
  Validated keyrings for application-level field encryption and blind indexes.

  Key material is deliberately omitted from `Inspect` output. Production keys
  come from runtime configuration; callers may pass an explicit config to the
  crypto functions for tests and rotation tooling.
  """

  @derive {Inspect, only: [:active_key_id, :blind_index_active_key_id]}
  @enforce_keys [:active_key_id, :keys, :blind_index_active_key_id, :blind_index_keys]
  defstruct [:active_key_id, :keys, :blind_index_active_key_id, :blind_index_keys]

  @type key_id :: String.t()
  @type keyring :: %{required(key_id()) => binary()}
  @type t :: %__MODULE__{
          active_key_id: key_id(),
          keys: keyring(),
          blind_index_active_key_id: key_id(),
          blind_index_keys: keyring()
        }

  @key_bytes 32
  @key_id_pattern ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/

  @doc "Loads and validates the configured encryption keyrings."
  @spec load(keyword() | map() | nil) :: {:ok, t()} | {:error, atom()}
  def load(config \\ Application.get_env(:emakola, Emakola.Security.FieldEncryption))

  def load(config) when is_list(config) do
    if Keyword.keyword?(config), do: load(Map.new(config)), else: {:error, :invalid_configuration}
  end

  def load(config) when is_map(config) do
    with {:ok, active_key_id} <- fetch_key_id(config, :active_key_id),
         {:ok, keys} <- fetch_keyring(config, :keys),
         :ok <- ensure_active_key(keys, active_key_id),
         {:ok, blind_key_id} <- fetch_key_id(config, :blind_index_active_key_id),
         {:ok, blind_keys} <- fetch_keyring(config, :blind_index_keys),
         :ok <- ensure_active_key(blind_keys, blind_key_id),
         :ok <- ensure_separate_key_material(keys, blind_keys) do
      {:ok,
       %__MODULE__{
         active_key_id: active_key_id,
         keys: keys,
         blind_index_active_key_id: blind_key_id,
         blind_index_keys: blind_keys
       }}
    end
  end

  def load(_config), do: {:error, :missing_configuration}

  defp fetch_key_id(config, field) do
    case Map.get(config, field) do
      key_id when is_binary(key_id) ->
        if Regex.match?(@key_id_pattern, key_id),
          do: {:ok, key_id},
          else: {:error, :invalid_key_id}

      _ ->
        {:error, :invalid_key_id}
    end
  end

  defp fetch_keyring(config, field) do
    case Map.get(config, field) do
      keyring when is_map(keyring) and map_size(keyring) > 0 -> validate_keyring(keyring)
      _ -> {:error, :invalid_keyring}
    end
  end

  defp validate_keyring(keyring) do
    Enum.reduce_while(keyring, {:ok, %{}}, fn
      {key_id, key}, {:ok, valid} when is_binary(key_id) and is_binary(key) ->
        cond do
          not Regex.match?(@key_id_pattern, key_id) ->
            {:halt, {:error, :invalid_key_id}}

          byte_size(key) != @key_bytes ->
            {:halt, {:error, :invalid_key_length}}

          true ->
            {:cont, {:ok, Map.put(valid, key_id, key)}}
        end

      _, _acc ->
        {:halt, {:error, :invalid_keyring}}
    end)
  end

  defp ensure_active_key(keys, key_id) do
    if Map.has_key?(keys, key_id), do: :ok, else: {:error, :active_key_not_found}
  end

  defp ensure_separate_key_material(keys, blind_keys) do
    encryption_values = keys |> Map.values() |> MapSet.new()
    blind_values = blind_keys |> Map.values() |> MapSet.new()

    if MapSet.disjoint?(encryption_values, blind_values),
      do: :ok,
      else: {:error, :key_reuse_not_allowed}
  end
end
