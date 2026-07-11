defmodule Emakola.Suppliers.PartnerCreditAgreement do
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("partner_credit_agreements")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:offer_id, :uuid, allow_nil?: false, public?: true)
    attribute(:borrower_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:passport_id, :uuid, allow_nil?: false, public?: true)
    attribute(:principal_amount, :integer, allow_nil?: false, public?: true)
    attribute(:fee_amount, :integer, allow_nil?: false, public?: true)
    attribute(:total_due, :integer, allow_nil?: false, public?: true)
    attribute(:outstanding_amount, :integer, allow_nil?: false, public?: true)
    attribute(:repayment_bps, :integer, allow_nil?: false, public?: true)
    attribute(:consent_snapshot, :map, allow_nil?: false, public?: true)
    attribute(:consented_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:external_disbursement_reference, :string, public?: true)
    attribute(:activated_at, :utc_datetime_usec, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :accepted,
      public?: true,
      constraints: [one_of: [:accepted, :active, :repaid, :cancelled]]
    )

    timestamps()
  end

  relationships do
    belongs_to :offer, Emakola.Suppliers.PartnerCreditOffer do
      define_attribute?(false)
    end
  end

  identities do
    identity(:unique_offer, [:offer_id])
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :offer_id,
        :borrower_store_id,
        :passport_id,
        :principal_amount,
        :fee_amount,
        :total_due,
        :outstanding_amount,
        :repayment_bps,
        :consent_snapshot,
        :consented_at
      ])
    end

    update :activate do
      require_atomic?(false)
      accept([:external_disbursement_reference, :activated_at])
      change(set_attribute(:status, :active))
    end

    update :balance do
      require_atomic?(false)
      accept([:outstanding_amount, :status])
    end
  end
end
