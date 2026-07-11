defmodule Emakola.Suppliers.SalesTeamSettlement do
  @moduledoc "Immutable, consented allocation of an attributed order's merchant proceeds."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_sales_team_settlements")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:order_id, :uuid, allow_nil?: false, public?: true)
    attribute(:payment_id, :uuid, allow_nil?: false, public?: true)
    attribute(:team_id, :uuid, allow_nil?: false, public?: true)
    attribute(:team_member_id, :uuid, allow_nil?: false, public?: true)
    attribute(:merchant_id, :uuid, allow_nil?: false, public?: true)

    attribute(:role, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:owner, :content, :seller, :support]]
    )

    attribute(:split_bps, :integer, allow_nil?: false, public?: true)
    attribute(:settlement_base, :integer, allow_nil?: false, public?: true)
    attribute(:amount, :integer, allow_nil?: false, public?: true)
    attribute(:reversed_amount, :integer, allow_nil?: false, default: 0, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :settled,
      public?: true,
      constraints: [one_of: [:settled, :partially_reversed, :reversed]]
    )

    attribute(:settled_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:reversed_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_payment_member, [:payment_id, :team_member_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :order_id,
        :payment_id,
        :team_id,
        :team_member_id,
        :merchant_id,
        :role,
        :split_bps,
        :settlement_base,
        :amount,
        :settled_at
      ])
    end

    update :record_reversal do
      require_atomic?(false)
      accept([:reversed_amount])

      change(fn changeset, _context ->
        reversed = Ash.Changeset.get_attribute(changeset, :reversed_amount) || 0
        status = if reversed >= changeset.data.amount, do: :reversed, else: :partially_reversed
        Ash.Changeset.change_attribute(changeset, :status, status)
      end)

      change(set_attribute(:reversed_at, &DateTime.utc_now/0))
    end
  end
end
