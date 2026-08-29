defmodule Emakola.Affiliates.AffiliateLink do
  @moduledoc """
  One affiliate's link to one product in one shop.

  The token is what survives the journey — it rides the URL, is captured into
  the session by `EmakolaWeb.Plugs.UtmCapture`, and is written onto
  `Order.attribution` at checkout. Everything the commission carve later needs
  hangs off resolving it back to an affiliate and a product.

  Stable per (affiliate, store, product): an affiliate who shares their link
  twice must not split their own attribution across two rows, and a token
  already in someone's session must keep working.
  """

  use Ash.Resource,
    domain: Emakola.Affiliates,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("affiliate_links")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :affiliate_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :token, :string do
      allow_nil?(false)
      public?(true)
    end

    # Cheap counters for the affiliate's own page. Deliberately NOT the basis
    # for anything paid — money comes from PaymentSplit rows, never from a
    # counter that a page refresh could inflate.
    attribute :click_count, :integer do
      allow_nil?(false)
      public?(true)
      default(0)
    end

    timestamps()
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

    create :mint do
      accept([:affiliate_id, :store_id, :product_id, :token])
      upsert?(true)
      upsert_identity(:one_link_per_product)
      # Keep the ORIGINAL token on a repeat mint — a token already shared into
      # a WhatsApp group must not stop working because the affiliate reopened
      # the page.
      upsert_fields([])
    end

    update :record_click do
      change(atomic_update(:click_count, expr(click_count + 1)))
    end

    read :by_token do
      argument :token, :string do
        allow_nil?(false)
      end

      filter(expr(token == ^arg(:token)))
    end

    read :for_affiliate do
      argument :affiliate_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(affiliate_id == ^arg(:affiliate_id)))
    end
  end

  identities do
    identity(:one_link_per_product, [:affiliate_id, :store_id, :product_id])
    identity(:unique_token, [:token])
  end
end
