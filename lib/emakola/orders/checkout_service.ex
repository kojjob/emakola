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
      - `:region` — snake_case Ghana region param (optional; resolves
        supplier dispatch fees via `GhanaRegions.from_param/1` — absent or
        unresolvable means all dispatch fees are 0)

  ## Returns
    - `{:ok, order}` on success
    - `{:error, reason}` on failure
  """
  def checkout!(store_id, items, opts) do
    with :ok <- validate_cart(items),
         {:ok, variants} <- load_and_validate_variants(store_id, items),
         :ok <- Emakola.Suppliers.NetworkCheckoutEligibility.validate(store_id, variants, opts),
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
    capped = if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw
    # Never discount more than the subtotal, or the order total would go
    # negative (defence in depth if a coupon slips past the 100% cap).
    min(capped, subtotal)
  end

  def calculate_discount(%{discount_type: :fixed_amount} = coupon, subtotal, _delivery_fee) do
    min(coupon.discount_value, subtotal)
  end

  def calculate_discount(%{discount_type: :free_shipping}, _subtotal, delivery_fee) do
    delivery_fee
  end

  @doc """
  Per-supplier dispatch fees for a cart, pesewas. MAX across the supplier's
  offers in the cart (one parcel per supplier per order — locked decision),
  0 for unquoted regions, "other", or unresolvable listings. Pure: region
  resolution via GhanaRegions.from_param/1.
  """
  def dispatch_fees_for(items, variants, region_param) do
    case Emakola.Suppliers.GhanaRegions.from_param(region_param) do
      nil ->
        %{}

      region ->
        supplier_variant_ids =
          items
          |> Enum.map(& &1.variant_id)
          |> Enum.filter(fn vid -> Map.fetch!(variants, vid).supplier_id != nil end)

        fees_by_supplier(supplier_variant_ids, region)
    end
  end

  defp fees_by_supplier([], _region), do: %{}

  defp fees_by_supplier(variant_ids, region) do
    listing_variants =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id in ^variant_ids)
      |> Ash.Query.load(listing: :offer)
      |> Ash.read!(authorize?: false)

    listing_variants
    |> Enum.group_by(& &1.listing.supplier_id)
    |> Map.new(fn {supplier_id, lvs} ->
      max_fee =
        lvs
        |> Enum.map(fn lv -> Map.get(lv.listing.offer.dispatch_fees || %{}, region, 0) end)
        |> Enum.max(fn -> 0 end)

      {supplier_id, max_fee}
    end)
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

      Enum.any?(variants, fn v -> not product_available?(v.product) end) ->
        {:error, :product_unavailable}

      true ->
        {:ok, Map.new(variants, fn v -> {v.id, v} end)}
    end
  end

  # A variant can't be ordered once its product has been REMOVED from sale —
  # archived by the merchant or taken down by platform moderation. The storefront
  # only lets an `:active` product into a cart (Catalog `get_active_product`), and
  # an active product has no transition back to `:draft` — so these two states are
  # exactly the stale-cart hazards: a product live when added, removed before
  # checkout. This stops a taken-down (e.g. counterfeit) item being bought anyway.
  defp product_available?(%{status: :archived}), do: false
  defp product_available?(%{moderation_status: moderation}) when moderation != :ok, do: false
  defp product_available?(_), do: true

  defp validate_stock(variants, items) do
    insufficient =
      Enum.any?(items, fn %{variant_id: vid, quantity: qty} ->
        variant = Map.fetch!(variants, vid)
        not available_for_order?(variant, qty)
      end)

    if insufficient, do: {:error, :insufficient_stock}, else: :ok
  end

  # A dropship (supplier-fulfilled) variant the supplier marked unavailable is
  # out of stock regardless of its numeric quantity — Variant.in_stock?/2 alone
  # treats every untracked variant as available, so it misses this. Mirrors
  # Inventory.stock_status, the rule the storefront uses.
  defp available_for_order?(%{supplier_id: sid, available: false}, _qty)
       when not is_nil(sid),
       do: false

  defp available_for_order?(variant, qty), do: Emakola.Catalog.Variant.in_stock?(variant, qty)

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

      # Per-supplier dispatch fees for the customer's region, resolved once
      # inside the transaction — never accepted as a client-supplied amount.
      dispatch_fees = dispatch_fees_for(items, variants, Keyword.get(opts, :region))

      # Split the order into one fulfillment per distinct supplier_id
      # (including the nil key for merchant-owned/own-stock items).
      fulfillment_ids = create_fulfillments(store_id, order.id, items, variants, dispatch_fees)

      # 4. Create line items. Stock is NOT decremented here — it's reserved
      #    nowhere at checkout and decremented only when payment confirms the
      #    order (Order :confirm -> Changes.DecrementStock), so an abandoned or
      #    unpaid order never bleeds inventory.
      line_items =
        Enum.map(items, fn %{variant_id: vid, quantity: qty} ->
          variant = Map.fetch!(variants, vid)

          Emakola.Orders.LineItem
          |> Ash.Changeset.for_create(:create, %{
            order_id: order.id,
            store_id: store_id,
            variant_id: vid,
            quantity: qty,
            fulfillment_id: Map.fetch!(fulfillment_ids, variant.supplier_id)
          })
          |> Ash.create!(authorize?: false)
        end)

      # 4a. Record what we owe each supplier for their dropship fulfillment,
      #     including their dispatch fee.
      create_ledger_entries(store_id, items, variants, fulfillment_ids, dispatch_fees)

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

      dispatch_fee_total = dispatch_fees |> Map.values() |> Enum.sum()
      total = subtotal + delivery_fee + dispatch_fee_total - discount_amount

      order =
        order
        |> Ash.Changeset.for_update(:update, %{
          subtotal: subtotal,
          total: total,
          delivery_fee: delivery_fee,
          discount_amount: discount_amount,
          dispatch_fee_total: dispatch_fee_total,
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
  # map of `supplier_id => fulfillment_id` for line-item assignment. Each
  # fulfillment snapshots its supplier's dispatch fee (0 for the nil group).
  defp create_fulfillments(store_id, order_id, items, variants, dispatch_fees) do
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
          status: :pending,
          dispatch_fee: Map.get(dispatch_fees, supplier_id, 0)
        })
        |> Ash.create!(authorize?: false)

      {supplier_id, fulfillment.id}
    end)
  end

  # -- Supplier payout ledger ---------------------------------------------

  # Creates one SupplierLedgerEntry per non-nil supplier, recording the total
  # supplier cost owed for that supplier's fulfillment plus their dispatch
  # fee (added once per supplier, not per line). The nil-supplier merchant
  # group is skipped (nothing is owed to an external supplier).
  defp create_ledger_entries(store_id, items, variants, fulfillment_ids, dispatch_fees) do
    items
    |> Enum.group_by(fn %{variant_id: vid} -> Map.fetch!(variants, vid).supplier_id end)
    |> Enum.each(fn
      {nil, _group_items} ->
        :ok

      {supplier_id, group_items} ->
        cost_sum =
          Enum.reduce(group_items, 0, fn %{variant_id: vid, quantity: qty}, acc ->
            cost = Map.fetch!(variants, vid).cost_price || 0
            acc + cost * qty
          end)

        amount_owed = cost_sum + Map.get(dispatch_fees, supplier_id, 0)

        # Skip suppliers with no recorded cost and no dispatch fee — a
        # zero-amount entry would be a misleading "owed" record. The
        # fulfillment itself still exists.
        if amount_owed > 0 do
          Emakola.Suppliers.SupplierLedgerEntry
          |> Ash.Changeset.for_create(:create, %{
            store_id: store_id,
            supplier_id: supplier_id,
            fulfillment_id: Map.fetch!(fulfillment_ids, supplier_id),
            amount_owed: amount_owed,
            status: :owed
          })
          |> Ash.create!(authorize?: false)
        end
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
