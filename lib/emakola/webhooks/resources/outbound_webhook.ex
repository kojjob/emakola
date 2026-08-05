defmodule Emakola.Webhooks.OutboundWebhook do
  @moduledoc "Registered outbound webhook endpoint with URL and subscribed event type configuration."
  use Ash.Resource,
    domain: Emakola.Webhooks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("outbound_webhooks")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :url, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2_048)
    end

    attribute :secret, :string do
      allow_nil?(false)
      sensitive?(true)
      constraints(max_length: 255)
    end

    attribute :secret_encrypted, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute :events, {:array, :string} do
      default([])
      allow_nil?(false)
      public?(true)
      constraints(items: [max_length: 255])
    end

    attribute(:active, :boolean, default: true, public?: true)
    attribute(:description, :string, public?: true, constraints: [max_length: 1_000])
    attribute(:metadata, :map, default: %{}, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :organisation, Emakola.Accounts.Organisation do
      allow_nil?(false)
      public?(true)
    end

    has_many :deliveries, Emakola.Webhooks.WebhookDelivery do
      destination_attribute(:webhook_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:url, :secret, :events, :active, :description, :metadata])
      argument(:organisation_id, :uuid, allow_nil?: false)
      change(manage_relationship(:organisation_id, :organisation, type: :append))

      change({
        Emakola.Security.Changes.EncryptAttribute,
        source: :secret, encrypted: :secret_encrypted, context: "outbound_webhooks.secret"
      })
    end

    update :update do
      accept([:url, :events, :active, :description])
    end

    update :rotate_secret do
      require_atomic?(false)
      accept([:secret])

      change({
        Emakola.Security.Changes.EncryptAttribute,
        source: :secret, encrypted: :secret_encrypted, context: "outbound_webhooks.secret"
      })
    end
  end
end
