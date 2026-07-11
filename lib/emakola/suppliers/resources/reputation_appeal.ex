defmodule Emakola.Suppliers.ReputationAppeal do
  @moduledoc "Merchant challenge to a specific reputation signal and its evidence."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_reputation_appeals")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:signal_id, :uuid, allow_nil?: false, public?: true)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:merchant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:reason, :string, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :open,
      public?: true,
      constraints: [one_of: [:open, :upheld, :denied, :withdrawn]]
    )

    attribute(:resolution, :string, public?: true)
    attribute(:resolved_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])
    create(:create, accept: [:signal_id, :store_id, :merchant_id, :reason])
    update(:resolve, accept: [:status, :resolution, :resolved_at], require_atomic?: false)
  end
end
