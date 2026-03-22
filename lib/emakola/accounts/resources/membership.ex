defmodule Emakola.Accounts.Membership do
  use Ash.Resource,
    domain: Emakola.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("memberships")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :admin, :member])
      default(:member)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Emakola.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :organisation, Emakola.Accounts.Organisation do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_user_org, [:user_id, :organisation_id])
  end

  policies do
    # TODO: Restrict update/destroy to org owners once all call sites pass actor:
    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:role])

      argument(:user_id, :uuid, allow_nil?: false)
      argument(:organisation_id, :uuid, allow_nil?: false)

      change(manage_relationship(:user_id, :user, type: :append))
      change(manage_relationship(:organisation_id, :organisation, type: :append))
    end

    update :change_role do
      accept([:role])
    end
  end
end
