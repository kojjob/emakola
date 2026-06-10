defmodule Emakola.Pages.Page do
  @moduledoc """
  Storefront page composed of an ordered list of blocks — backing store for
  the merchant page builder.

  A `Page` is owned by a store at a unique slug. When a published page exists
  at slug `"home"`, `Emakola.Pages` returns it for the storefront renderer
  to use instead of the theme's home module. Stores with no page keep their
  theme home — the builder is opt-in.

  ## Multi-tenancy
  Scoped to `store_id`. Read access is policy-open (storefronts need to read
  their own page). Writes require a Merchant actor with store access.

  ## Block shape
  Each entry in `blocks` is a map with three keys:

      %{
        "id"      => "stable-uuid",   # used as the LiveView/template key
        "type"    => "hero_banner",   # registered Block module type
        "content" => %{...}           # type-specific configuration
      }

  Block schema validation is intentionally loose at the resource level — the
  block module's `default_content/0` provides defaults at render time, so a
  page with stale content keeps rendering across block schema changes.
  """

  use Ash.Resource,
    domain: Emakola.Pages,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("storefront_pages")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 80)
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :published, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    attribute :blocks, {:array, :map} do
      default([])
      allow_nil?(false)
      public?(true)
    end

    attribute :meta, :map do
      default(%{})
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_store_slug, [:store_id, :slug])
  end

  policies do
    # Reads are open — storefront reads pages without an actor.
    # Writes require a Merchant actor with store access.
    # System code that needs to mutate a Page must opt in with `authorize?: false`.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:store_id, :slug, :title, :published, :blocks, :meta])
    end

    update :update do
      accept([:title, :published, :blocks, :meta])
    end

    read :get_published_for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      argument(:slug, :string, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id) and slug == ^arg(:slug) and published == true))
      get?(true)
    end

    read :list_for_store do
      argument(:store_id, :uuid, allow_nil?: false)

      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [slug: :asc]))
    end

    read :list_published_for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id) and published == true))
      prepare(build(sort: [slug: :asc]))
    end
  end
end
