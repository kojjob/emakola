defmodule Emakola.Notifications.Settings do
  @moduledoc """
  One person's notification choices.

  One row per owner, holding only what they changed. `overrides` maps an
  event type to the channels they want for it; anything absent falls through
  to the default matrix in `Emakola.Notifications.Preferences`. A row per
  event would write eleven rows the first time anyone opened the settings
  page, ten of them recording the default.

  Quiet hours are a `:time` pair read in `utc_offset_minutes`, not an IANA
  zone: there is no `tzdata` here, and the two markets this serves — Ghana at
  UTC+0 and Nigeria at UTC+1 — have no DST between them.
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("notification_settings")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :owner_kind, :atom do
      constraints(one_of: [:user, :merchant, :customer])
      allow_nil?(false)
      public?(true)
    end

    attribute :owner_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # %{"new_message" => ["in_app", "sms"]} — string keys, because this is a
    # jsonb column and round-tripping atoms through it is how atom leaks start.
    attribute :overrides, :map do
      default(%{})
      allow_nil?(false)
      public?(true)
    end

    attribute(:quiet_hours_start, :time, public?: true)
    attribute(:quiet_hours_end, :time, public?: true)

    attribute :utc_offset_minutes, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:one_per_owner, [:owner_kind, :owner_id])
  end

  actions do
    defaults([:read])

    # Upsert: a caller should never have to know whether this person has ever
    # opened the settings page before.
    create :put do
      accept([
        :owner_kind,
        :owner_id,
        :overrides,
        :quiet_hours_start,
        :quiet_hours_end,
        :utc_offset_minutes
      ])

      upsert?(true)
      upsert_identity(:one_per_owner)
    end

    read :for_owner do
      argument(:owner_kind, :atom, allow_nil?: false)
      argument(:owner_id, :uuid, allow_nil?: false)

      filter(expr(owner_kind == ^arg(:owner_kind) and owner_id == ^arg(:owner_id)))
    end
  end
end
