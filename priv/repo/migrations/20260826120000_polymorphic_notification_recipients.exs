defmodule Emakola.Repo.Migrations.PolymorphicNotificationRecipients do
  @moduledoc """
  Lets a merchant or a customer own a notification, not just platform staff.

  The table arrived from a SaaS template (its create migration is still named
  `FounderPad.Repo.Migrations.CreateNotifications`) with `user_id` referencing
  `users` — platform staff. Merchants live in `merchants` and customers in
  `customers`, so neither could own a row. The bell that renders these rows
  is in the merchant layout, which meant the one actor who could be notified
  could not see it and the one actor who could see it could not be notified.

  `recipient_kind` + `recipient_id` rather than three nullable foreign keys,
  matching `Emakola.Conversations.Message.author_kind`/`author_id`, which
  already solves exactly this three-table problem in this codebase. The id is
  deliberately unconstrained: no single FK can point at three tables, and the
  kind is a small fixed set so a wrong value cannot be written.

  `user_id` is dropped in this same migration rather than left nullable for a
  release. Its only production writer (`Billing.Workers.StripeHandler`) and
  its only reader (`Hooks.AssignDefaults`) are both rewritten in the same
  commit, so there is no window where deployed code reads a column that is
  gone. Leaving the column would also leave the `null: false` FK, which is
  what blocked merchants in the first place.

  Hand-written, like every recent migration here: 38 resources have no
  committed snapshot, so `mix ash.codegen` emits `create table` for the whole
  schema.
  """

  use Ecto.Migration

  # Everything the resource's `type` constraint accepts after this migration.
  @types ~w(
    order_placed order_status_changed payment_received payout_sent new_message
    verification_result product_moderated supplier_connection announcement
    billing_warning system
  )

  def up do
    alter table(:notifications) do
      add(:recipient_kind, :text)
      add(:recipient_id, :uuid)
    end

    # Every existing row belongs to platform staff by definition — the column
    # it came from could not hold anything else.
    execute("UPDATE notifications SET recipient_kind = 'user', recipient_id = user_id")

    # The old vocabulary was the template's (:agent_completed, :team_invite,
    # :system_announcement…). Only :billing_warning survives into the commerce
    # set, so anything else becomes :system rather than being left as a value
    # the resource would refuse to write.
    execute("""
    UPDATE notifications SET type = 'system'
    WHERE type NOT IN (#{Enum.map_join(@types, ",", &"'#{&1}'")})
    """)

    alter table(:notifications) do
      modify(:recipient_kind, :text, null: false)
      modify(:recipient_id, :uuid, null: false)
    end

    drop(constraint(:notifications, "notifications_user_id_fkey"))

    alter table(:notifications) do
      remove(:user_id)
    end

    # Matches how the bell reads: this recipient's rows, newest first.
    create(
      index(:notifications, [:recipient_kind, :recipient_id, "inserted_at DESC"],
        name: "notifications_recipient_index"
      )
    )
  end

  def down do
    drop(
      index(:notifications, [:recipient_kind, :recipient_id],
        name: "notifications_recipient_index"
      )
    )

    alter table(:notifications) do
      add(
        :user_id,
        references(:users, column: :id, name: "notifications_user_id_fkey", type: :uuid)
      )
    end

    # Only staff rows can go back — a merchant's or customer's recipient_id has
    # no row in `users` and would violate the foreign key.
    execute("DELETE FROM notifications WHERE recipient_kind <> 'user'")
    execute("UPDATE notifications SET user_id = recipient_id")

    alter table(:notifications) do
      modify(:user_id, :uuid, null: false)
      remove(:recipient_kind)
      remove(:recipient_id)
    end
  end
end
