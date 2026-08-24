defmodule Emakola.Marketing.CampaignRecipient do
  @moduledoc """
  One row per customer a campaign was attempted to.

  The row is written **before** the provider call, in `:pending`, and updated
  after. That order is what makes the Oban retry safe: a worker that crashes
  between a successful send and its bookkeeping finds the row already claimed
  and does not send twice. Writing the row afterwards would make a unique
  index useless — the duplicate SMS has already gone out by then.

  `phone` is denormalised at send time so the record of what was attempted
  survives the customer later changing their number.
  """

  use Ash.Resource,
    domain: Emakola.Marketing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("campaign_recipients")
    repo(Emakola.Repo)

    references do
      reference(:campaign, on_delete: :delete)
    end

    custom_indexes do
      # One attempt per customer per campaign — the claim that makes a retry
      # safe rather than a second charge on the merchant's SMS bill.
      index([:campaign_id, :customer_id], unique: true)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :campaign_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :phone, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      public?(true)
      default(:pending)
      constraints(one_of: [:pending, :sent, :failed])
    end

    attribute :error, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :sent_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :campaign, Emakola.Marketing.Campaign do
      allow_nil?(false)
      attribute_writable?(true)
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

    create :claim do
      accept([:campaign_id, :customer_id, :phone])
      upsert?(true)
      upsert_identity(:unique_attempt)
    end

    update :mark_sent do
      change(set_attribute(:status, :sent))
      change(set_attribute(:sent_at, &DateTime.utc_now/0))
    end

    update :mark_failed do
      accept([:error])
      change(set_attribute(:status, :failed))
    end

    read :for_campaign do
      argument :campaign_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(campaign_id == ^arg(:campaign_id)))
    end
  end

  identities do
    identity(:unique_attempt, [:campaign_id, :customer_id])
  end
end
