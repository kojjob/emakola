defmodule Emakola.Repo.Migrations.AddEncryptedSecretShadows do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :totp_secret_encrypted, :text
    end

    alter table(:outbound_webhooks) do
      add :secret_encrypted, :text
    end

    alter table(:device_tokens) do
      add :token_encrypted, :text
      add :token_blind_index, :text
    end

    execute(fn -> Emakola.Security.SecretBackfill.run!(repo()) end)

    create index(:device_tokens, [:token_blind_index],
             name: :device_tokens_token_blind_index_index
           )
  end

  def down do
    drop_if_exists index(:device_tokens, [:token_blind_index],
                     name: :device_tokens_token_blind_index_index
                   )

    alter table(:device_tokens) do
      remove :token_blind_index
      remove :token_encrypted
    end

    alter table(:outbound_webhooks) do
      remove :secret_encrypted
    end

    alter table(:users) do
      remove :totp_secret_encrypted
    end
  end
end
