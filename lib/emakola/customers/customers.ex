defmodule Emakola.Customers do
  @moduledoc """
  The Customers domain — store customer accounts and addresses.
  """
  use Ash.Domain

  resources do
    resource Emakola.Customers.Customer do
      define(:create_customer, action: :create)
      define(:list_customers_by_store, action: :list_by_store, args: [:store_id])
      define(:search_customers, action: :search, args: [:store_id, :query])
      define(:get_customer_by_id, action: :get_by_id, args: [:id])
    end
  end
end
