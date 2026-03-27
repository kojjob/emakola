defmodule Emakola.Customers do
  @moduledoc """
  The Customers domain — store customer accounts, addresses, and notes.

  All resources are multi-tenant, scoped to a store via store_id.
  """
  use Ash.Domain

  resources do
    resource Emakola.Customers.Customer do
      define(:create_customer, action: :create)
      define(:update_customer, action: :update)
      define(:find_or_create_customer, action: :find_or_create, args: [:email, :store_id])
      define(:list_customers_by_store, action: :list_by_store, args: [:store_id])
      define(:search_customers, action: :search, args: [:store_id, :query])
      define(:get_customer_by_id, action: :get_by_id, args: [:id])
    end

    resource(Emakola.Customers.CustomerToken)

    resource Emakola.Customers.Address do
      define(:create_address, action: :create)
      define(:update_address, action: :update)
      define(:destroy_address, action: :destroy)
      define(:list_addresses_by_customer, action: :list_by_customer, args: [:customer_id])
      define(:set_default_address, action: :set_as_default)
    end

    resource Emakola.Customers.CustomerNote do
      define(:create_note, action: :create)
      define(:destroy_note, action: :destroy)
      define(:list_notes_by_customer, action: :list_by_customer, args: [:customer_id])
    end
  end
end
