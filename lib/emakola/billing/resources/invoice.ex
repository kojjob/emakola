defmodule Emakola.Billing.Invoice do
  @moduledoc "Invoice records generated for each subscription billing cycle."
  use Ash.Resource,
    domain: Emakola.Billing,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("invoices")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :invoice_number, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :amount_cents, :integer do
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:paid, :pending, :failed, :refunded])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute :stripe_invoice_id, :string do
      allow_nil?(true)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :period_start, :date do
      allow_nil?(false)
      public?(true)
    end

    attribute :period_end, :date do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :organisation, Emakola.Accounts.Organisation do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :invoice_number,
        :amount_cents,
        :status,
        :stripe_invoice_id,
        :period_start,
        :period_end
      ])

      argument(:organisation_id, :uuid, allow_nil?: false)
      change(manage_relationship(:organisation_id, :organisation, type: :append))
    end
  end
end
