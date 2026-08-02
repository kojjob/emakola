defmodule Emakola.Payments.DropshipSettlement do
  @moduledoc """
  Decides whether a customer charge can be split at the gateway across the
  dropship parties, and if so computes the allocations (SP5).

  Resolution chain for each dropship line: `supplier_id -> Supplier.linked_store_id
  -> that store's verified StorePayoutAccount.subaccount_code`. A split engages
  only when the dropshipper and every wholesaler have a verified payout
  subaccount; otherwise the caller falls back to the existing manual
  `SupplierLedgerEntry` flow.

  Returns `{:split, %{total: integer, allocations: [map]}}` or
  `{:no_split, reason}` where reason is one of `:no_dropship_items`,
  `:dropshipper_payout_unverified`, `:supplier_not_linked`,
  `:wholesaler_payout_unverified`.

  `prepare_internal/3` is the internal-rail counterpart, with no subaccount
  requirement and a narrower reason set (only `:no_dropship_items` — the
  other three don't apply once verification is no longer a precondition).
  """

  alias Emakola.Payments.SplitCalculator
  alias Emakola.Suppliers.Supplier

  @doc """
  Prepare a split for `line_items` sold by `dropshipper_store_id`.

  `line_items` are maps with `:unit_price`, `:cost_price`, `:quantity`, and
  `:supplier_id` (nil for own-stock). `opts` requires `:fee_rate_bps` and
  accepts `:dispatch_fees` (map of `supplier_id => pesewas`, default `%{}`).
  """
  def prepare(line_items, dropshipper_store_id, opts) do
    fee_rate_bps = Keyword.fetch!(opts, :fee_rate_bps)
    dispatch_fees = Keyword.get(opts, :dispatch_fees, %{})

    supplier_ids =
      line_items |> Enum.map(& &1.supplier_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    with {:dropship, [_ | _]} <- {:dropship, supplier_ids},
         {:ok, dropshipper_code} <- verified_subaccount(dropshipper_store_id),
         {:ok, resolved} <- resolve_subaccounts(supplier_ids, dropshipper_store_id) do
      subaccounts = Map.new(resolved, fn {sid, %{code: code}} -> {sid, code} end)

      %{total: total, allocations: allocations} =
        SplitCalculator.calculate(line_items,
          fee_rate_bps: fee_rate_bps,
          subaccounts: subaccounts,
          dropshipper_subaccount: dropshipper_code,
          dispatch_fees: dispatch_fees
        )

      enriched = Enum.map(allocations, &add_recipient(&1, resolved, dropshipper_store_id))
      {:split, %{total: total, allocations: enriched}}
    else
      {:dropship, []} -> {:no_split, :no_dropship_items}
      {:error, :payout_unverified} -> {:no_split, :dropshipper_payout_unverified}
      {:error, reason} -> {:no_split, reason}
    end
  end

  # Builds a supplier_id => %{code, store_id} map, short-circuiting on the first
  # supplier that cannot be resolved to a verified wholesaler payout account.
  defp resolve_subaccounts(supplier_ids, dropshipper_store_id) do
    Enum.reduce_while(supplier_ids, {:ok, %{}}, fn supplier_id, {:ok, acc} ->
      case resolve_supplier(supplier_id, dropshipper_store_id) do
        {:ok, resolution} -> {:cont, {:ok, Map.put(acc, supplier_id, resolution)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp resolve_supplier(supplier_id, dropshipper_store_id) do
    case Ash.get(Supplier, supplier_id, tenant: dropshipper_store_id, authorize?: false) do
      {:ok, %{linked_store_id: nil}} ->
        {:error, :supplier_not_linked}

      {:ok, %{linked_store_id: linked_store_id}} ->
        case verified_subaccount(linked_store_id) do
          {:ok, code} -> {:ok, %{code: code, store_id: linked_store_id}}
          {:error, :payout_unverified} -> {:error, :wholesaler_payout_unverified}
        end

      {:error, _} ->
        {:error, :supplier_not_linked}
    end
  end

  # Adds recipient_store_id to each allocation: the wholesaler's linked store,
  # the dropshipper's own store, or nil for the platform (its cut stays in the
  # platform main account).
  defp add_recipient(%{role: :wholesaler, supplier_id: supplier_id} = alloc, resolved, _drop) do
    Map.put(alloc, :recipient_store_id, resolved[supplier_id].store_id)
  end

  defp add_recipient(%{role: :dropshipper} = alloc, _resolved, dropshipper_store_id) do
    Map.put(alloc, :recipient_store_id, dropshipper_store_id)
  end

  defp add_recipient(%{role: :platform} = alloc, _resolved, _drop) do
    Map.put(alloc, :recipient_store_id, nil)
  end

  # A store's payout subaccount, only if the account is verified and has a code.
  defp verified_subaccount(store_id) do
    case Emakola.Stores.get_payout_account(store_id, authorize?: false) do
      {:ok, %{verification_status: :verified, subaccount_code: code}} when is_binary(code) ->
        {:ok, code}

      _ ->
        {:error, :payout_unverified}
    end
  end

  @doc """
  Internal-rail variant of `prepare/3`: same SplitCalculator math, NO
  subaccount requirement. Linked suppliers keep their wholesaler allocation
  (payable to their store via the ledger); unlinked suppliers' cost and
  dispatch fee fold into the dropshipper, who still owes them manually via
  SupplierLedgerEntry. Routed to by `prepare/2`'s verification-failure
  fallbacks since Phase 3.
  """
  def prepare_internal(line_items, dropshipper_store_id, opts) do
    fee_rate_bps = Keyword.fetch!(opts, :fee_rate_bps)
    dispatch_fees = Keyword.get(opts, :dispatch_fees, %{})

    supplier_ids =
      line_items |> Enum.map(& &1.supplier_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if supplier_ids == [] do
      {:no_split, :no_dropship_items}
    else
      linked = resolve_linked(supplier_ids, dropshipper_store_id)

      %{total: total, allocations: allocations} =
        SplitCalculator.calculate(line_items,
          fee_rate_bps: fee_rate_bps,
          subaccounts: %{},
          dropshipper_subaccount: nil,
          dispatch_fees: dispatch_fees
        )

      {:split,
       %{total: total, allocations: internalize(allocations, linked, dropshipper_store_id)}}
    end
  end

  defp resolve_linked(supplier_ids, dropshipper_store_id) do
    Enum.reduce(supplier_ids, %{}, fn supplier_id, acc ->
      case Ash.get(Supplier, supplier_id, tenant: dropshipper_store_id, authorize?: false) do
        {:ok, %{linked_store_id: linked}} when not is_nil(linked) ->
          Map.put(acc, supplier_id, linked)

        _ ->
          acc
      end
    end)
  end

  # Linked wholesalers keep their allocation; unlinked ones fold into the
  # dropshipper so the money to pay them manually reaches the merchant.
  defp internalize(allocations, linked, dropshipper_store_id) do
    {folded, kept} =
      Enum.reduce(allocations, {0, []}, fn
        %{role: :wholesaler, supplier_id: sid} = alloc, {folded, acc} ->
          case Map.fetch(linked, sid) do
            {:ok, store_id} ->
              {folded, [Map.put(alloc, :recipient_store_id, store_id) | acc]}

            :error ->
              {folded + alloc.amount, acc}
          end

        %{role: :dropshipper} = alloc, {folded, acc} ->
          {folded, [Map.put(alloc, :recipient_store_id, dropshipper_store_id) | acc]}

        %{role: :platform} = alloc, {folded, acc} ->
          {folded, [Map.put(alloc, :recipient_store_id, nil) | acc]}
      end)

    kept
    |> Enum.reverse()
    |> Enum.map(fn
      # passthrough_amount fences the folded unlinked-supplier money (owed
      # manually via SupplierLedgerEntry) out of the carve and refund-recovery
      # bases downstream — see PartnerCredit.carve_sales_proceeds and
      # RefundLiability.reserve_for_allocation/2.
      %{role: :dropshipper} = alloc ->
        alloc
        |> Map.put(:amount, alloc.amount + folded)
        |> Map.put(:passthrough_amount, folded)

      alloc ->
        alloc
    end)
  end
end
