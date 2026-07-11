defmodule Emakola.Suppliers.CommercePassport do
  @moduledoc "Portable, expiring summary of evidence-backed commerce reliability."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_commerce_passports")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:score, :integer, allow_nil?: false, default: 500, public?: true)

    attribute(:tier, :atom,
      allow_nil?: false,
      default: :starter,
      public?: true,
      constraints: [one_of: [:starter, :reliable, :proven]]
    )

    attribute(:metrics, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:computed_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    has_many :signals, Emakola.Suppliers.ReputationSignal do
      destination_attribute(:passport_id)
      public?(true)
    end
  end

  identities do
    identity(:unique_store, [:store_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])
    create(:create, accept: [:store_id, :score, :tier, :metrics, :computed_at, :expires_at])

    update(:refresh,
      accept: [:score, :tier, :metrics, :computed_at, :expires_at],
      require_atomic?: false
    )
  end
end
