defmodule Emakola.Billing.Subscription do
  use Ash.Resource,
    domain: Emakola.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("subscriptions")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :stripe_subscription_id, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :stripe_customer_id, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :status, :atom do
      constraints(one_of: [:active, :past_due, :canceled, :incomplete, :trialing, :unpaid])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute(:current_period_start, :utc_datetime, public?: true)
    attribute(:current_period_end, :utc_datetime, public?: true)
    attribute(:cancel_at_period_end, :boolean, default: false, public?: true)
    attribute(:canceled_at, :utc_datetime, public?: true)
    attribute(:trial_end, :utc_datetime, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :organisation, Emakola.Accounts.Organisation do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :plan, Emakola.Billing.Plan do
      allow_nil?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_stripe_subscription, [:stripe_subscription_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :stripe_subscription_id,
        :stripe_customer_id,
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end,
        :trial_end
      ])

      argument(:organisation_id, :uuid, allow_nil?: false)
      argument(:plan_id, :uuid, allow_nil?: false)
      change(manage_relationship(:organisation_id, :organisation, type: :append))
      change(manage_relationship(:plan_id, :plan, type: :append))
    end

    update :update_from_stripe do
      accept([
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end,
        :canceled_at,
        :trial_end
      ])
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :canceled))
      change(set_attribute(:canceled_at, &DateTime.utc_now/0))
    end

    read :by_organisation do
      argument(:organisation_id, :uuid, allow_nil?: false)
      filter(expr(organisation_id == ^arg(:organisation_id) and status in [:active, :trialing]))
    end

    read :by_stripe_id do
      argument(:stripe_subscription_id, :string, allow_nil?: false)
      filter(expr(stripe_subscription_id == ^arg(:stripe_subscription_id)))
    end
  end
end
