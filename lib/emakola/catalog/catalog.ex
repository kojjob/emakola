defmodule Emakola.Catalog do
  @moduledoc """
  The Catalog domain — products, variants, categories, options, images.

  All resources are multi-tenant, scoped to a store via store_id.
  """
  use Ash.Domain

  resources do
    resource Emakola.Catalog.Category do
      define(:create_category, action: :create)
      define(:list_categories_by_store, action: :list_by_store, args: [:store_id])
      define(:list_root_categories, action: :list_roots, args: [:store_id])
      define(:list_child_categories, action: :list_children, args: [:parent_id, :store_id])
    end

    resource Emakola.Catalog.Product do
      define(:create_product, action: :create)
      define(:list_products_by_store, action: :list_by_store, args: [:store_id])

      define(:list_products_by_store_and_status,
        action: :list_by_store_and_status,
        args: [:store_id, :status]
      )

      define(:search_products, action: :search, args: [:query, :store_id])

      define(:list_products_by_category,
        action: :list_by_category,
        args: [:category_id, :store_id]
      )
    end

    resource(Emakola.Catalog.OptionType)
    resource(Emakola.Catalog.OptionValue)

    resource Emakola.Catalog.Variant do
      define(:list_variants_by_store, action: :list_by_store, args: [:store_id])
      define(:list_low_stock, action: :low_stock, args: [:threshold, :store_id])
    end

    resource(Emakola.Catalog.VariantOptionValue)

    resource(Emakola.Catalog.Image)

    resource(Emakola.Catalog.Review)

    resource(Emakola.Catalog.DigitalFile)
  end
end
