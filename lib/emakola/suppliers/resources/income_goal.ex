defmodule Emakola.Suppliers.IncomeGoal do
  @moduledoc "A reseller's explicit, non-guaranteed income target for Hustle Autopilot."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_income_goals")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:target_amount, :integer, allow_nil?: false, public?: true)
    attribute(:timeframe_days, :integer, allow_nil?: false, public?: true)
    attribute(:daily_minutes, :integer, allow_nil?: false, public?: true)

    attribute :channels, {:array, :atom} do
      allow_nil?(false)
      default([])
      public?(true)
      constraints(items: [one_of: [:whatsapp, :facebook, :copy_link]])
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:active)
      public?(true)
      constraints(one_of: [:active, :completed, :paused, :cancelled])
    end

    attribute(:starts_on, :date, allow_nil?: false, public?: true)
    attribute(:ends_on, :date, allow_nil?: false, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
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
      accept([
        :store_id,
        :target_amount,
        :timeframe_days,
        :daily_minutes,
        :channels,
        :starts_on,
        :ends_on
      ])

      validate(compare(:target_amount, greater_than: 0))
      validate(compare(:timeframe_days, greater_than_or_equal_to: 7, less_than_or_equal_to: 90))
      validate(compare(:daily_minutes, greater_than_or_equal_to: 10, less_than_or_equal_to: 480))
    end

    read :for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    update :pause do
      accept([])
      change(set_attribute(:status, :paused))
    end

    update :complete do
      accept([])
      change(set_attribute(:status, :completed))
    end

    update :cancel do
      accept([])
      change(set_attribute(:status, :cancelled))
    end
  end
end
