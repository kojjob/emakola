defmodule Emakola.Affiliates.AffiliateProgramme do
  @moduledoc """
  A merchant's decision to pay commission, and how much.

  One per store. `commission_bps` is basis points — the convention used
  everywhere money is computed in this codebase (`div(amount * bps, 10_000)`),
  never a percentage as a float, because commission is money and money here
  is integers.

  Disabling keeps the rate: a merchant pausing over Christmas should not have
  to remember what they were paying when they switch it back on.
  """

  use Ash.Resource,
    domain: Emakola.Affiliates,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("affiliate_programmes")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # 1..9_999. At 10_000 (100%) the merchant keeps nothing of the sale, and
    # once other carves stack on the same allocation the split goes negative
    # and OrderSettlement refuses the whole charge.
    attribute :commission_bps, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1, max: 9_999)
    end

    attribute :active, :boolean do
      allow_nil?(false)
      public?(true)
      default(true)
    end

    timestamps()
  end

  policies do
    bypass action_type(:create) do
      authorize_if(always())
    end

    bypass action_type(:action) do
      authorize_if(always())
    end

    policy action_type([:read, :update]) do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :enable do
      accept([:store_id, :commission_bps])
      change(set_attribute(:active, true))
      upsert?(true)
      upsert_identity(:one_per_store)
      upsert_fields([:commission_bps, :active])
    end

    update :disable do
      change(set_attribute(:active, false))
    end

    read :for_store do
      argument :store_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(store_id == ^arg(:store_id)))
    end
  end

  identities do
    identity(:one_per_store, [:store_id])
  end
end
