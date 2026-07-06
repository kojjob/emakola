defmodule Emakola.Notifications.Announcement do
  @moduledoc """
  A platform→merchant broadcast: shown to merchants as a dismissible in-app
  banner and optionally pushed over email / SMS / WhatsApp.

  Platform-owned (NOT tenant-scoped). Created by platform staff; merchants only
  read it (banner) and dismiss it. "Active for a store" is DERIVED from status +
  the publish/expiry window + audience, so no expiry job is needed.

  Distinct from `Emakola.Notifications.Notification` (the per-user notification
  bell): this is a broadcast, not a per-recipient row.
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("announcements")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 200)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :severity, :atom do
      allow_nil?(false)
      default(:info)
      constraints(one_of: [:info, :warning, :critical])
      public?(true)
    end

    attribute :channels, {:array, :atom} do
      allow_nil?(false)
      constraints(min_length: 1, items: [one_of: [:banner, :email, :sms, :whatsapp]])
      public?(true)
    end

    attribute :audience, :atom do
      allow_nil?(false)
      default(:all)
      constraints(one_of: [:all, :active])
      public?(true)
    end

    attribute :publish_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:scheduled)
      constraints(one_of: [:scheduled, :published, :canceled])
      public?(true)
    end

    timestamps()
  end

  policies do
    # Reads run with authorize?: false (banner hook, workers, platform admin).
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # All writes are platform-only — callable solely via authorize?: false from
    # the gated platform admin / workers.
    policy action_type([:create, :update]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:title, :body, :severity, :channels, :audience, :publish_at, :expires_at])
    end

    update :publish do
      accept([])
      change(set_attribute(:status, :published))
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :canceled))
    end

    # Derived "active for a viewing store": published, inside the publish/expiry
    # window at `as_of`, and either audience :all or (audience :active and the
    # viewing store is live). `as_of` is passed in (testable; no `now()`).
    read :active_for_store do
      argument(:store_live, :boolean, allow_nil?: false)
      argument(:as_of, :utc_datetime_usec, allow_nil?: false)

      filter(
        expr(
          status == :published and
            publish_at <= ^arg(:as_of) and
            (is_nil(expires_at) or expires_at > ^arg(:as_of)) and
            (audience == :all or (audience == :active and ^arg(:store_live)))
        )
      )

      prepare(build(sort: [publish_at: :desc]))
    end

    read :list_for_admin do
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
