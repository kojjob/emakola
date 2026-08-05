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
  end

  def down do
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
