defmodule Emakola.Catalog do
  @moduledoc """
  The Catalog domain — products, variants, categories, images.

  All resources are multi-tenant, scoped to a store via store_id.
  """
  use Ash.Domain

  resources do
    resource Emakola.Catalog.Category do
      define(:create_category, action: :create)
      define(:list_root_categories, action: :list_roots, args: [:store_id])
      define(:list_child_categories, action: :list_children, args: [:parent_id, :store_id])
    end
  end
end
