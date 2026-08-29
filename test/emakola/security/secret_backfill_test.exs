defmodule Emakola.Security.SecretBackfillTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.User
  alias Emakola.Notifications.DeviceToken
  alias Emakola.Security.EncryptionConfig
  alias Emakola.Security.FieldEncryption
  alias Emakola.Security.SecretBackfill
  alias Emakola.Security.SecretStorage
  alias Emakola.Webhooks.OutboundWebhook

  test "bounded backfill protects legacy rows and rotation converges" do
    secret = TOTP.generate_secret()

    user =
      create_user!()
      |> Ash.Changeset.for_update(:setup_totp, %{
        secret: secret,
        code: NimbleTOTP.verification_code(secret)
      })
      |> Ash.update!(authorize?: false)

    organisation = create_organisation!()

    webhook =
      OutboundWebhook
      |> Ash.Changeset.for_create(:create, %{
        url: "https://example.com/security-backfill",
        secret: "whsec_legacy",
        events: [],
        organisation_id: organisation.id
      })
      |> Ash.create!(authorize?: false)

    {merchant, store} = create_merchant_with_store!()

    device_token =
      DeviceToken
      |> Ash.Changeset.for_create(
        :register,
        %{platform: :android, token: "fcm-legacy-token"},
        actor: merchant,
        tenant: store.id
      )
      |> Ash.create!()

    Emakola.Repo.query!(
      "UPDATE users SET totp_secret_encrypted = NULL WHERE id = $1::text::uuid",
      [user.id]
    )

    Emakola.Repo.query!(
      "UPDATE outbound_webhooks SET secret_encrypted = NULL WHERE id = $1::text::uuid",
      [webhook.id]
    )

    Emakola.Repo.query!(
      "UPDATE device_tokens SET token_encrypted = NULL, token_blind_index = NULL " <>
        "WHERE id = $1::text::uuid",
      [device_token.id]
    )

    assert %{"device_tokens" => 1, "outbound_webhooks" => 1, "users" => 1} =
             Emakola.Release.backfill_field_encryption(1)

    user = Ash.get!(User, user.id, authorize?: false)
    webhook = Ash.get!(OutboundWebhook, webhook.id, authorize?: false)

    device_token =
      Ash.get!(DeviceToken, device_token.id, authorize?: false, tenant: store.id)

    assert FieldEncryption.encrypted?(user.totp_secret_encrypted)
    assert FieldEncryption.encrypted?(webhook.secret_encrypted)
    assert FieldEncryption.encrypted?(device_token.token_encrypted)
    assert String.starts_with?(device_token.token_blind_index, "emkidx.v1.test-lookup-v1.")

    assert {:ok, ^secret} = SecretStorage.user_totp_secret(user)
    assert {:ok, "whsec_legacy"} = SecretStorage.outbound_webhook_secret(webhook)
    assert {:ok, "fcm-legacy-token"} = SecretStorage.device_token(device_token)

    assert {:ok, ^secret} =
             SecretStorage.user_totp_secret(%{user | totp_secret_encrypted: nil})

    # A still-running old node can change the compatibility column without
    # knowing about the shadow. New nodes remain behaviorally safe during the
    # rollout, then the bounded reconciliation catches the shadow up.
    Emakola.Repo.query!(
      "UPDATE outbound_webhooks SET secret = 'rotated-by-old-node' " <>
        "WHERE id = $1::text::uuid",
      [webhook.id]
    )

    stale_webhook = Ash.get!(OutboundWebhook, webhook.id, authorize?: false)

    assert {:ok, "rotated-by-old-node"} =
             SecretStorage.outbound_webhook_secret(stale_webhook)

    assert %{"device_tokens" => 0, "outbound_webhooks" => 1, "users" => 0} =
             SecretBackfill.reconcile!(Emakola.Repo, batch_size: 1)

    assert %{"device_tokens" => 0, "outbound_webhooks" => 0, "users" => 0} =
             SecretBackfill.reconcile!(Emakola.Repo, batch_size: 1)

    assert {:error, _reason} =
             SecretStorage.user_totp_secret(%{
               user
               | totp_secret_encrypted: user.totp_secret_encrypted <> "tampered"
             })

    rotated_config = rotated_config()

    assert %{"device_tokens" => 1, "outbound_webhooks" => 1, "users" => 1} =
             SecretBackfill.rotate!(Emakola.Repo,
               batch_size: 1,
               config: rotated_config
             )

    assert %{"device_tokens" => 0, "outbound_webhooks" => 0, "users" => 0} =
             SecretBackfill.rotate!(Emakola.Repo,
               batch_size: 1,
               config: rotated_config
             )

    rotated_user = Ash.get!(User, user.id, authorize?: false)
    assert String.starts_with?(rotated_user.totp_secret_encrypted, "emkenc.v1.test-v2.")

    assert {:ok, ^secret} =
             FieldEncryption.decrypt(
               rotated_user.totp_secret_encrypted,
               "users.totp_secret:#{rotated_user.id}",
               config: rotated_config
             )
  end

  test "reconciliation refuses to erase unauthenticated ciphertext when plaintext is null" do
    secret = TOTP.generate_secret()

    user =
      create_user!()
      |> Ash.Changeset.for_update(:setup_totp, %{
        secret: secret,
        code: NimbleTOTP.verification_code(secret)
      })
      |> Ash.update!(authorize?: false)

    tampered = user.totp_secret_encrypted <> "tampered"

    Emakola.Repo.query!(
      "UPDATE users SET totp_secret = NULL, totp_secret_encrypted = $1 " <>
        "WHERE id = $2::text::uuid",
      [tampered, user.id]
    )

    assert_raise RuntimeError, ~r/failed to protect users\.totp_secret during backfill/, fn ->
      SecretBackfill.reconcile!(Emakola.Repo, batch_size: 1)
    end

    reloaded = Ash.get!(User, user.id, authorize?: false)
    assert reloaded.totp_secret_encrypted == tampered
  end

  test "rotation compare-and-swap preserves a concurrent secret update" do
    original_secret = TOTP.generate_secret()

    user =
      create_user!()
      |> Ash.Changeset.for_update(:setup_totp, %{
        secret: original_secret,
        code: NimbleTOTP.verification_code(original_secret)
      })
      |> Ash.update!(authorize?: false)

    rotated_config = rotated_config()
    concurrent_secret = TOTP.generate_secret()

    assert {:ok, concurrent_encrypted} =
             FieldEncryption.encrypt(
               concurrent_secret,
               "users.totp_secret:#{user.id}",
               config: rotated_config
             )

    before_compare_and_swap = fn table, id, operation ->
      if table == "users" and id == user.id and operation == :rotate and
           Process.get(:field_encryption_race_written?) != true do
        Process.put(:field_encryption_race_written?, true)

        Emakola.Repo.query!(
          "UPDATE users SET totp_secret = $1, totp_secret_encrypted = $2 " <>
            "WHERE id = $3::text::uuid",
          [concurrent_secret, concurrent_encrypted, user.id]
        )
      end
    end

    assert %{"users" => 0} =
             SecretBackfill.rotate!(Emakola.Repo,
               batch_size: 1,
               config: rotated_config,
               before_compare_and_swap: before_compare_and_swap
             )

    reloaded = Ash.get!(User, user.id, authorize?: false)
    assert reloaded.totp_secret == concurrent_secret
    assert reloaded.totp_secret_encrypted == concurrent_encrypted

    assert {:ok, ^concurrent_secret} =
             FieldEncryption.decrypt(
               reloaded.totp_secret_encrypted,
               "users.totp_secret:#{user.id}",
               config: rotated_config
             )
  end

  test "rotation refuses to rewrap a stale encrypted shadow" do
    original_secret = TOTP.generate_secret()

    user =
      create_user!()
      |> Ash.Changeset.for_update(:setup_totp, %{
        secret: original_secret,
        code: NimbleTOTP.verification_code(original_secret)
      })
      |> Ash.update!(authorize?: false)

    stale_encrypted = user.totp_secret_encrypted
    replacement_secret = TOTP.generate_secret()

    Emakola.Repo.query!(
      "UPDATE users SET totp_secret = $1 WHERE id = $2::text::uuid",
      [replacement_secret, user.id]
    )

    assert_raise RuntimeError, ~r/encrypted shadow does not match.*reconcile first/, fn ->
      SecretBackfill.rotate!(Emakola.Repo, batch_size: 1, config: rotated_config())
    end

    reloaded = Ash.get!(User, user.id, authorize?: false)
    assert reloaded.totp_secret == replacement_secret
    assert reloaded.totp_secret_encrypted == stale_encrypted
  end

  defp rotated_config do
    assert {:ok, config} =
             EncryptionConfig.load(%{
               active_key_id: "test-v2",
               keys: %{
                 "test-v1" => "0123456789abcdef0123456789abcdef",
                 "test-v2" => "aaaaaaaa11111111bbbbbbbb22222222"
               },
               blind_index_active_key_id: "test-lookup-v2",
               blind_index_keys: %{
                 "test-lookup-v1" => "fedcba9876543210fedcba9876543210",
                 "test-lookup-v2" => "cccccccc33333333dddddddd44444444"
               }
             })

    config
  end
end
