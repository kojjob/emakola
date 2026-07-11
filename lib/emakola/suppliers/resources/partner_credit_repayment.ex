defmodule Emakola.Suppliers.PartnerCreditRepayment do
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("partner_credit_repayments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:agreement_id, :uuid, allow_nil?: false, public?: true)
    attribute(:payment_id, :uuid, allow_nil?: false, public?: true)
    attribute(:amount, :integer, allow_nil?: false, public?: true)
    attribute(:reversed_amount, :integer, allow_nil?: false, default: 0, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_payment, [:agreement_id, :payment_id])
  end

  actions do
    defaults([:read])

    create :create do
      accept([:agreement_id, :payment_id, :amount])
    end

    update :reverse do
      require_atomic?(false)
      accept([:reversed_amount])
    end
  end
end
