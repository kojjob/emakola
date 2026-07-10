defmodule Emakola.Suppliers do
  @moduledoc "Suppliers domain — third-party suppliers for dropshipped products."
  use Ash.Domain

  resources do
    resource Emakola.Suppliers.Supplier do
      define(:create_supplier, action: :create)
      define(:update_supplier, action: :update)
      define(:list_suppliers_by_store, action: :list_by_store, args: [:store_id])
      define(:list_active_suppliers_by_store, action: :list_active_by_store, args: [:store_id])
      define(:get_supplier_by_store, action: :get_by_store, args: [:id, :store_id])
    end

    resource Emakola.Suppliers.SupplierLedgerEntry do
      define(:list_ledger_entries_by_supplier,
        action: :list_by_supplier,
        args: [:supplier_id]
      )

      define(:mark_ledger_entry_paid, action: :mark_paid)
    end

    resource Emakola.Suppliers.SupplyConnection do
      define(:request_supply_connection, action: :request)
      define(:list_supply_connections_for_store, action: :for_store, args: [:store_id])
      define(:approve_supply_connection, action: :approve)
      define(:reject_supply_connection, action: :reject)
      define(:suspend_supply_connection, action: :suspend)
      define(:reactivate_supply_connection, action: :reactivate)
      define(:terminate_supply_connection, action: :terminate)
    end
  end
end
