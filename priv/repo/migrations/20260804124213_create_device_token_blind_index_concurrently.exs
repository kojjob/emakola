defmodule Emakola.Repo.Migrations.CreateDeviceTokenBlindIndexConcurrently do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists(
      index(:device_tokens, [:token_blind_index],
        name: :device_tokens_token_blind_index_index,
        concurrently: true
      )
    )
  end
end
