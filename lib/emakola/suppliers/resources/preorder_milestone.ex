defmodule Emakola.Suppliers.PreorderMilestone do
  @moduledoc "Ordered, evidence-backed production milestone for a protected preorder."
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("preorder_milestones")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:preorder_id, :uuid, allow_nil?: false, public?: true)
    attribute(:position, :integer, allow_nil?: false, public?: true)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:due_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:evidence_requirements, :string, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :pending,
      public?: true,
      constraints: [one_of: [:pending, :completed, :missed]]
    )

    attribute(:evidence, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:completed_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_position, [:preorder_id, :position])
  end

  actions do
    defaults([:read])

    create :create do
      accept([:preorder_id, :position, :title, :due_at, :evidence_requirements])
    end

    update :complete do
      require_atomic?(false)
      accept([:evidence, :completed_at])
      change(set_attribute(:status, :completed))
    end

    update :miss do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :missed))
    end
  end
end
