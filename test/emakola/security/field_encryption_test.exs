defmodule Emakola.Security.FieldEncryptionTest do
  use ExUnit.Case, async: true

  alias Emakola.Security.EncryptionConfig
  alias Emakola.Security.FieldEncryption

  @context "test_records.secret"

  test "property-style binary roundtrips preserve arbitrary bytes" do
    inputs =
      [<<>>, <<0, 255, 1, 128>>, "Akwaaba 👋🏿"] ++
        Enum.map(0..96, &:crypto.strong_rand_bytes/1)

    Enum.each(inputs, fn plaintext ->
      assert {:ok, envelope} = FieldEncryption.encrypt(plaintext, @context, config: config())
      assert envelope != plaintext
      assert FieldEncryption.encrypted?(envelope)
      assert {:ok, ^plaintext} = FieldEncryption.decrypt(envelope, @context, config: config())
    end)
  end

  test "fresh nonces make repeated encryption non-deterministic" do
    assert {:ok, first} = FieldEncryption.encrypt("same", @context, config: config())
    assert {:ok, second} = FieldEncryption.encrypt("same", @context, config: config())
    assert first != second
  end

  test "tampering with valid base64 ciphertext fails authentication" do
    assert {:ok, envelope} = FieldEncryption.encrypt("sensitive", @context, config: config())

    [prefix, version, key_id, nonce, ciphertext64, tag] = String.split(envelope, ".")
    ciphertext = Base.url_decode64!(ciphertext64, padding: false)
    <<first, rest::binary>> = ciphertext
    tampered_ciphertext = <<Bitwise.bxor(first, 1), rest::binary>>

    tampered =
      Enum.join(
        [
          prefix,
          version,
          key_id,
          nonce,
          Base.url_encode64(tampered_ciphertext, padding: false),
          tag
        ],
        "."
      )

    assert {:error, :authentication_failed} =
             FieldEncryption.decrypt(tampered, @context, config: config())
  end

  test "wrong field context and wrong key fail authentication" do
    assert {:ok, envelope} = FieldEncryption.encrypt("sensitive", @context, config: config())

    assert {:error, :authentication_failed} =
             FieldEncryption.decrypt(envelope, "other_records.secret", config: config())

    wrong_key_config =
      build_config(
        "enc-old",
        %{"enc-old" => String.duplicate("x", 32)},
        "idx-old",
        %{"idx-old" => String.duplicate("z", 32)}
      )

    assert {:error, :authentication_failed} =
             FieldEncryption.decrypt(envelope, @context, config: wrong_key_config)
  end

  test "key ids support overlapping read keys during rotation" do
    old_config = config()

    assert {:ok, old_envelope} =
             FieldEncryption.encrypt("rotate me", @context, config: old_config)

    assert String.starts_with?(old_envelope, "emkenc.v1.enc-old.")

    rotated_config =
      build_config(
        "enc-new",
        %{
          "enc-old" => String.duplicate("a", 32),
          "enc-new" => String.duplicate("b", 32)
        },
        "idx-new",
        %{
          "idx-old" => String.duplicate("c", 32),
          "idx-new" => String.duplicate("d", 32)
        }
      )

    assert {:ok, "rotate me"} =
             FieldEncryption.decrypt(old_envelope, @context, config: rotated_config)

    assert {:ok, new_envelope} =
             FieldEncryption.encrypt("rotate me", @context, config: rotated_config)

    assert String.starts_with?(new_envelope, "emkenc.v1.enc-new.")
  end

  test "blind indexes are deterministic, scoped, versioned, and keyed separately" do
    assert {:ok, first} = FieldEncryption.blind_index("lookup", @context, config: config())
    assert {:ok, second} = FieldEncryption.blind_index("lookup", @context, config: config())

    assert first == second
    assert String.starts_with?(first, "emkidx.v1.idx-old.")

    assert {:ok, other_context} =
             FieldEncryption.blind_index("lookup", "other_records.secret", config: config())

    refute first == other_context
  end

  test "legacy reads are explicit and malformed envelopes do not downgrade" do
    assert {:ok, "legacy", :legacy} =
             FieldEncryption.decrypt_or_legacy("legacy", @context, config: config())

    assert {:ok, envelope} = FieldEncryption.encrypt("protected", @context, config: config())

    assert {:ok, "protected", :encrypted} =
             FieldEncryption.decrypt_or_legacy(envelope, @context, config: config())

    assert {:error, _reason} =
             FieldEncryption.decrypt_or_legacy("emkenc.not-valid", @context, config: config())
  end

  test "configuration failures are closed and Inspect redacts key material" do
    assert {:error, :missing_configuration} = EncryptionConfig.load(nil)

    assert {:error, :invalid_key_length} =
             EncryptionConfig.load(%{
               active_key_id: "enc",
               keys: %{"enc" => "short"},
               blind_index_active_key_id: "idx",
               blind_index_keys: %{"idx" => String.duplicate("i", 32)}
             })

    reused = String.duplicate("r", 32)

    assert {:error, :key_reuse_not_allowed} =
             EncryptionConfig.load(%{
               active_key_id: "enc",
               keys: %{"enc" => reused},
               blind_index_active_key_id: "idx",
               blind_index_keys: %{"idx" => reused}
             })

    inspected = inspect(config())
    assert inspected =~ "enc-old"
    refute inspected =~ String.duplicate("a", 32)
    refute inspected =~ String.duplicate("c", 32)
  end

  defp config do
    build_config(
      "enc-old",
      %{"enc-old" => String.duplicate("a", 32)},
      "idx-old",
      %{"idx-old" => String.duplicate("c", 32)}
    )
  end

  defp build_config(active_key_id, keys, blind_key_id, blind_keys) do
    assert {:ok, config} =
             EncryptionConfig.load(%{
               active_key_id: active_key_id,
               keys: keys,
               blind_index_active_key_id: blind_key_id,
               blind_index_keys: blind_keys
             })

    config
  end
end
