defmodule Emakola.Payments.RefundLiability do
  @moduledoc """
  Reconciles cumulative payment refunds into the existing split ledger.

  Each recipient's reversal is proportional to its original allocation. The
  `PaymentSplit.reversed_amount` is the recoverable balance source of truth,
  making partial refunds cumulative without duplicating the allocation ledger.

  Future gateway splits reserve that debt before payment initiation. The
  recipient's share is reduced by the reserved amount and the platform
  remainder grows by the same amount, preserving the charge total. A successful
  charge applies the reservation; a failed initiation releases it.
  """

  require Ash.Query

  alias Emakola.Orders.Fulfillment
  alias Emakola.Payments.PaymentSplit

  @dispatched_statuses [:shipped, :delivered]

  # Targets are cumulative-quota differences (not per-split floors), so the
  # reversals sum exactly to the splits' proportional share of the refund —
  # per-split flooring silently dropped up to n-1 pesewas per partial refund.
  def reconcile!(payment, splits) do
    splits
    |> Enum.sort_by(& &1.id)
    |> with_reversible_bases(payment)
    |> Enum.reduce({0, 0}, fn {split, base}, {base_before, target_before} ->
      base_after = base_before + base

      target_after =
        proportional_amount(base_after, payment.refunded_amount, payment.amount)

      reversed_amount = target_after - target_before

      if reversed_amount > split.reversed_amount do
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
        |> Ash.update!(authorize?: false)
      end

      {base_after, target_after}
    end)

    :ok
  end

  # A supplier that already dispatched keeps its dispatch fee: the courier cost
  # is spent whether or not the customer gets refunded. The fee is subtracted
  # from that wholesaler's reversible base and added to the dropshipper's, so
  # the merchant who chose to refund absorbs that portion of the reversal.
  # Redistribution leaves the total untouched — `Σ base == payment.amount` is
  # exactly what keeps the reversals summing to `payment.refunded_amount`.
  defp with_reversible_bases(splits, payment) do
    unprotected = Enum.map(splits, &{&1, &1.amount})

    if is_nil(payment.order_id) do
      unprotected
    else
      apply_protection(splits, unprotected, payment.order_id)
    end
  end

  defp apply_protection(splits, unprotected, order_id) do
    fees = protected_fees(splits, order_id)
    total = fees |> Map.values() |> Enum.sum()
    dropshipper = Enum.find(splits, &(&1.role == :dropshipper))

    if total == 0 or is_nil(dropshipper) or dispatch_fee_waived?(order_id) do
      unprotected
    else
      Enum.map(splits, fn split ->
        if split.id == dropshipper.id do
          {split, split.amount + total}
        else
          {split, split.amount - Map.get(fees, split.id, 0)}
        end
      end)
    end
  end

  # One fulfillment query per reconcile, never one per split. Merchant-owned
  # groups (nil supplier_id) have no supplier to protect.
  defp protected_fees(splits, order_id) do
    fees =
      Fulfillment
      |> Ash.Query.filter(
        order_id == ^order_id and status in ^@dispatched_statuses and dispatch_fee > 0 and
          not is_nil(supplier_id)
      )
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.supplier_id, &1.dispatch_fee})

    for %{role: :wholesaler, supplier_id: supplier_id} = split <- splits,
        is_map_key(fees, supplier_id),
        into: %{},
        # A fee larger than the allocation cannot claw back more than the
        # split holds — the base floors at zero, never negative.
        do: {split.id, min(fees[supplier_id], split.amount)}
  end

  # The merchant marked the supplier at fault, so protection is waived. Returns
  # are frequently absent; anything but an explicit waiver means "no waiver".
  defp dispatch_fee_waived?(order_id) do
    case Emakola.Orders.get_return_by_order(order_id, authorize?: false) do
      {:ok, [%{refund_dispatch_fee?: waived} | _]} -> waived
      _ -> false
    end
  end

  @doc "Reserves recipient liabilities and returns gateway-ready net allocations."
  def reserve!(allocations) do
    {:ok, adjusted} =
      Emakola.Repo.transaction(fn ->
        {recipient_allocations, recovered_total} =
          allocations
          |> Enum.sort_by(fn allocation ->
            recipient_store_id = Map.get(allocation, :recipient_store_id)
            {is_nil(recipient_store_id), recipient_store_id || ""}
          end)
          |> Enum.map_reduce(0, fn allocation, total ->
            reserve_for_allocation(allocation, total)
          end)

        add_to_platform(recipient_allocations, recovered_total)
      end)

    adjusted
  end

  @doc "Releases reservations when the gateway never accepted the payment."
  def release!(allocations) do
    {:ok, :ok} =
      Emakola.Repo.transaction(fn ->
        allocations
        |> Enum.flat_map(&breakdown_items/1)
        |> Enum.sort_by(& &1["split_id"])
        |> Enum.each(fn %{"split_id" => split_id, "amount" => amount} ->
          liability = locked_split!(split_id)

          update_tracking!(liability, %{
            reserved_recovery_amount: max(liability.reserved_recovery_amount - amount, 0)
          })
        end)
      end)

    :ok
  end

  @doc "Applies reserved recovery amounts after a successful customer charge."
  def apply_recoveries!(earning_splits) do
    earning_splits
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&apply_recovery!/1)

    :ok
  end

  @doc "Reopens applied recovery when its earning payment is later refunded."
  def rollback_recoveries!(payment, earning_splits) do
    earning_splits
    |> Enum.sort_by(& &1.id)
    |> Enum.each(&rollback_recovery!(payment, &1))

    :ok
  end

  defp reserve_for_allocation(%{recipient_store_id: nil} = allocation, total),
    do: {allocation, total}

  defp reserve_for_allocation(%{amount: amount} = allocation, total) when amount > 0 do
    liabilities =
      PaymentSplit
      |> Ash.Query.for_read(:recoverable_by_recipient, %{
        recipient_store_id: allocation.recipient_store_id
      })
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read!(authorize?: false)

    {items, recovered} = reserve_from_liabilities(liabilities, amount, [], 0)

    adjusted =
      allocation
      |> Map.put(:amount, amount - recovered)
      |> Map.put(:recovery_amount, recovered)
      |> Map.put(:recovery_breakdown, %{"items" => Enum.reverse(items)})

    {adjusted, total + recovered}
  end

  defp reserve_for_allocation(allocation, total), do: {allocation, total}

  defp reserve_from_liabilities(_liabilities, 0, items, recovered),
    do: {items, recovered}

  defp reserve_from_liabilities([], _available, items, recovered),
    do: {items, recovered}

  defp reserve_from_liabilities([liability | rest], available, items, recovered) do
    outstanding =
      liability.reversed_amount - liability.recovered_amount -
        liability.reserved_recovery_amount

    amount = min(outstanding, available)

    update_tracking!(liability, %{
      reserved_recovery_amount: liability.reserved_recovery_amount + amount
    })

    item = %{"split_id" => liability.id, "amount" => amount}
    reserve_from_liabilities(rest, available - amount, [item | items], recovered + amount)
  end

  defp add_to_platform(allocations, 0), do: allocations

  defp add_to_platform(allocations, recovered_total) do
    Enum.map(allocations, fn
      %{role: :platform} = allocation ->
        %{allocation | amount: allocation.amount + recovered_total}

      allocation ->
        allocation
    end)
  end

  defp apply_recovery!(%{recovery_amount: amount}) when amount <= 0, do: :ok

  defp apply_recovery!(earning_split) do
    {:ok, :ok} =
      Emakola.Repo.transaction(fn ->
        current = locked_split!(earning_split.id)
        remaining = current.recovery_amount - current.recovery_applied_amount

        if remaining > 0 do
          applied = apply_breakdown(breakdown_items(current), remaining, 0)

          update_tracking!(current, %{
            recovery_applied_amount: current.recovery_applied_amount + applied
          })
        end

        :ok
      end)

    :ok
  end

  defp apply_breakdown(_items, 0, applied), do: applied
  defp apply_breakdown([], _remaining, applied), do: applied

  defp apply_breakdown(
         [%{"split_id" => split_id, "amount" => reserved} | rest],
         remaining,
         applied
       ) do
    liability = locked_split!(split_id)
    amount = min(reserved, remaining)

    update_tracking!(liability, %{
      recovered_amount: liability.recovered_amount + amount,
      reserved_recovery_amount: max(liability.reserved_recovery_amount - amount, 0)
    })

    apply_breakdown(rest, remaining - amount, applied + amount)
  end

  defp rollback_recovery!(payment, %{recovery_amount: amount} = earning_split) when amount > 0 do
    {:ok, :ok} =
      Emakola.Repo.transaction(fn ->
        current = locked_split!(earning_split.id)

        desired =
          proportional_amount(current.recovery_amount, payment.refunded_amount, payment.amount)

        delta = desired - current.recovery_reversed_amount

        if delta > 0 do
          rollback_breakdown(
            breakdown_items(current),
            current.recovery_reversed_amount,
            delta
          )

          update_tracking!(current, %{recovery_reversed_amount: desired})
        end

        :ok
      end)

    :ok
  end

  defp rollback_recovery!(_payment, _earning_split), do: :ok

  defp rollback_breakdown(_items, _skip, 0), do: :ok
  defp rollback_breakdown([], _skip, _remaining), do: :ok

  defp rollback_breakdown(
         [%{"split_id" => split_id, "amount" => amount} | rest],
         skip,
         remaining
       ) do
    skipped = min(skip, amount)
    available = amount - skipped
    rollback = min(available, remaining)

    if rollback > 0 do
      liability = locked_split!(split_id)

      update_tracking!(liability, %{
        recovered_amount: max(liability.recovered_amount - rollback, 0)
      })
    end

    rollback_breakdown(rest, max(skip - amount, 0), remaining - rollback)
  end

  defp breakdown_items(%{recovery_breakdown: %{"items" => items}}) when is_list(items), do: items
  defp breakdown_items(_), do: []

  defp locked_split!(split_id) do
    PaymentSplit
    |> Ash.Query.filter(id == ^split_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp update_tracking!(split, attrs) do
    split
    |> Ash.Changeset.for_update(:update_recovery_tracking, attrs)
    |> Ash.update!(authorize?: false)
  end

  defp proportional_amount(_allocation, 0, _payment_total), do: 0

  defp proportional_amount(allocation, refunded, payment_total) do
    min(allocation, div(allocation * refunded, payment_total))
  end
end
