defmodule Emakola.Customers do
  @moduledoc """
  The Customers domain — store customer accounts and addresses.
  """
  use Ash.Domain

  resources do
    resource Emakola.Customers.Customer do
      define(:create_customer, action: :create)
    end
  end
end
