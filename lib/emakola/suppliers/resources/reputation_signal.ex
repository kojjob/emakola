defmodule Emakola.Suppliers.ReputationSignal do
  @moduledoc "Explainable, expiring evidence used by a commerce passport."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_reputation_signals")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:passport_id, :uuid, allow_nil?: false, public?: true)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)

    attribute(:kind, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [
        one_of: [:fulfilled_orders, :service_quality, :refunds_disputes, :verified_training]
      ]
    )

    attribute(:value, :integer, allow_nil?: false, public?: true)
    attribute(:impact, :integer, allow_nil?: false, public?: true)
    attribute(:reason_code, :string, allow_nil?: false, public?: true)
    attribute(:evidence, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:source_fingerprint, :string, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :active,
      public?: true,
      constraints: [one_of: [:active, :appealed, :corrected, :expired]]
    )

    attribute(:observed_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:corrected_at, :utc_datetime_usec, public?: true)
    attribute(:correction_reason, :string, public?: true)
    timestamps()
  end

  relationships do
    has_many :appeals, Emakola.Suppliers.ReputationAppeal do
      destination_attribute(:signal_id)
      public?(true)
    end
  end

  identities do
    identity(:unique_snapshot, [:passport_id, :source_fingerprint])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create(:create,
      accept: [
        :passport_id,
        :store_id,
        :kind,
        :value,
        :impact,
        :reason_code,
        :evidence,
        :source_fingerprint,
        :observed_at,
        :expires_at
      ]
    )

    update :mark_appealed do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :active))
      change(set_attribute(:status, :appealed))
    end

    update :correct do
      require_atomic?(false)
      accept([:value, :impact, :evidence, :correction_reason])
      change(set_attribute(:status, :corrected))
      change(set_attribute(:corrected_at, &DateTime.utc_now/0))
    end

    update :expire do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :expired))
    end
  end
end
