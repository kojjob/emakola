defmodule Emakola.Orders.CheckoutService do
  @moduledoc """
  Orchestrates the checkout process: resolves customer, validates cart items,
  creates the order and line items, decrements stock, and calculates totals.

  Customer resolution: accepts either `customer_id` (backward compatible)
  or `customer_email` (find-or-create). When using customer_email, the
  customer's default address is used as shipping address if none provided.

  All operations — including customer creation — run inside an Ecto
  transaction so a failure at any step rolls everything back.
  """

  require Ash.Query
  require Logger

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
      - `:delivery_fee` — integer in minor units (optional, default 0)

  ## Returns
    - `{:ok, order}` on success
    - `{:error, reason}` on failure
  """
  def checkout!(store_id, items, opts) do
    with :ok <- validate_cart(items),
         {:ok, variants} <- load_and_validate_variants(store_id, items),
         :ok <- validate_stock(variants, items) do
      case run_checkout(store_id, items, variants, opts) do
        {:ok, order} ->
          # Dispatch notification outside the transaction. Dispatcher is
          # guaranteed not to raise; we log but never fail the checkout
          # on a notification subsystem error.
          case Emakola.Notifications.Dispatcher.dispatch(order, :order_placed) do
            {:ok, _job} ->
              :ok

            {:error, reason} ->
              Logger.error(
                "[checkout] order_placed notification dispatch failed: #{inspect(reason)}",
                order_id: order.id,
                store_id: store_id
              )
          end

          {:ok, order}

        error ->
          error
      end
    end
  end

  @doc """
  Validates a coupon code for a given store and subtotal.

  Returns `{:ok, coupon}` if the coupon is valid, or `{:error, reason}` with
  a descriptive atom if validation fails.
  """
  def validate_coupon(store_id, code, subtotal) do
    case Emakola.Marketing.Coupon
         |> Ash.Query.filter(store_id == ^store_id and code == ^String.upcase(code))
         |> Ash.read(authorize?: false) do
      {:ok, [coupon]} -> check_coupon_validity(coupon, subtotal)
      {:ok, []} -> {:error, :coupon_not_found}
      _ -> {:error, :coupon_not_found}
    end
  end

  @doc """
  Calculates discount amount in pesewas.

  - `:percentage` -- discount_value is basis points (1000 = 10%). Integer
    division truncates (rounds down) in the merchant's favor.
  - `:fixed_amount` -- discount_value is pesewas, capped at subtotal.
  - `:free_shipping` -- returns the delivery fee amount.
  """
  def calculate_discount(%{discount_type: :percentage} = coupon, subtotal, _delivery_fee) do
    raw = div(subtotal * coupon.discount_value, 10_000)
    if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw
  end

  def calculate_discount(%{discount_type: :fixed_amount} = coupon, subtotal, _delivery_fee) do
    min(coupon.discount_value, subtotal)
  end

  def calculate_discount(%{discount_type: :free_shipping}, _subtotal, delivery_fee) do
    delivery_fee
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
      |> Ash.read!(authorize?: false)

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
        # Dropshipped / intentionally untracked variants have no numeric stock
        # to check — only tracked own-stock is gated here.
        variant.track_inventory and variant.stock_quantity < qty
      end)

    if insufficient, do: {:error, :insufficient_stock}, else: :ok
  end

  defp check_coupon_validity(coupon, subtotal) do
    now = DateTime.utc_now()

    cond do
      not coupon.active ->
        {:error, :coupon_inactive}

      coupon.expires_at && DateTime.compare(now, coupon.expires_at) == :gt ->
        {:error, :coupon_expired}

      coupon.starts_at && DateTime.compare(now, coupon.starts_at) == :lt ->
        {:error, :coupon_not_started}

      coupon.max_uses && coupon.uses_count >= coupon.max_uses ->
        {:error, :coupon_max_uses_reached}

      coupon.minimum_order_amount && subtotal < coupon.minimum_order_amount ->
        {:error, :coupon_minimum_not_met}

      true ->
        {:ok, coupon}
    end
  end

  # -- Transaction -----------------------------------------------------

  defp run_checkout(store_id, items, variants, opts) do
    Emakola.Repo.transaction(fn ->
      # 1. Resolve customer INSIDE the transaction
      {customer_id, resolved_address} = resolve_customer(store_id, opts)

      # 2. Determine shipping address: explicit opts > resolved default > nil
      shipping_address =
        Keyword.get(opts, :shipping_address) || resolved_address

      # 3. Create line items first to compute subtotal before order creation
      #    (we need subtotal for coupon validation)
      #    Create a temporary order to hold line items
      order =
        Emakola.Orders.Order
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          customer_id: customer_id,
          notes: Keyword.get(opts, :notes),
          shipping_address: shipping_address,
          billing_address: Keyword.get(opts, :billing_address),
          attribution: Keyword.get(opts, :attribution, %{})
        })
        |> Ash.create!(authorize?: false)

      # Split the order into one fulfillment per distinct supplier_id
      # (including the nil key for merchant-owned/own-stock items).
      fulfillment_ids = create_fulfillments(store_id, order.id, items, variants)

      # 4. Create line items and decrement stock for tracked variants only
      line_items =
        Enum.map(items, fn %{variant_id: vid, quantity: qty} ->
          variant = Map.fetch!(variants, vid)

          line_item =
            Emakola.Orders.LineItem
            |> Ash.Changeset.for_create(:create, %{
              order_id: order.id,
              store_id: store_id,
              variant_id: vid,
              quantity: qty,
              fulfillment_id: Map.fetch!(fulfillment_ids, variant.supplier_id)
            })
            |> Ash.create!(authorize?: false)

          # Dropshipped / untracked variants carry no numeric stock to decrement.
          if variant.track_inventory do
            variant
            |> Ash.Changeset.for_update(:adjust_stock, %{delta: -qty})
            |> Ash.update!(authorize?: false)
          end

          line_item
        end)

      # 4a. Record what we owe each supplier for their dropship fulfillment.
      create_ledger_entries(store_id, items, variants, fulfillment_ids)

      # 4b. Check for low-stock threshold crossings and enqueue alerts
      check_low_stock_alerts(store_id, items, variants)

      # 5. Calculate totals (include delivery fee and coupon discount)
      subtotal = Enum.reduce(line_items, 0, fn li, acc -> acc + li.line_total end)
      delivery_fee = Keyword.get(opts, :delivery_fee, 0)

      # 6. Re-validate and apply coupon inside the transaction
      {coupon_id, discount_amount} =
        case Keyword.get(opts, :coupon_id) do
          nil ->
            {nil, 0}

          cid ->
            coupon = Ash.get!(Emakola.Marketing.Coupon, cid, authorize?: false)

            case check_coupon_validity(coupon, subtotal) do
              {:ok, valid_coupon} ->
                discount = calculate_discount(valid_coupon, subtotal, delivery_fee)

                valid_coupon
                |> Ash.Changeset.for_update(:increment_usage, %{})
                |> Ash.update!(authorize?: false)

                {valid_coupon.id, discount}

              {:error, reason} ->
                Emakola.Repo.rollback(reason)
            end
        end

      total = subtotal + delivery_fee - discount_amount

      order =
        order
        |> Ash.Changeset.for_update(:update, %{
          subtotal: subtotal,
          total: total,
          delivery_fee: delivery_fee,
          discount_amount: discount_amount,
          coupon_id: coupon_id
        })
        |> Ash.update!(authorize?: false)

      # 7. Touch customer's last_order_at
      if customer_id do
        customer = Ash.get!(Emakola.Customers.Customer, customer_id, authorize?: false)

        customer
        |> Ash.Changeset.for_update(:touch_last_order)
        |> Ash.update!(authorize?: false)
      end

      order
    end)
  rescue
    # Concurrent oversell: two checkouts both pass the upfront stock check,
    # both attempt to decrement, and the second hits the DB CHECK constraint
    # `stock_non_negative` (defined on `variants` in Catalog.Variant). Ash
    # surfaces this as Ash.Error.Invalid; we inspect for the stock signature
    # to disambiguate from unrelated validation failures.
    e in Ash.Error.Invalid ->
      if stock_constraint_violation?(e) do
        {:error, :insufficient_stock}
      else
        Logger.error("[checkout] validation error during transaction: #{Exception.message(e)}")
        {:error, :checkout_failed}
      end

    # Ecto raises StaleEntryError when a row the transaction depends on has
    # been modified concurrently (e.g., optimistic-lock mismatch on stock).
    _e in Ecto.StaleEntryError ->
      {:error, :insufficient_stock}
  end

  @doc false
  # Public for unit testing via `@doc false` convention. Recognises the
  # `stock_non_negative` DB CHECK constraint violation (or any
  # stock_quantity-related error) inside an Ash.Error.Invalid aggregate.
  def stock_constraint_violation?(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    Enum.any?(errors, &stock_related_error?/1)
  end

  def stock_constraint_violation?(_), do: false

  defp stock_related_error?(%{constraint: "stock_non_negative"}), do: true
  defp stock_related_error?(%{field: :stock_quantity}), do: true

  defp stock_related_error?(%{message: msg}) when is_binary(msg),
    do: String.contains?(msg, "stock")

  defp stock_related_error?(_), do: false

  # -- Customer resolution (called inside transaction) -----------------

  defp resolve_customer(store_id, opts) when is_list(opts) do
    cond do
      Keyword.has_key?(opts, :customer_id) ->
        {Keyword.get(opts, :customer_id), nil}

      Keyword.has_key?(opts, :customer_email) ->
        customer = find_or_create_customer!(store_id, opts)
        default_address = resolve_default_address(customer)
        {customer.id, default_address}

      true ->
        {nil, nil}
    end
  end

  defp find_or_create_customer!(store_id, opts) do
    Emakola.Customers.Customer
    |> Ash.ActionInput.for_action(:find_or_create, %{
      email: Keyword.get(opts, :customer_email),
      store_id: store_id,
      name: Keyword.get(opts, :customer_name),
      phone: Keyword.get(opts, :customer_phone)
    })
    |> Ash.run_action!()
  end

  defp resolve_default_address(customer) do
    Emakola.Customers.Address
    |> Ash.Query.filter(customer_id == ^customer.id and is_default == true)
    |> Ash.read!(authorize?: false)
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

  # -- Fulfillment split --------------------------------------------------

  # Creates one Fulfillment per distinct supplier_id across the cart's
  # variants (the nil key is the merchant-owned/own-stock group). Returns a
  # map of `supplier_id => fulfillment_id` for line-item assignment.
  defp create_fulfillments(store_id, order_id, items, variants) do
    items
    |> Enum.map(fn %{variant_id: vid} -> Map.fetch!(variants, vid).supplier_id end)
    |> Enum.uniq()
    |> Map.new(fn supplier_id ->
      fulfillment =
        Emakola.Orders.Fulfillment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          order_id: order_id,
          supplier_id: supplier_id,
          status: :pending
        })
        |> Ash.create!(authorize?: false)

      {supplier_id, fulfillment.id}
    end)
  end

  # -- Supplier payout ledger ---------------------------------------------

  # Creates one SupplierLedgerEntry per non-nil supplier, recording the total
  # supplier cost owed for that supplier's fulfillment. The nil-supplier
  # merchant group is skipped (nothing is owed to an external supplier).
  defp create_ledger_entries(store_id, items, variants, fulfillment_ids) do
    items
    |> Enum.group_by(fn %{variant_id: vid} -> Map.fetch!(variants, vid).supplier_id end)
    |> Enum.each(fn
      {nil, _group_items} ->
        :ok

      {supplier_id, group_items} ->
        amount_owed =
          Enum.reduce(group_items, 0, fn %{variant_id: vid, quantity: qty}, acc ->
            cost = Map.fetch!(variants, vid).cost_price || 0
            acc + cost * qty
          end)

        Emakola.Suppliers.SupplierLedgerEntry
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          supplier_id: supplier_id,
          fulfillment_id: Map.fetch!(fulfillment_ids, supplier_id),
          amount_owed: amount_owed,
          status: :owed
        })
        |> Ash.create!(authorize?: false)
    end)
  end

  # -- Low-stock alert detection ------------------------------------------

  @low_stock_threshold 10

  defp check_low_stock_alerts(store_id, items, variants) do
    Enum.each(items, fn %{variant_id: vid, quantity: qty} ->
      variant = Map.fetch!(variants, vid)
      new_stock = variant.stock_quantity - qty

      if variant.track_inventory and new_stock < @low_stock_threshold and
           not variant.low_stock_alerted do
        # Flag the variant so we don't alert again
        variant
        |> Ash.Changeset.for_update(:set_low_stock_alerted, %{})
        |> Ash.update!(authorize?: false)

        # Enqueue real-time SMS/WhatsApp alert
        %{"variant_id" => vid, "store_id" => store_id}
        |> Emakola.Inventory.Workers.LowStockSmsWorker.new()
        |> Oban.insert!()
      end
    end)
  end
end
