defmodule Emakola.Orders.CheckoutService do
  @moduledoc """
  Orchestrates the checkout process: resolves customer, validates cart items,
  creates the order and line items, decrements stock, and calculates totals.

  Customer resolution: accepts either `customer_id` (backward compatible)
  or `customer_email` (find-or-create). When using customer_email, the
  customer's default address is used as shipping address if none provided.

  All operations run inside an Ecto transaction so a failure at any step
  rolls everything back (including stock adjustments).
  """

  require Ash.Query

  @doc """
  Process a checkout for the given store.

  ## Parameters
    - `store_id` — UUID of the store
    - `items` — list of `%{variant_id: uuid, quantity: integer}`
    - `opts` — keyword list with:
      - `:customer_id` — UUID (backward compatible, used directly)
      - `:customer_email` — string (triggers find-or-create)
      - `:customer_name` — string (optional, used with customer_email)
      - `:customer_phone` — string (optional, used with customer_email)
      - `:notes` — string
      - `:shipping_address` — map
      - `:billing_address` — map

  ## Returns
    - `{:ok, order}` on success
    - `{:error, reason}` on failure
  """
  def checkout!(store_id, items, opts) do
    with :ok <- validate_cart(items),
         {:ok, variants} <- load_and_validate_variants(store_id, items),
         :ok <- validate_stock(variants, items),
         {:ok, customer_id, resolved_address} <- resolve_customer(store_id, opts) do
      run_checkout(store_id, items, variants, customer_id, resolved_address, opts)
    end
  end

  # -- Customer resolution --------------------------------------------

  defp resolve_customer(store_id, opts) do
    cond do
      Keyword.has_key?(opts, :customer_id) ->
        {:ok, Keyword.get(opts, :customer_id), nil}

      Keyword.has_key?(opts, :customer_email) ->
        email = Keyword.get(opts, :customer_email)
        name = Keyword.get(opts, :customer_name)
        phone = Keyword.get(opts, :customer_phone)

        customer =
          Emakola.Customers.Customer
          |> Ash.ActionInput.for_action(:find_or_create, %{
            email: email,
            store_id: store_id,
            name: name,
            phone: phone
          })
          |> Ash.run_action!()

        # Resolve default address if customer has one
        default_address = resolve_default_address(customer)

        {:ok, customer.id, default_address}

      true ->
        {:ok, nil, nil}
    end
  end

  defp resolve_default_address(customer) do
    Emakola.Customers.Address
    |> Ash.Query.filter(customer_id == ^customer.id and is_default == true)
    |> Ash.read!()
    |> List.first()
    |> case do
      nil -> nil
      address -> address_to_map(address)
    end
  end

  defp address_to_map(address) do
    %{
      "first_name" => address.first_name,
      "last_name" => address.last_name,
      "line_1" => address.line_1,
      "line_2" => address.line_2,
      "city" => address.city,
      "region" => address.region,
      "country" => address.country,
      "postal_code" => address.postal_code,
      "phone" => address.phone
    }
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

  defp run_checkout(store_id, items, variants, customer_id, resolved_address, opts) do
    # Determine shipping address: explicit opts > resolved default > nil
    shipping_address =
      Keyword.get(opts, :shipping_address) || resolved_address

    Emakola.Repo.transaction(fn ->
      # 1. Create order
      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          customer_id: customer_id,
          notes: Keyword.get(opts, :notes),
          shipping_address: shipping_address,
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

      # 3. Calculate totals (include delivery fee if provided)
      subtotal = Enum.reduce(line_items, 0, fn li, acc -> acc + li.line_total end)
      delivery_fee = Keyword.get(opts, :delivery_fee, 0)
      total = subtotal + delivery_fee

      order =
        order
        |> Ash.Changeset.for_update(:update, %{subtotal: subtotal, total: total})
        |> Ash.update!()

      # 4. Touch customer's last_order_at
      if customer_id do
        customer = Ash.get!(Emakola.Customers.Customer, customer_id)

        customer
        |> Ash.Changeset.for_update(:touch_last_order)
        |> Ash.update!()
      end

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
