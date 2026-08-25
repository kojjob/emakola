defmodule Emakola.Affiliates.Affiliate do
  @moduledoc """
  Someone who promotes a merchant's products and earns commission on the
  sales they drive. Not a merchant, and they have no shop.

  Identified by **phone**, not email — most people in this market do not use
  email, and phone is already how the platform recognises people. The number
  is stored normalised to E.164 so `0201234567` and `+233201234567` are one
  person rather than two accounts and two balances.

  `payout_store_id` points at a `:affiliate_payout` store: a container that
  exists only because `Payout.store_id` is `allow_nil?: false` and the MoMo
  transfer resolves its destination from a store's payout account. It is
  never a shop — see `Emakola.Affiliates.PayoutStoreNeverLeaksTest`.
  """

  use Ash.Resource,
    domain: Emakola.Affiliates,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("affiliates")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Always E.164 — normalised on the way in by Affiliates.register/1.
    attribute :phone, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 20)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 120)
    end

    attribute :momo_number, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 20)
    end

    attribute :momo_provider, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :payout_store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      public?(true)
      default(:active)
      constraints(one_of: [:active, :suspended])
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

    create :register do
      accept([:phone, :name, :momo_number, :momo_provider, :payout_store_id])
    end

    update :suspend do
      change(set_attribute(:status, :suspended))
    end

    read :by_phone do
      argument :phone, :string do
        allow_nil?(false)
      end

      filter(expr(phone == ^arg(:phone)))
    end
  end

  identities do
    identity(:unique_phone, [:phone])
  end
end
