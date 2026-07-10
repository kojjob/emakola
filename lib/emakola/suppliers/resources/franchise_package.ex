defmodule Emakola.Suppliers.FranchisePackage do
  @moduledoc "A supplier-authored product-sales package with training, brand rules, permissions, and commission."
  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("earn_franchise_packages")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:supplier_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:offer_ids, {:array, :uuid}, allow_nil?: false, default: [], public?: true)
    attribute(:training, :map, allow_nil?: false, default: %{}, public?: true)
    attribute(:brand_rules, :map, allow_nil?: false, default: %{}, public?: true)

    attribute(:channel_permissions, {:array, :atom},
      allow_nil?: false,
      default: [],
      public?: true,
      constraints: [items: [one_of: [:storefront, :whatsapp, :facebook, :in_person]]]
    )

    attribute(:territory, :string, public?: true)
    attribute(:commission_bps, :integer, allow_nil?: false, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      default: :draft,
      public?: true,
      constraints: [one_of: [:draft, :published, :paused, :archived]]
    )

    timestamps()
  end

  relationships do
    belongs_to :supplier_store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end

    has_many :enrollments, Emakola.Suppliers.FranchiseEnrollment do
      destination_attribute(:package_id)
      public?(true)
    end
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :supplier_store_id,
        :name,
        :offer_ids,
        :training,
        :brand_rules,
        :channel_permissions,
        :territory,
        :commission_bps
      ])

      validate(compare(:commission_bps, greater_than: 0, less_than_or_equal_to: 10_000))
    end

    update :publish do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :draft))
      change(set_attribute(:status, :published))
    end

    update :pause do
      require_atomic?(false)
      accept([])
      validate(attribute_equals(:status, :published))
      change(set_attribute(:status, :paused))
    end

    read :owned_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(supplier_store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc], load: [:enrollments]))
    end
  end
end
