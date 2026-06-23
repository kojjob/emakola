defmodule Emakola.Notifications.AnnouncementDismissal do
  @moduledoc """
  Records that a merchant dismissed an announcement banner. One row per
  (announcement, merchant) — re-dismissing is an idempotent upsert. Writes run
  with authorize?: false from the merchant banner hook (merchant_id is taken
  from the server-side session, never from request params).
  """
  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("announcement_dismissals")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :announcement_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :merchant_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_dismissal, [:announcement_id, :merchant_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    policy action_type([:create, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :dismiss do
      upsert?(true)
      upsert_identity(:unique_dismissal)
      accept([:announcement_id, :merchant_id])
    end

    read :dismissed_ids_for_merchant do
      argument(:merchant_id, :uuid, allow_nil?: false)
      filter(expr(merchant_id == ^arg(:merchant_id)))
    end
  end
end
