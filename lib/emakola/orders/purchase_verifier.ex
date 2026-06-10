defmodule Emakola.Orders.PurchaseVerifier do
  @moduledoc """
  Answers purchase-eligibility questions on behalf of other contexts.

  Provides a single, authoritative function for verifying whether a customer
  has a delivered order containing a specific product within a store. This
  boundary module prevents other contexts (e.g. Catalog.Review) from reaching
  directly into the Orders schema.
  """

  require Ash.Query

  @doc """
  Returns `{:ok, order_id}` if `customer_id` has at least one delivered order
  in `store_id` that contains a line item whose variant belongs to `product_id`.

  Returns `{:error, :not_eligible}` otherwise.

  Uses `authorize?: false` to match the behaviour of the Ecto query it replaces
  (Catalog.Review.eligible?/3 — system-level check, no actor in scope).
  """
  @spec has_delivered_order?(Ash.UUID.t(), Ash.UUID.t(), Ash.UUID.t()) ::
          {:ok, Ash.UUID.t()} | {:error, :not_eligible}
  def has_delivered_order?(store_id, product_id, customer_id) do
    result =
      Emakola.Orders.Order
      |> Ash.Query.filter(
        store_id == ^store_id and
          customer_id == ^customer_id and
          status == :delivered and
          exists(line_items, exists(variant, product_id == ^product_id))
      )
      |> Ash.Query.select([:id])
      |> Ash.Query.limit(1)
      |> Ash.read!(authorize?: false)

    case result do
      [] -> {:error, :not_eligible}
      [order | _] -> {:ok, order.id}
    end
  end
end
