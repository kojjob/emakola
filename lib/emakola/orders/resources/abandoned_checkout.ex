defmodule Emakola.Orders.AbandonedCheckout do
  @moduledoc """
  A checkout the buyer walked away from after typing a phone.

  Written from the storefront while the buyer is still on the page, so the
  merchant sees the latest cart. Recovered when an order lands from the same
  cart session or the same phone. Never sends anything.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("abandoned_checkouts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:cart_session_id, :string, allow_nil?: false, public?: true)
    attribute(:phone, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, public?: true)
    attribute(:items, {:array, :map}, allow_nil?: false, default: [], public?: true)
    attribute(:cart_total, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:last_seen_at, :utc_datetime_usec, allow_nil?: false, public?: true)
    attribute(:recovered_order_id, :uuid, public?: true)
    attribute(:recovered_at, :utc_datetime_usec, public?: true)
    timestamps()
  end

  identities do
    identity(:one_per_cart, [:store_id, :cart_session_id])
  end

  policies do
    bypass action_type(:action) do
      authorize_if(always())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :touch do
      accept([:store_id, :cart_session_id, :phone, :name, :items, :cart_total])
      upsert?(true)
      upsert_identity(:one_per_cart)
      upsert_fields([:phone, :name, :items, :cart_total, :last_seen_at])
      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    update :recover do
      accept([:recovered_order_id])
      change(set_attribute(:recovered_at, &DateTime.utc_now/0))
    end

    read :left_behind do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:before, :utc_datetime, allow_nil?: false)
      argument(:after, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          store_id == ^arg(:store_id) and is_nil(recovered_at) and
            last_seen_at < ^arg(:before) and last_seen_at >= ^arg(:after)
        )
      )

      prepare(build(sort: [last_seen_at: :desc]))
    end
  end
end
