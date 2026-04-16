defmodule Emakola.Webhooks.WebhookDelivery do
  @moduledoc "Individual webhook delivery attempt recording HTTP status, response body, and retry state."
  use Ash.Resource,
    domain: Emakola.Webhooks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("webhook_deliveries")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:event_type, :string,
      allow_nil?: false,
      public?: true,
      constraints: [max_length: 255]
    )

    attribute(:payload, :map, default: %{}, public?: true)
    attribute(:response_status, :integer, public?: true)
    attribute(:response_body, :string, public?: true, constraints: [max_length: 50_000])
    attribute(:error, :string, public?: true, constraints: [max_length: 5_000])
    attribute(:attempts, :integer, default: 0, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:pending, :delivered, :failed])
      default(:pending)
      allow_nil?(false)
      public?(true)
    end

    attribute(:delivered_at, :utc_datetime, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :webhook, Emakola.Webhooks.OutboundWebhook do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:event_type, :payload, :status])
      argument(:webhook_id, :uuid, allow_nil?: false)
      change(manage_relationship(:webhook_id, :webhook, type: :append))
    end

    update :mark_delivered do
      accept([:response_status, :response_body, :attempts])
      change(set_attribute(:status, :delivered))
      change(set_attribute(:delivered_at, &DateTime.utc_now/0))
    end

    update :mark_failed do
      accept([:error, :response_status, :response_body, :attempts])
      change(set_attribute(:status, :failed))
    end
  end
end
