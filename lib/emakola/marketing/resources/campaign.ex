defmodule Emakola.Marketing.Campaign do
  @moduledoc """
  A one-off message a merchant sends to their own customers.

  **Counts are of deliveries attempted, never of engagement.** `sent_count`
  and `failed_count` come from `CampaignRecipient` rows this platform actually
  wrote. There is deliberately no `opened` or `clicked`: the SMS gateway does
  not report either, and the WhatsApp Business API only does through webhooks
  we do not receive. The page this replaced showed "89% Opened".

  `body` is capped at 480 characters — a little over three SMS segments. The
  merchant pays per segment, so the cap is a cost guard.

  Multi-tenant via `store_id`.
  """

  use Ash.Resource,
    domain: Emakola.Marketing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("campaigns")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 120)
    end

    attribute :channel, :atom do
      allow_nil?(false)
      public?(true)
      default(:sms)
      # WhatsApp marketing requires pre-approved templates, so free-text
      # campaigns are SMS-only until template management exists.
      constraints(one_of: [:sms])
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 480)
    end

    attribute :audience, :atom do
      allow_nil?(false)
      public?(true)
      default(:everyone)
      constraints(one_of: [:everyone, :new, :bought_again, :big_spenders, :gone_quiet])
    end

    attribute :status, :atom do
      allow_nil?(false)
      public?(true)
      default(:draft)
      constraints(one_of: [:draft, :sending, :sent, :failed])
    end

    attribute :audience_size, :integer do
      allow_nil?(false)
      public?(true)
      default(0)
    end

    attribute :sent_count, :integer do
      allow_nil?(false)
      public?(true)
      default(0)
    end

    attribute :failed_count, :integer do
      allow_nil?(false)
      public?(true)
      default(0)
    end

    attribute :sent_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many :recipients, Emakola.Marketing.CampaignRecipient do
      destination_attribute(:campaign_id)
    end
  end

  policies do
    bypass action_type(:create) do
      authorize_if(always())
    end

    bypass action_type(:action) do
      authorize_if(always())
    end

    policy action_type([:read, :update]) do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id, :name, :channel, :body, :audience])
    end

    update :mark_sending do
      accept([:audience_size])
      change(set_attribute(:status, :sending))
    end

    update :record_result do
      accept([:sent_count, :failed_count])
      require_atomic?(false)

      change(set_attribute(:status, :sent))
      change(set_attribute(:sent_at, &DateTime.utc_now/0))
    end

    update :mark_failed do
      change(set_attribute(:status, :failed))
    end

    read :for_store do
      argument :store_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
