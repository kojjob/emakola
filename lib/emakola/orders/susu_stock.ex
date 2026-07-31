defmodule Emakola.Orders.SusuStock do
  @moduledoc """
  Stock for a susu plan is decremented once, at activation — not reserved
  at plan creation, and never decremented again when the plan's order
  eventually confirms (`Orders.Changes.DecrementStock` skips susu orders
  for exactly this reason). Documented spec deviation: no reservation
  table, no availability-query changes anywhere — a susu activation is,
  for stock purposes, indistinguishable from an ordinary sale.

  `reserve/1` funnels through the same atomic mechanism
  `Orders.Changes.DecrementStock` uses for a normal order
  (`Inventory.decrement_for_sale!/4`), so the same oversell guard (the
  `stock_non_negative` DB CHECK) applies — insufficient stock rolls back
  the whole decrement, nothing partial. `release/1` re-increments the
  variant's default location only if `reserve/1` actually decremented
  something, tracked via `SusuPlan.stock_reserved`: the flag is read and
  cleared under `FOR UPDATE` on the plan row, so releasing the same plan
  twice (an expiry sweep racing a manual cancel, say) only credits stock
  back once.

  What happens to the PLAN itself on `{:error, :insufficient_stock}`
  (cancelling it, flagging the payment for refund attention) is the
  activation caller's job, not this module's.
  """

  require Ash.Query

  alias Emakola.Orders.SusuPlan

  @doc """
  Decrements a catalog plan's tracked variant by `plan.quantity`. Custom
  plans and untracked variants are a no-op. Returns
  `{:error, :insufficient_stock}` (nothing decremented) when stock is
  short; sets `stock_reserved` on the plan only when a decrement actually
  happened.
  """
  def reserve(%SusuPlan{type: :custom}), do: :ok

  def reserve(%SusuPlan{type: :catalog} = plan) do
    variant = Ash.get!(Emakola.Catalog.Variant, plan.variant_id, authorize?: false)

    if variant.track_inventory do
      do_reserve(plan, variant)
    else
      :ok
    end
  end

  @doc """
  Re-increments stock previously reserved by `reserve/1`. A no-op unless
  the plan's CURRENT (freshly re-read, `FOR UPDATE`) `stock_reserved` is
  true — so calling this more than once for the same plan only credits
  stock back once.
  """
  def release(%SusuPlan{id: id}) do
    Emakola.Repo.transaction(fn ->
      plan = locked_plan!(id)

      if plan.stock_reserved do
        variant = Ash.get!(Emakola.Catalog.Variant, plan.variant_id, authorize?: false)
        default_location = Emakola.Inventory.ensure_default_location!(plan.store_id)

        {:ok, _} =
          Emakola.Inventory.adjust(
            variant.id,
            default_location.id,
            plan.quantity,
            :reservation_release
          )

        clear_reserved!(plan)
      end
    end)

    :ok
  end

  defp do_reserve(plan, variant) do
    Emakola.Repo.transaction(fn ->
      Emakola.Inventory.decrement_for_sale!(variant.id, plan.store_id, plan.quantity, nil)
      mark_reserved!(plan)
    end)

    :ok
  rescue
    Ash.Error.Invalid -> {:error, :insufficient_stock}
  end

  defp mark_reserved!(plan) do
    plan
    |> Ash.Changeset.for_update(:mark_stock_reserved, %{})
    |> Ash.update!(authorize?: false)
  end

  defp clear_reserved!(plan) do
    plan
    |> Ash.Changeset.for_update(:clear_stock_reserved, %{})
    |> Ash.update!(authorize?: false)
  end

  defp locked_plan!(id) do
    SusuPlan
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end
end
