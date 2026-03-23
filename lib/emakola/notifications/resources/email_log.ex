defmodule Emakola.Notifications.EmailLog do
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("email_logs")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :to, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 320)
    end

    attribute :subject, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 500)
    end

    attribute :template, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :sent, :failed, :bounced])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute(:error, :string, public?: true, constraints: [max_length: 5_000])
    attribute(:metadata, :map, default: %{}, public?: true)
    attribute(:sent_at, :utc_datetime, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :user, Emakola.Accounts.User do
      allow_nil?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:to, :subject, :template, :status, :error, :metadata, :sent_at])
      argument(:user_id, :uuid, allow_nil?: true)
      change(manage_relationship(:user_id, :user, type: :append))
    end

    update :mark_sent do
      accept([])
      change(set_attribute(:status, :sent))
      change(set_attribute(:sent_at, &DateTime.utc_now/0))
    end

    update :mark_failed do
      accept([:error])
      change(set_attribute(:status, :failed))
    end
  end
end
