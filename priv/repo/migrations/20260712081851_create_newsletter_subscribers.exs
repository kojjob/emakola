defmodule Emakola.Repo.Migrations.CreateNewsletterSubscribers do
  use Ecto.Migration

  def change do
    create table(:newsletter_subscribers, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :store_id,
          references(:stores, type: :uuid, on_delete: :delete_all),
          null: false

      add :email, :citext, null: false
      add :subscribed_at, :utc_datetime_usec, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:newsletter_subscribers, [:store_id, :email])
  end
end
