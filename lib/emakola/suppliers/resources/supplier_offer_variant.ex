defmodule Emakola.Suppliers.SupplierOfferVariant do
  @moduledoc "Network-specific commercial terms for an existing source variant."

  use Ash.Resource,
    domain: Emakola.Suppliers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("supplier_offer_variants")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:offer_id, :uuid, allow_nil?: false, public?: true)
    attribute(:wholesaler_store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:source_variant_id, :uuid, allow_nil?: false, public?: true)
    attribute(:supplier_price, :integer, allow_nil?: false, public?: true)
    attribute(:suggested_retail_price, :integer, allow_nil?: false, public?: true)
    attribute(:max_retail_price, :integer, public?: true)
    attribute(:fixed_commission_amount, :integer, public?: true)
    timestamps()
  end

  relationships do
    belongs_to :offer, Emakola.Suppliers.SupplierOffer do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :source_variant, Emakola.Catalog.Variant do
      source_attribute(:source_variant_id)
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_offer_variant, [:offer_id, :source_variant_id])
  end

  policies do
    policy action_type([:create, :read, :update, :destroy]) do
      forbid_if(always())
    end
  end

  validations do
    validate(compare(:supplier_price, greater_than: 0))
    validate(compare(:suggested_retail_price, greater_than: 0))

    validate(fn changeset, _context ->
      supplier = Ash.Changeset.get_attribute(changeset, :supplier_price)
      suggested = Ash.Changeset.get_attribute(changeset, :suggested_retail_price)
      maximum = Ash.Changeset.get_attribute(changeset, :max_retail_price)

      cond do
        suggested && supplier && suggested < supplier ->
          {:error, field: :suggested_retail_price, message: "must cover the supplier price"}

        maximum && suggested && maximum < suggested ->
          {:error, field: :max_retail_price, message: "must not be below the suggested price"}

        true ->
          :ok
      end
    end)
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :offer_id,
        :wholesaler_store_id,
        :source_variant_id,
        :supplier_price,
        :suggested_retail_price,
        :max_retail_price,
        :fixed_commission_amount
      ])
    end

    update :update_terms do
      require_atomic?(false)

      accept([
        :supplier_price,
        :suggested_retail_price,
        :max_retail_price,
        :fixed_commission_amount
      ])
    end

    destroy(:destroy)
  end
end
