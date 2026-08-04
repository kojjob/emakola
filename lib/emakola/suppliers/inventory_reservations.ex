defmodule Emakola.Suppliers.InventoryReservations do
  @moduledoc "Transparent passport-tier stock holds with atomic release back to supplier inventory."

  require Ash.Query
  require Logger

  alias Emakola.Suppliers.{CommercePassports, InventoryEligibilityPolicy, InventoryReservation}

  @tier_rank %{starter: 0, reliable: 1, proven: 2}

  def create_policy(actor, supplier_store_id, offer_variant_id, attrs) do
    with :ok <- ensure_store_access(actor, supplier_store_id),
         {:ok, offer_variant} <-
           Ash.get(Emakola.Suppliers.SupplierOfferVariant, offer_variant_id, authorize?: false),
         true <- offer_variant.wholesaler_store_id == supplier_store_id,
         {:ok, minimum_tier} <- tier(value(attrs, :minimum_tier)),
         {:ok, max_quantity} <-
           bounded_integer(value(attrs, :max_quantity_per_reseller), 1, 10_000),
         {:ok, hours} <- bounded_integer(value(attrs, :reservation_hours), 1, 720) do
      InventoryEligibilityPolicy
      |> Ash.Changeset.for_create(:create, %{
        supplier_store_id: supplier_store_id,
        offer_variant_id: offer_variant.id,
        minimum_tier: minimum_tier,
        max_quantity_per_reseller: max_quantity,
        reservation_hours: hours,
        reason_code: "PASSPORT_TIER_#{minimum_tier |> Atom.to_string() |> String.upcase()}"
      })
      |> Ash.create(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def eligible_policies(actor, reseller_store_id) do
    with :ok <- ensure_store_access(actor, reseller_store_id),
         {:ok, passport} <- CommercePassports.inspect(actor, reseller_store_id) do
      policies =
        InventoryEligibilityPolicy
        |> Ash.Query.filter(active == true)
        |> Ash.Query.load(offer_variant: [:source_variant, offer: :source_product])
        |> Ash.read!(authorize?: false)
        |> Enum.filter(fn policy ->
          connected?(policy.supplier_store_id, reseller_store_id) and
            tier_eligible?(passport.tier, policy.minimum_tier)
        end)

      {:ok, policies}
    end
  end

  def owned_policies(actor, supplier_store_id) do
    with :ok <- ensure_store_access(actor, supplier_store_id) do
      policies =
        InventoryEligibilityPolicy
        |> Ash.Query.filter(supplier_store_id == ^supplier_store_id)
        |> Ash.Query.load(offer_variant: [:source_variant, offer: :source_product])
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(authorize?: false)

      {:ok, policies}
    end
  end

  def reserve(actor, reseller_store_id, policy_id, quantity) do
    with :ok <- ensure_store_access(actor, reseller_store_id),
         {:ok, quantity} <- bounded_integer(quantity, 1, 10_000),
         {:ok, policy} <- load_policy(policy_id),
         true <- policy.active,
         true <- connected?(policy.supplier_store_id, reseller_store_id),
         {:ok, passport} <- CommercePassports.inspect(actor, reseller_store_id),
         :ok <- passport_current?(passport),
         true <- tier_eligible?(passport.tier, policy.minimum_tier) do
      create_reservation(policy, passport, reseller_store_id, quantity)
    else
      false -> {:error, :not_eligible}
      error -> error
    end
  end

  def list(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      reservations =
        InventoryReservation
        |> Ash.Query.filter(reseller_store_id == ^store_id or supplier_store_id == ^store_id)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(authorize?: false)

      {:ok, reservations}
    end
  end

  def release(actor, store_id, reservation_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, reservation} <- Ash.get(InventoryReservation, reservation_id, authorize?: false),
         true <- store_id in [reservation.reseller_store_id, reservation.supplier_store_id] do
      release_reservation(reservation, :released)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def expire_due do
    now = DateTime.utc_now()

    InventoryReservation
    |> Ash.Query.filter(status == :active and expires_at <= ^now)
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn reservation ->
      try do
        release_reservation(reservation, :expired)
      rescue
        exception ->
          Logger.error(
            "[InventoryReservations] expire failed for #{reservation.id}: " <>
              Exception.message(exception)
          )
      end
    end)

    :ok
  end

  def consume_for_order(nil, _store_id), do: :ok

  def consume_for_order(order_id, store_id) do
    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order_id)
      |> Ash.read!(authorize?: false, tenant: store_id)

    Enum.each(line_items, &consume_line(&1, order_id, store_id))
    :ok
  end

  @doc """
  Returns reservation-covered units consumed by a fully refunded order to the
  supplier's available stock.

  Consumption rows remain immutable audit records. Matching
  `:reservation_refund` stock movements are the idempotency ledger, so a
  webhook replay restores no units twice. The reservation's consumed count is
  intentionally retained: any later release/expiry returns only its unused
  remainder, while the refund movement already returned this order's portion.
  """
  @spec restore_for_refunded_order(binary()) :: {:ok, non_neg_integer()} | {:error, term()}
  def restore_for_refunded_order(order_id) when is_binary(order_id) do
    Emakola.Repo.transaction(fn ->
      targets = reservation_refund_targets(order_id)
      restored = reservation_refund_credits(order_id)

      targets
      |> Enum.sort_by(fn {{variant_id, _store_id}, _quantity} -> variant_id end)
      |> Enum.reduce(0, fn {{variant_id, store_id}, quantity}, total ->
        to_restore = Kernel.max(quantity - Map.get(restored, variant_id, 0), 0)

        if to_restore > 0 do
          location = Emakola.Inventory.ensure_default_location!(store_id)

          {:ok, :adjusted} =
            Emakola.Inventory.adjust(
              variant_id,
              location.id,
              to_restore,
              :reservation_refund,
              order_id: order_id
            )

          total + to_restore
        else
          total
        end
      end)
    end)
    |> normalize_transaction()
  end

  def restore_for_refunded_order(_order_id), do: {:error, :invalid_order_id}

  defp create_reservation(policy, passport, reseller_store_id, quantity) do
    Emakola.Repo.transaction(fn ->
      source_variant = locked_variant!(policy.offer_variant.source_variant_id)
      already_reserved = active_quantity(policy.id, reseller_store_id)

      cond do
        already_reserved + quantity > policy.max_quantity_per_reseller ->
          Emakola.Repo.rollback(:reseller_limit_exceeded)

        not source_variant.track_inventory ->
          Emakola.Repo.rollback(:inventory_not_tracked)

        source_variant.stock_quantity < quantity ->
          Emakola.Repo.rollback(:insufficient_inventory)

        true ->
          # Funnel through the Inventory domain (hold at the supplier's
          # default location) so total==sum(levels) holds and the ledger
          # records the hold. Same-transaction re-lock is re-entrant.
          hold_location = Emakola.Inventory.ensure_default_location!(policy.supplier_store_id)

          {:ok, _} =
            Emakola.Inventory.adjust(
              source_variant.id,
              hold_location.id,
              -quantity,
              :reservation_hold
            )

          now = DateTime.utc_now()

          InventoryReservation
          |> Ash.Changeset.for_create(:create, %{
            policy_id: policy.id,
            passport_id: passport.id,
            supplier_store_id: policy.supplier_store_id,
            reseller_store_id: reseller_store_id,
            offer_variant_id: policy.offer_variant_id,
            source_variant_id: source_variant.id,
            quantity: quantity,
            reason_code: policy.reason_code,
            eligibility_snapshot: %{
              "passport_score" => passport.score,
              "passport_tier" => Atom.to_string(passport.tier),
              "minimum_tier" => Atom.to_string(policy.minimum_tier),
              "max_quantity_per_reseller" => policy.max_quantity_per_reseller
            },
            reserved_at: now,
            expires_at: DateTime.add(now, policy.reservation_hours, :hour)
          })
          |> Ash.create!(authorize?: false)
      end
    end)
    |> normalize_transaction()
  end

  defp reservation_refund_targets(order_id) do
    Emakola.Suppliers.InventoryReservationConsumption
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(%{}, fn consumption, targets ->
      reservation = Ash.get!(InventoryReservation, consumption.reservation_id, authorize?: false)
      key = {reservation.source_variant_id, reservation.supplier_store_id}
      Map.update(targets, key, consumption.quantity, &(&1 + consumption.quantity))
    end)
  end

  defp reservation_refund_credits(order_id) do
    Emakola.Inventory.StockMovement
    |> Ash.Query.filter(order_id == ^order_id and reason == :reservation_refund and delta > 0)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(%{}, fn movement, credits ->
      Map.update(credits, movement.variant_id, movement.delta, &(&1 + movement.delta))
    end)
  end

  defp consume_line(line_item, order_id, store_id) do
    mapping =
      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(reseller_variant_id == ^line_item.variant_id)
      |> Ash.read_one!(authorize?: false)

    if mapping do
      already_consumed =
        Emakola.Suppliers.InventoryReservationConsumption
        |> Ash.Query.filter(line_item_id == ^line_item.id)
        |> Ash.read!(authorize?: false)
        |> Enum.reduce(0, &(&1.quantity + &2))

      needed = max(line_item.quantity - already_consumed, 0)

      if needed > 0 do
        reservations =
          InventoryReservation
          |> Ash.Query.filter(
            reseller_store_id == ^store_id and offer_variant_id == ^mapping.offer_variant_id and
              status == :active and expires_at > ^DateTime.utc_now()
          )
          |> Ash.Query.sort(reserved_at: :asc)
          |> Ash.read!(authorize?: false)

        Enum.reduce_while(reservations, needed, fn reservation, remaining ->
          if remaining == 0 do
            {:halt, 0}
          else
            available = reservation.quantity - reservation.consumed_quantity
            take = min(available, remaining)

            if take > 0, do: record_consumption(reservation, line_item, order_id, take)
            {:cont, remaining - take}
          end
        end)
      end
    end
  end

  defp record_consumption(reservation, line_item, order_id, quantity) do
    Emakola.Repo.transaction(fn ->
      reservation = locked_reservation!(reservation.id)

      existing =
        Emakola.Suppliers.InventoryReservationConsumption
        |> Ash.Query.filter(reservation_id == ^reservation.id and line_item_id == ^line_item.id)
        |> Ash.read_one!(authorize?: false)

      unless existing do
        consumed = min(reservation.consumed_quantity + quantity, reservation.quantity)

        Emakola.Suppliers.InventoryReservationConsumption
        |> Ash.Changeset.for_create(:create, %{
          reservation_id: reservation.id,
          order_id: order_id,
          line_item_id: line_item.id,
          quantity: consumed - reservation.consumed_quantity,
          consumed_at: DateTime.utc_now()
        })
        |> Ash.create!(authorize?: false)

        reservation
        |> Ash.Changeset.for_update(:record_consumption, %{
          consumed_quantity: consumed,
          status: if(consumed == reservation.quantity, do: :consumed, else: :active)
        })
        |> Ash.update!(authorize?: false)
      end
    end)
  end

  # Dispatches on the FRESH row status under FOR UPDATE — a stale struct from a
  # sweep batch or a concurrent release can no longer restore stock twice, and
  # `remaining` reflects consumption that happened after the caller's read.
  defp release_reservation(%{id: id}, status) when status in [:released, :expired] do
    Emakola.Repo.transaction(fn ->
      reservation = locked_reservation!(id)

      if reservation.status == :active do
        remaining = reservation.quantity - reservation.consumed_quantity

        if remaining > 0 do
          release_location =
            Emakola.Inventory.ensure_default_location!(reservation.supplier_store_id)

          {:ok, _} =
            Emakola.Inventory.adjust(
              reservation.source_variant_id,
              release_location.id,
              remaining,
              :reservation_release
            )
        end

        reservation
        |> Ash.Changeset.for_update(:release, %{status: status})
        |> Ash.update!(authorize?: false)
      else
        reservation
      end
    end)
    |> normalize_transaction()
  end

  defp load_policy(id) do
    case Ash.get(InventoryEligibilityPolicy, id, authorize?: false) do
      {:ok, policy} ->
        Ash.load(policy, [offer_variant: [:source_variant, offer: :source_product]],
          authorize?: false
        )

      error ->
        error
    end
  end

  defp active_quantity(policy_id, reseller_store_id) do
    InventoryReservation
    |> Ash.Query.filter(
      policy_id == ^policy_id and reseller_store_id == ^reseller_store_id and status == :active
    )
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.quantity - &1.consumed_quantity + &2))
  end

  defp locked_variant!(id) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp locked_reservation!(id) do
    InventoryReservation
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp connected?(supplier_store_id, reseller_store_id) do
    Emakola.Suppliers.SupplyConnection
    |> Ash.Query.filter(
      wholesaler_store_id == ^supplier_store_id and reseller_store_id == ^reseller_store_id and
        status == :active
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Enum.any?()
  end

  defp passport_current?(passport),
    do:
      if(DateTime.compare(passport.expires_at, DateTime.utc_now()) == :gt,
        do: :ok,
        else: {:error, :passport_expired}
      )

  defp tier_eligible?(actual, minimum),
    do: Map.fetch!(@tier_rank, actual) >= Map.fetch!(@tier_rank, minimum)

  defp tier(value) when value in [:starter, :reliable, :proven], do: {:ok, value}

  defp tier(value) when is_binary(value),
    do:
      Enum.find_value(Map.keys(@tier_rank), {:error, :invalid_tier}, fn tier ->
        if Atom.to_string(tier) == value, do: {:ok, tier}
      end)

  defp tier(_), do: {:error, :invalid_tier}

  defp bounded_integer(value, min, max) when is_integer(value) and value >= min and value <= max,
    do: {:ok, value}

  defp bounded_integer(value, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> bounded_integer(number, min, max)
      _ -> {:error, :invalid_number}
    end
  end

  defp bounded_integer(_, _, _), do: {:error, :invalid_number}
  defp value(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_, _), do: {:error, :forbidden}
end
