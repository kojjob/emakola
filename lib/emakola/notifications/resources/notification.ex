defmodule Emakola.Notifications.Notification do
  @moduledoc "Notification record tracking SMS, WhatsApp, and email delivery status per recipient."
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("notifications")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      constraints(
        one_of: [
          :team_invite,
          :team_removed,
          :billing_warning,
          :billing_updated,
          :agent_completed,
          :agent_failed,
          :system_announcement
        ]
      )

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

  relationships do
    belongs_to :user, Emakola.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:type, :title, :body, :action_url, :metadata])
      argument(:user_id, :uuid, allow_nil?: false)
      change(manage_relationship(:user_id, :user, type: :append))
    end

    update :mark_read do
      accept([])
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end

    update :mark_all_read do
      accept([])
      change(set_attribute(:read_at, &DateTime.utc_now/0))
    end

    read :unread do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id) and is_nil(read_at)))
    end

    read :list_by_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
      prepare(build(sort: [inserted_at: :desc], limit: 20))
    end
  end
end
