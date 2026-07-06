defmodule Emakola.Stores.StorePageContent do
  @moduledoc """
  Per-store editable prose for the storefront informational pages —
  About, Contact, FAQ and Policies. One row per store.

  Kept off the (publicly-readable) `Store` resource so merchant-authored
  content carries merchant-only write policies — the same split as
  `StorePayoutAccount`. Storefront code reads it with `authorize?: false`;
  an un-customised store simply has no row (or blank fields) and the
  renderers fall back to neutral, store-name-driven copy.

  ## Block shapes
  The `{:array, :map}` fields round-trip as string-keyed maps from jsonb:

      about_steps:  %{"number" => "01", "title" => ..., "description" => ...}
      about_values: %{"title" => ..., "description" => ...}
      faq_items:    %{"question" => ..., "answer" => ...}

  Contact details (email/phone/whatsapp/address/socials) are NOT duplicated
  here — they live on `Store` and are read straight from it.
  """

  use Ash.Resource,
    domain: Emakola.Stores,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @content_fields [
    :about_headline,
    :about_intro,
    :about_story,
    :about_steps,
    :about_values,
    :about_cta_heading,
    :about_cta_text,
    :faq_items,
    :shipping_returns,
    :privacy_policy,
    :terms_of_service,
    :contact_note,
    :contact_hours
  ]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("store_page_contents")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # About
    attribute :about_headline, :string do
      public?(true)
      constraints(max_length: 200)
    end

    attribute :about_intro, :string do
      public?(true)
    end

    attribute :about_story, :string do
      public?(true)
    end

    attribute :about_steps, {:array, :map} do
      default([])
      allow_nil?(false)
      public?(true)
    end

    attribute :about_values, {:array, :map} do
      default([])
      allow_nil?(false)
      public?(true)
    end

    attribute :about_cta_heading, :string do
      public?(true)
    end

    attribute :about_cta_text, :string do
      public?(true)
    end

    # FAQ
    attribute :faq_items, {:array, :map} do
      default([])
      allow_nil?(false)
      public?(true)
    end

    # Policies
    attribute :shipping_returns, :string do
      public?(true)
    end

    attribute :privacy_policy, :string do
      public?(true)
    end

    attribute :terms_of_service, :string do
      public?(true)
    end

    # Contact (supplements the contact fields that live on Store)
    attribute :contact_note, :string do
      public?(true)
    end

    attribute :contact_hours, :string do
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_page_content, [:store_id])
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      source_attribute(:store_id)
      define_attribute?(false)
    end
  end

  policies do
    # Reads are open — storefront reads content without an actor.
    # Writes require a Merchant actor with access to the owning store.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:store_id | @content_fields])
    end

    update :update do
      accept(@content_fields)
    end

    read :get_by_store do
      get?(true)
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
    end
  end
end
