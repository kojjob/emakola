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
      define(:get_category, action: :read, get_by: [:id])
      define(:get_category_by_slug, action: :get_by_slug, args: [:store_id, :slug])
      define(:update_category, action: :update)
      define(:destroy_category, action: :destroy)
    end

    resource Emakola.Catalog.Product do
      define(:create_product, action: :create)
      define(:get_product, action: :read, get_by: [:id])
      define(:get_product_by_slug, action: :get_by_slug, args: [:store_id, :slug])
      # Storefront-safe single-product fetch — active, moderation-ok, store-scoped.
      define(:get_active_product, action: :get_active_by_id, args: [:store_id, :id])
      define(:update_product, action: :update)
      define(:archive_product, action: :archive)
      define(:activate_product, action: :activate)
      define(:increment_product_share_count, action: :increment_share_count)
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

      define(:list_related_products, action: :list_related, args: [:store_id, :product_id])
      define(:list_products_admin, action: :list_admin, args: [:store_id])
      # Platform content moderation — call with `authorize?: false` (gated in the LiveView).
      define(:take_down_product, action: :take_down)
      define(:reinstate_product, action: :reinstate)
      define(:list_products_for_moderation, action: :list_for_moderation)
    end

    resource Emakola.Catalog.OptionType do
      define(:list_option_types_by_product, action: :list_by_product, args: [:product_id])
    end

    resource(Emakola.Catalog.OptionValue)

    resource Emakola.Catalog.Variant do
      define(:create_variant, action: :create)
      define(:list_variants_by_store, action: :list_by_store, args: [:store_id])
      define(:list_low_stock, action: :low_stock, args: [:threshold, :store_id])
      define(:list_variants_admin, action: :list_admin, args: [:store_id])
      define(:adjust_variant_stock, action: :adjust_stock)
      define(:update_variant, action: :update)
    end

    resource Emakola.Catalog.VariantOptionValue do
      define(:list_variant_option_values_by_variants,
        action: :list_by_variants,
        args: [:variant_ids]
      )
    end

    resource Emakola.Catalog.Image do
      define(:create_image, action: :create)
      define(:get_image, action: :read, get_by: [:id])
      define(:destroy_image, action: :destroy)
    end

    resource Emakola.Catalog.Review do
      define(:create_review, action: :create)
      define(:hide_review, action: :hide)
      define(:unhide_review, action: :unhide)
      define(:list_reviews_admin, action: :list_admin, args: [:store_id])
      define(:get_review_by_store, action: :get_by_store, args: [:id, :store_id])
      define(:list_published_reviews, action: :list_published_by_product, args: [:product_id])
    end

    resource(Emakola.Catalog.DigitalFile)
  end
end
