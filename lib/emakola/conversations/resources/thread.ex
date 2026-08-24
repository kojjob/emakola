defmodule Emakola.Conversations.Thread do
  @moduledoc """
  A conversation between two sides.

  Two kinds share this one resource:

    * `:shop_buyer` — `store_id` + `customer_id`
    * `:platform_merchant` — `merchant_id`

  One resource rather than two, because everything difficult about messaging
  — ordering, unread, isolation — is identical in both, and only the identity
  of the two sides differs.

  **Unread is two timestamps, not a receipts table.** `merchant_last_read_at`
  and `counterpart_last_read_at` are enough to count what each side has not
  seen, and they cost one row instead of one row per message per reader. The
  "counterpart" is the buyer on a shop thread and Makola staff on a platform
  thread — the side that is not the merchant.
  """

  use Ash.Resource,
    domain: Emakola.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("conversation_threads")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :kind, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:shop_buyer, :platform_merchant])
    end

    # Set on :shop_buyer threads only.
    attribute :store_id, :uuid do
      public?(true)
    end

    attribute :customer_id, :uuid do
      public?(true)
    end

    # Set on :platform_merchant threads only.
    attribute :merchant_id, :uuid do
      public?(true)
    end

    # Sorting an inbox by "who wrote last" without loading every message.
    attribute :last_message_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :merchant_last_read_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :counterpart_last_read_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many :messages, Emakola.Conversations.Message do
      destination_attribute(:thread_id)
    end

    # define_attribute? false — the ids are declared above so a thread can
    # carry either shape without two nullable belongs_to definitions fighting
    # over them.
    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :merchant, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
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

    create :open_shop do
      accept([:store_id, :customer_id])
      change(set_attribute(:kind, :shop_buyer))
      upsert?(true)
      upsert_identity(:one_thread_per_buyer)
    end

    create :open_platform do
      accept([:merchant_id])
      change(set_attribute(:kind, :platform_merchant))
      upsert?(true)
      upsert_identity(:one_thread_per_merchant)
    end

    update :touch do
      accept([:last_message_at])
    end

    update :mark_merchant_read do
      change(set_attribute(:merchant_last_read_at, &DateTime.utc_now/0))
    end

    update :mark_counterpart_read do
      change(set_attribute(:counterpart_last_read_at, &DateTime.utc_now/0))
    end

    read :for_store do
      argument :store_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(store_id == ^arg(:store_id) and kind == :shop_buyer))
      prepare(build(sort: [last_message_at: :desc_nils_last]))
    end
  end

  identities do
    identity(:one_thread_per_buyer, [:store_id, :customer_id])
    identity(:one_thread_per_merchant, [:merchant_id])
  end
end
