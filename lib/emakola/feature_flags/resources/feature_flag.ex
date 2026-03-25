defmodule Emakola.FeatureFlags.FeatureFlag do
  use Ash.Resource,
    domain: Emakola.FeatureFlags,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("feature_flags")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :key, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute(:description, :string, public?: true, constraints: [max_length: 1_000])

    attribute :enabled, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    attribute(:required_plan, :string, public?: true, constraints: [max_length: 255])

    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_key, [:key])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:key, :name, :description, :enabled, :required_plan, :metadata])
    end

    update :update do
      accept([:name, :description, :enabled, :required_plan, :metadata])
    end

    update :toggle do
      accept([])
      require_atomic?(false)

      change(fn changeset, _ctx ->
        current = Ash.Changeset.get_attribute(changeset, :enabled)
        Ash.Changeset.change_attribute(changeset, :enabled, !current)
      end)
    end
  end
end
