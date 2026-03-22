defmodule Emakola.Orders.CheckoutService do
  @moduledoc """
  Orchestrates the checkout process: validates cart items, creates the order
  and line items, decrements stock, and calculates totals.

  All operations run inside an Ecto transaction so a failure at any step
  rolls everything back (including stock adjustments).
  """

  require Ash.Query

  @doc """
  Process a checkout for the given store.

  ## Parameters
    - `store_id` — UUID of the store
    - `items` — list of `%{variant_id: uuid, quantity: integer}`
    - `opts` — keyword list with optional :customer_id, :notes, :shipping_address, :billing_address

  ## Returns
    - `{:ok, order}` on success
    - `{:error, reason}` on failure
  """
  def checkout!(store_id, items, opts) do
    with :ok <- validate_cart(items),
         {:ok, variants} <- load_and_validate_variants(store_id, items),
         :ok <- validate_stock(variants, items) do
      run_checkout(store_id, items, variants, opts)
    end
  end

  # -- Validations -----------------------------------------------------

  defp validate_cart([]), do: {:error, :empty_cart}
  defp validate_cart(_items), do: :ok

  defp load_and_validate_variants(store_id, items) do
    variant_ids = Enum.map(items, & &1.variant_id)

    variants =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(id in ^variant_ids)
      |> Ash.Query.load(:product)
      |> Ash.read!()

    found_ids = MapSet.new(Enum.map(variants, & &1.id))
    requested_ids = MapSet.new(variant_ids)

    cond do
      MapSet.size(found_ids) != MapSet.size(requested_ids) ->
        {:error, :variant_not_found}

      Enum.any?(variants, fn v -> v.store_id != store_id end) ->
        {:error, :variant_not_in_store}

      true ->
        {:ok, Map.new(variants, fn v -> {v.id, v} end)}
    end
  end

  defp validate_stock(variants, items) do
    insufficient =
      Enum.any?(items, fn %{variant_id: vid, quantity: qty} ->
        variant = Map.fetch!(variants, vid)
        variant.stock_quantity < qty
      end)

    if insufficient, do: {:error, :insufficient_stock}, else: :ok
  end

  # -- Transaction -----------------------------------------------------

  defp run_checkout(store_id, items, variants, opts) do
    Emakola.Repo.transaction(fn ->
      # 1. Create order
      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          customer_id: Keyword.get(opts, :customer_id),
          notes: Keyword.get(opts, :notes),
          shipping_address: Keyword.get(opts, :shipping_address),
          billing_address: Keyword.get(opts, :billing_address)
        })
        |> Ash.create!()

      # 2. Create line items and decrement stock
      line_items =
        Enum.map(items, fn %{variant_id: vid, quantity: qty} ->
          # Create line item (snapshots price/title from variant change)
          line_item =
            Emakola.Orders.LineItem
            |> Ash.Changeset.for_create(:create, %{
              order_id: order.id,
              store_id: store_id,
              variant_id: vid,
              quantity: qty
            })
            |> Ash.create!()

          # Decrement stock atomically
          variant = Map.fetch!(variants, vid)

          variant
          |> Ash.Changeset.for_update(:adjust_stock, %{delta: -qty})
          |> Ash.update!()

          line_item
        end)

      # 3. Calculate totals
      subtotal = Enum.reduce(line_items, 0, fn li, acc -> acc + li.line_total end)

      order =
        order
        |> Ash.Changeset.for_update(:update, %{subtotal: subtotal, total: subtotal})
        |> Ash.update!()

      order
    end)
  rescue
    _e in Ash.Error.Invalid ->
      # Stock CHECK constraint violation or other Ash errors
      {:error, :insufficient_stock}

    _e in Ecto.StaleEntryError ->
      {:error, :insufficient_stock}
  end
end
