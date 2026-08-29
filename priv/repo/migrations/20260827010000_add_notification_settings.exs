defmodule Emakola.Repo.Migrations.AddNotificationSettings do
  @moduledoc """
  Per-person control over which notifications reach them, and when.

  One row per owner, not one per owner-and-event. A row per event would mean
  eleven rows written the first time anyone opens the settings page, almost
  all of them recording the default. `overrides` holds only the events the
  person actually changed; everything absent falls through to the compile-time
  matrix in `Emakola.Notifications.Preferences`.

  Quiet hours are stored as a plain `:time` pair plus an integer UTC offset
  rather than an IANA zone. This project has no `tzdata` dependency, and
  neither Ghana (UTC+0) nor Nigeria (UTC+1) observes DST — adding a timezone
  database to serve two fixed offsets is a dependency bought for nothing.

  `owner_kind`/`owner_id` mirrors `notifications.recipient_kind`/`recipient_id`
  and `conversation_messages.author_kind`/`author_id`: the owner is a
  merchant, a customer, or platform staff, and those are three tables.

  Hand-written, like every recent migration here — 38 resources have no
  committed snapshot, so `mix ash.codegen` emits the whole schema.
  """

  use Ecto.Migration

  def up do
    create table(:notification_settings, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(:owner_kind, :text, null: false)
      add(:owner_id, :uuid, null: false)

      add(:overrides, :map, null: false, default: %{})

      add(:quiet_hours_start, :time)
      add(:quiet_hours_end, :time)

      add(:utc_offset_minutes, :integer, null: false, default: 0)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # Plain, not partial: this is the upsert identity, and ON CONFLICT needs an
    # index whose predicate it can match — an upsert against a partial index
    # fails with 42P10, the same trap documented in the conversations migration.
    create(
      unique_index(:notification_settings, [:owner_kind, :owner_id],
        name: "notification_settings_one_per_owner_index"
      )
    )
  end

  def down do
    drop(table(:notification_settings))
  end
end
