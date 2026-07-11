defmodule Emakola.Suppliers.ProtectedPreorder do
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("protected_preorders")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:supplier_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:listing_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, allow_nil?: false, public?: true)
    attribute(:unit_price, :integer, allow_nil?: false, public?: true)
    attribute(:deposit_amount, :integer, allow_nil?: false, public?: true)
    attribute(:minimum_quantity, :integer, allow_nil?: false, public?: true)
    attribute(:maximum_quantity, :integer, allow_nil?: false, public?: true)
    attribute(:committed_quantity, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:commitment_deadline, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:delivery_window_start, :date, allow_nil?: false, public?: true)
    attribute(:delivery_window_end, :date, allow_nil?: false, public?: true)
    attribute(:automatic_refund_deadline, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:customer_disclosures, :map, allow_nil?: false, public?: true)
    attribute(:legal_approval_reference, :string, public?: true)
    attribute(:payment_provider_approval_reference, :string, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :draft,
      public?: true,
      constraints: [one_of: [:draft, :open, :funded, :production, :fulfilled, :failed, :refunded]]
    )

    attribute(:failed_at, :utc_datetime_usec, public?: true)
    attribute(:failure_reason, :string, public?: true)
    timestamps()
  end

  relationships do
    has_many :milestones, Emakola.Suppliers.PreorderMilestone do
      destination_attribute(:preorder_id)
    end

    has_many :deposits, Emakola.Suppliers.PreorderDeposit do
      destination_attribute(:preorder_id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :supplier_store_id,
        :listing_variant_id,
        :title,
        :description,
        :unit_price,
        :deposit_amount,
        :minimum_quantity,
        :maximum_quantity,
        :commitment_deadline,
        :delivery_window_start,
        :delivery_window_end,
        :automatic_refund_deadline,
        :customer_disclosures,
        :legal_approval_reference,
        :payment_provider_approval_reference
      ])
    end

    update :open do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :open))
    end

    update :record_quantity do
      require_atomic?(true)
      argument(:quantity, :integer, allow_nil?: false)
      change(atomic_update(:committed_quantity, expr(committed_quantity + ^arg(:quantity))))
    end

    update :status do
      require_atomic?(false)
      accept([:status, :failed_at, :failure_reason])
    end
  end
end
