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
end
