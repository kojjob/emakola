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
      constraints(one_of: Emakola.Customers.Segments.all())
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

    # Called both by the send handler (before it enqueues, so the Send button
    # disappears immediately) and by the worker itself (with the freshest
    # count) — so :sending must be allowed to re-enter itself, not just
    # :draft -> :sending.
    #
    # :failed is allowed in too, so a campaign whose job was discarded can be
    # retried from the page. Only :sent is a dead end: a campaign that has
    # already cost the merchant money must never be re-sent by accident.
    update :mark_sending do
      require_atomic?(false)
      accept([:audience_size])

      validate(
        {Emakola.Validations.StatusGuard,
         from: [:draft, :sending, :failed],
         message: "cannot send a campaign that has already been sent"}
      )

      # This filter is NOT the double-send guard, and it cannot be one.
      # Because :sending is inside the allowed set, a second concurrent
      # mark_sending matches one row, not zero — it is re-entrant by
      # construction, deliberately, so the worker can re-enter it with the
      # freshest audience count.
      #
      # **The real gate is the Oban unique insert** in
      # EmakolaWeb.Admin.CampaignLive.Index: `unique: [period: :infinity,
      # keys: [:campaign_id], states: :incomplete]` is a partial unique index
      # in oban_jobs, so a second tab's Oban.insert/1 returns the EXISTING
      # job and only one send is ever queued. Do not weaken or drop that
      # option on the strength of this filter — if it goes, sends double and
      # the merchant pays twice for every SMS.
      #
      # What this filter does buy: a campaign already :sent can never be
      # dragged back to :sending by a stale changeset.
      change(fn changeset, _context ->
        Ash.Changeset.filter(changeset, expr(status in [:draft, :sending, :failed]))
      end)

      change(set_attribute(:status, :sending))
    end

    update :record_result do
      accept([:sent_count, :failed_count])
      require_atomic?(false)

      change(set_attribute(:status, :sent))
      change(set_attribute(:sent_at, &DateTime.utc_now/0))
    end

    # Set by CampaignSendWorker when the send raises, so a discarded job
    # leaves a campaign the merchant can retry rather than one stuck
    # :sending with no Send button.
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
