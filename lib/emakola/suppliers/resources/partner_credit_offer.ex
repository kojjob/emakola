defmodule Emakola.Suppliers.PartnerCreditOffer do
  use Ash.Resource, domain: Emakola.Suppliers, data_layer: AshPostgres.DataLayer

  postgres do
    table("partner_credit_offers")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:provider_type, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:supplier, :licensed_partner]]
    )

    attribute(:provider_store_id, :uuid, public?: true)
    attribute(:provider_name, :string, allow_nil?: false, public?: true)
    attribute(:license_reference, :string, public?: true)
    attribute(:creditor_subaccount_code, :string, allow_nil?: false, public?: true)
    attribute(:borrower_store_id, :uuid, allow_nil?: false, public?: true)

    attribute(:minimum_tier, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:starter, :reliable, :proven]]
    )

    attribute(:principal_amount, :integer, allow_nil?: false, public?: true)
    attribute(:fee_amount, :integer, allow_nil?: false, public?: true)
    attribute(:repayment_bps, :integer, allow_nil?: false, public?: true)
    attribute(:term_days, :integer, allow_nil?: false, public?: true)
    attribute(:reason_code, :string, allow_nil?: false, public?: true)
    attribute(:decision_snapshot, :map, allow_nil?: false, default: %{}, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :offered,
      public?: true,
      constraints: [one_of: [:offered, :accepted, :withdrawn, :expired]]
    )

    timestamps()
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :provider_type,
        :provider_store_id,
        :provider_name,
        :license_reference,
        :creditor_subaccount_code,
        :borrower_store_id,
        :minimum_tier,
        :principal_amount,
        :fee_amount,
        :repayment_bps,
        :term_days,
        :reason_code,
        :decision_snapshot
      ])
    end

    update :accept do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :accepted))
    end
  end
end
