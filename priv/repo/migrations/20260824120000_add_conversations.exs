defmodule Emakola.Repo.Migrations.AddConversations do
  @moduledoc """
  In-house messaging: merchant ↔ buyer, and Makola ↔ merchant.

  Hand-written for the same reason as the campaigns migration: 38 resources
  in this repo have never had a committed snapshot, so `mix ash.codegen`
  emits `create table` for all of them.
  """

  use Ecto.Migration

  def up do
    create table(:conversation_threads, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:kind, :text, null: false)

      add(:store_id, references(:stores, column: :id, type: :uuid, on_delete: :delete_all))

      add(:customer_id, references(:customers, column: :id, type: :uuid, on_delete: :delete_all))

      add(:merchant_id, references(:merchants, column: :id, type: :uuid, on_delete: :delete_all))

      add(:last_message_at, :utc_datetime_usec)
      add(:merchant_last_read_at, :utc_datetime_usec)
      add(:counterpart_last_read_at, :utc_datetime_usec)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # Plain, NOT partial. Postgres treats NULLs as distinct in a unique index,
    # so every platform thread (store_id and customer_id both NULL) coexists
    # under the buyer index, and every shop thread (merchant_id NULL) coexists
    # under the merchant index — while real duplicates are still refused.
    #
    # Partial indexes would express the intent more literally and cannot be
    # used: ON CONFLICT needs a matching index predicate, so an upsert against
    # a partial index fails with 42P10. The upsert is what makes "open" safely
    # idempotent, so the plain index wins.
    create(
      unique_index(:conversation_threads, [:store_id, :customer_id],
        name: "conversation_threads_one_per_buyer_index"
      )
    )

    create(
      unique_index(:conversation_threads, [:merchant_id],
        name: "conversation_threads_one_per_merchant_index"
      )
    )

    create(index(:conversation_threads, [:store_id, "last_message_at DESC"]))

    create table(:conversation_messages, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)

      add(
        :thread_id,
        references(:conversation_threads, column: :id, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:author_kind, :text, null: false)
      add(:author_id, :uuid, null: false)
      add(:body, :text, null: false)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    create(index(:conversation_messages, [:thread_id, :inserted_at]))
  end

  def down do
    drop(table(:conversation_messages))
    drop(table(:conversation_threads))
  end
end
