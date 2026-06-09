defmodule Emakola.Suppliers do
  @moduledoc "Suppliers domain — third-party suppliers for dropshipped products."
  use Ash.Domain

  require Ash.Query

  resources do
    resource Emakola.Suppliers.Supplier do
      define(:create_supplier, action: :create)
      define(:list_suppliers_by_store, action: :list_by_store, args: [:store_id])
    end
  end
end
