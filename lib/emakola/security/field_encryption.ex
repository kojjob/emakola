defmodule Emakola.Security.FieldEncryption do
  @moduledoc """
  Versioned AES-256-GCM field encryption with keyed HMAC blind indexes.

  Ciphertexts embed their format version and key id, allowing new writes to use
  the active key while old keys remain available for reads during rotation. The
  caller-supplied field and record context is authenticated as additional data,
  preventing a valid value from being copied into a different protected column
  or row.
  """

  alias Emakola.Security.EncryptionConfig

  @cipher :aes_256_gcm
  @version "v1"
  @envelope_prefix "emkenc"
  @blind_index_prefix "emkidx"
  @nonce_bytes 12
  @tag_bytes 16

  @type error ::
          :active_key_not_found
          | :authentication_failed
          | :invalid_configuration
          | :invalid_context
          | :invalid_envelope
          | :invalid_key_id
          | :invalid_key_length
          | :invalid_keyring
          | :invalid_plaintext
          | :key_reuse_not_allowed
          | :missing_configuration
          | :not_encrypted
          | :unknown_key_id
          | :unsupported_version

  @doc "Encrypts a binary into a versioned, authenticated envelope."
  @spec encrypt(binary(), String.t(), keyword()) :: {:ok, String.t()} | {:error, error()}
  def encrypt(plaintext, context, opts \\ [])

  def encrypt(plaintext, context, opts) when is_binary(plaintext) and is_binary(context) do
    with :ok <- validate_context(context),
         {:ok, config} <- resolve_config(opts),
         {:ok, key} <- fetch_active_key(config) do
      nonce = :crypto.strong_rand_bytes(@nonce_bytes)
      aad = authenticated_context(config.active_key_id, context)

      {ciphertext, tag} =
        :crypto.crypto_one_time_aead(
          @cipher,
          key,
          nonce,
          plaintext,
          aad,
          @tag_bytes,
          true
        )

      {:ok,
       Enum.join(
         [
           @envelope_prefix,
           @version,
           config.active_key_id,
           encode(nonce),
           encode(ciphertext),
           encode(tag)
         ],
         "."
       )}
    end
  end

  def encrypt(_plaintext, _context, _opts), do: {:error, :invalid_plaintext}

  @doc "Decrypts a versioned envelope and verifies its authentication tag."
  @spec decrypt(String.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, error()}
  def decrypt(envelope, context, opts \\ [])

  def decrypt(envelope, context, opts) when is_binary(envelope) and is_binary(context) do
    with :ok <- validate_context(context),
         {:ok, config} <- resolve_config(opts),
         {:ok, key_id, nonce, ciphertext, tag} <- parse_envelope(envelope),
         {:ok, key} <- fetch_decryption_key(config, key_id) do
      case :crypto.crypto_one_time_aead(
             @cipher,
             key,
             nonce,
             ciphertext,
             authenticated_context(key_id, context),
             tag,
             false
           ) do
        :error -> {:error, :authentication_failed}
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
      end
    end
  end

  def decrypt(_envelope, _context, _opts), do: {:error, :invalid_envelope}

  @doc "Reads an encrypted envelope or returns a legacy plaintext value unchanged."
  @spec decrypt_or_legacy(binary() | nil, String.t(), keyword()) ::
          {:ok, binary() | nil, :encrypted | :legacy} | {:error, error()}
  def decrypt_or_legacy(value, context, opts \\ [])

  def decrypt_or_legacy(nil, _context, _opts), do: {:ok, nil, :legacy}

  def decrypt_or_legacy(value, context, opts) when is_binary(value) do
    if encrypted?(value) do
      case decrypt(value, context, opts) do
        {:ok, plaintext} -> {:ok, plaintext, :encrypted}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, value, :legacy}
    end
  end

  def decrypt_or_legacy(_value, _context, _opts), do: {:error, :invalid_envelope}

  @doc "Builds a versioned keyed-HMAC blind index for equality lookups."
  @spec blind_index(binary(), String.t(), keyword()) :: {:ok, String.t()} | {:error, error()}
  def blind_index(plaintext, context, opts \\ [])

  def blind_index(plaintext, context, opts) when is_binary(plaintext) and is_binary(context) do
    with :ok <- validate_context(context),
         {:ok, config} <- resolve_config(opts),
         {:ok, key} <- fetch_blind_index_key(config) do
      payload =
        Enum.join(
          [@blind_index_prefix, @version, config.blind_index_active_key_id, context, plaintext],
          <<0>>
        )

      digest = :crypto.mac(:hmac, :sha256, key, payload)

      {:ok,
       Enum.join(
         [@blind_index_prefix, @version, config.blind_index_active_key_id, encode(digest)],
         "."
       )}
    end
  end

  def blind_index(_plaintext, _context, _opts), do: {:error, :invalid_plaintext}

  @doc "Returns true only for values carrying this module's envelope prefix."
  @spec encrypted?(term()) :: boolean()
  def encrypted?(value) when is_binary(value),
    do: String.starts_with?(value, @envelope_prefix <> ".")

  def encrypted?(_value), do: false

  defp resolve_config(opts) do
    case Keyword.get(opts, :config) do
      %EncryptionConfig{} = config -> {:ok, config}
      nil -> EncryptionConfig.load()
      config -> EncryptionConfig.load(config)
    end
  end

  defp fetch_active_key(config) do
    case Map.fetch(config.keys, config.active_key_id) do
      {:ok, key} -> {:ok, key}
      :error -> {:error, :active_key_not_found}
    end
  end

  defp fetch_decryption_key(config, key_id) do
    case Map.fetch(config.keys, key_id) do
      {:ok, key} -> {:ok, key}
      :error -> {:error, :unknown_key_id}
    end
  end

  defp fetch_blind_index_key(config) do
    case Map.fetch(config.blind_index_keys, config.blind_index_active_key_id) do
      {:ok, key} -> {:ok, key}
      :error -> {:error, :active_key_not_found}
    end
  end

  defp parse_envelope(envelope) do
    case String.split(envelope, ".", parts: 6) do
      [@envelope_prefix, @version, key_id, nonce64, ciphertext64, tag64] ->
        with {:ok, nonce} <- decode(nonce64),
             true <- byte_size(nonce) == @nonce_bytes,
             {:ok, ciphertext} <- decode(ciphertext64),
             {:ok, tag} <- decode(tag64),
             true <- byte_size(tag) == @tag_bytes do
          {:ok, key_id, nonce, ciphertext, tag}
        else
          _ -> {:error, :invalid_envelope}
        end

      [@envelope_prefix, _version | _rest] ->
        {:error, :unsupported_version}

      _ ->
        {:error, :not_encrypted}
    end
  end

  defp authenticated_context(key_id, context) do
    Enum.join([@envelope_prefix, @version, key_id, context], <<0>>)
  end

  defp validate_context(context) do
    if context == "" or byte_size(context) > 255,
      do: {:error, :invalid_context},
      else: :ok
  end

  defp encode(value), do: Base.url_encode64(value, padding: false)
  defp decode(value), do: Base.url_decode64(value, padding: false)
end
