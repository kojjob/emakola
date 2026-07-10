defmodule Emakola.Suppliers.SalesTeam do
  @moduledoc "A flat, consent-based transaction team with no recruitment hierarchy."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_sales_teams")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:created_by_id, :uuid, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :active,
      public?: true,
      constraints: [one_of: [:active, :closed]]
    )

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :created_by, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
    end

    has_many :members, Emakola.Suppliers.SalesTeamMember do
      destination_attribute(:team_id)
      public?(true)
    end
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :name, :created_by_id])
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], load: [members: :merchant]))
    end

    update :close do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :closed))
    end
  end
end
