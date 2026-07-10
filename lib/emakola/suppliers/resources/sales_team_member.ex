defmodule Emakola.Suppliers.SalesTeamMember do
  @moduledoc "A declared flat transaction role and fixed basis-point share accepted by its merchant."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_sales_team_members")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:team_id, :uuid, allow_nil?: false, public?: true)
    attribute(:merchant_id, :uuid, allow_nil?: false, public?: true)

    attribute(:role, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:owner, :content, :seller, :support]]
    )

    attribute(:split_bps, :integer, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :invited,
      public?: true,
      constraints: [one_of: [:invited, :active, :declined, :removed]]
    )

    attribute(:consented_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :team, Emakola.Suppliers.SalesTeam do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :merchant, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_team_merchant, [:team_id, :merchant_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :invite do
      accept([:team_id, :merchant_id, :role, :split_bps, :status, :consented_at])
      validate(compare(:split_bps, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000))
    end

    update :accept do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :invited))
      change(set_attribute(:status, :active))
      change(set_attribute(:consented_at, &DateTime.utc_now/0))
    end

    update :decline do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :invited))
      change(set_attribute(:status, :declined))
    end
  end
end
