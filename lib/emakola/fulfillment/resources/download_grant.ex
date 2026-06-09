defmodule Emakola.Fulfillment.DownloadGrant do
  @moduledoc """
  A customer's entitlement to download a specific `Emakola.Catalog.DigitalFile`,
  issued by `Emakola.Fulfillment.Pipelines.DigitalDownload` when an order
  is paid. One row per (line_item, digital_file).

  ## Lifecycle

      :issue  → grant created when fulfillment runs
      :increment_download_count  → bumped each time the customer hits the
                                   download endpoint

  ## Limits and expiry

  Both `:download_limit` and `:expires_at` are nullable. `nil` means
  unlimited / never. The download endpoint enforces both at delivery
  time; this resource is purely state.

  ## Guest checkout

  `:customer_id` is nullable. Guest orders still get grants — delivery
  happens via signed email link rather than the customer account page.
  """

  use Ash.Resource,
    domain: Emakola.Fulfillment,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("download_grants")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :line_item_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      public?(true)
    end

    attribute :digital_file_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :download_limit, :integer do
      public?(true)
      constraints(min: 1)
    end

    attribute :downloaded_count, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
      constraints(min: 0)
    end

    attribute :expires_at, :utc_datetime_usec do
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :line_item, Emakola.Orders.LineItem do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :digital_file, Emakola.Catalog.DigitalFile do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_grant_per_line_item_file, [:line_item_id, :digital_file_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # System / pipeline calls (nil actor) — pipelines run with authorize?: false
    bypass always() do
      authorize_unless(actor_present())
    end

    # Merchants with store access can manage grants (e.g. revoke)
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :issue do
      accept([
        :store_id,
        :order_id,
        :line_item_id,
        :customer_id,
        :digital_file_id,
        :download_limit,
        :expires_at
      ])
    end

    update :increment_download_count do
      require_atomic?(true)
      accept([])
      change(atomic_update(:downloaded_count, expr(downloaded_count + 1)))
    end
  end
end
