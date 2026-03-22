defmodule Emakola.Orders.CheckoutService do
  @moduledoc """
  Orchestrates the checkout process: validates cart items, creates the order
  and line items, decrements stock, and calculates totals.

  NOTE: This is a stub. Full implementation will be added when Order and
  LineItem resources are built in the Orders domain.
  """

  @doc """
  Process a checkout for the given store.

  ## Parameters
    - `store_id` — UUID of the store
    - `items` — list of `%{variant_id: uuid, quantity: integer}`
    - `opts` — keyword list with optional :customer_id, :notes, etc.

  ## Returns
    - `{:ok, order}` on success
    - `{:error, reason}` on failure
  """
  @spec checkout!(String.t(), list(map()), keyword()) :: {:ok, map()} | {:error, term()}
  def checkout!(store_id, items, opts)

  def checkout!(_store_id, [], _opts), do: {:error, :empty_cart}

  def checkout!(store_id, items, opts) when is_binary(store_id) and is_list(items) do
    # Stub: full implementation pending Order/LineItem resources.
    # Returns a placeholder order map to satisfy the type contract.
    if opts[:force_success] do
      {:ok, %{order_number: "ORD-STUB-000000", id: nil}}
    else
      {:error, :not_implemented}
    end
  end
end
