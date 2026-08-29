defmodule Emakola.Notifications.Notification do
  @moduledoc """
  One thing worth telling one person, waiting in their bell.

  `recipient_kind` + `recipient_id` rather than three nullable foreign keys:
  the recipient is a merchant, a customer, or Makola staff, and those live in
  three different tables. Same shape as
  `Emakola.Conversations.Message.author_kind`/`author_id`, which already
  solves this problem here. The kind is a small fixed set, so a wrong value
  cannot be written even though the id carries no database constraint.

  Distinct from `Emakola.Notifications.Announcement`, which is one row
  broadcast at every merchant. This is one row per recipient, and it is read.
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("notifications")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Commerce events, not the SaaS template's vocabulary this table arrived
    # with. Anything added here also needs an icon and colour in
    # `EmakolaWeb.LayoutHelpers`, or the bell renders it blank.
    attribute :type, :atom do
      constraints(
        one_of: [
          :order_placed,
          :order_status_changed,
          :payment_received,
          :payout_sent,
          :new_message,
          :verification_result,
          :product_moderated,
          :supplier_connection,
          :supplier_overdue,
          :announcement,
          :billing_warning,
          :system
        ]
      )

      allow_nil?(false)
      public?(true)
    end

    attribute :recipient_kind, :atom do
      constraints(one_of: [:user, :merchant, :customer])
      allow_nil?(false)
      public?(true)
    end

    attribute :recipient_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute(:body, :string, public?: true, constraints: [max_length: 5_000])

    attribute(:read_at, :utc_datetime, public?: true)

    attribute(:action_url, :string, public?: true, constraints: [max_length: 2_048])

    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :notify do
      accept([:type, :recipient_kind, :recipient_id, :title, :body, :action_url, :metadata])
    end

    update :mark_read do
      accept([])
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end

    read :for_recipient do
      argument(:recipient_kind, :atom, allow_nil?: false)
      argument(:recipient_id, :uuid, allow_nil?: false)

      filter(
        expr(recipient_kind == ^arg(:recipient_kind) and recipient_id == ^arg(:recipient_id))
      )

      prepare(build(sort: [inserted_at: :desc], limit: 20))
    end

    read :unread_for_recipient do
      argument(:recipient_kind, :atom, allow_nil?: false)
      argument(:recipient_id, :uuid, allow_nil?: false)

      filter(
        expr(
          recipient_kind == ^arg(:recipient_kind) and recipient_id == ^arg(:recipient_id) and
            is_nil(read_at)
        )
      )
    end

    # Bulk rather than a per-record update the caller loops over: clearing a
    # bell should be one statement, not one per unread row.
    update :mark_all_read do
      accept([])
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end
  end
end
