defmodule Emakola.Stores.FeaturedRanking do
  @moduledoc """
  Keeps featured stores in a single, gap-free order (ranks 1..n).

  Featuring a store appends it at the end; unfeaturing clears its rank and
  compacts the rest; `move/2` swaps a store with its neighbour. Legacy
  data (gapped, duplicate, or nil ranks on featured stores) is normalized
  before every reorder — unranked featured stores sort last.

  All writes go through the `:update_directory_meta` action with
  `authorize?: false`: callers are the platform admin LiveViews, which
  gate on the `:manage_stores` permission before invoking this module.
  Batches run inside a transaction so a mid-batch failure cannot leave a
  half-compacted order.
  """

  require Ash.Query

  alias Emakola.Repo
  alias Emakola.Stores.Store

  @spec feature(Store.t()) :: {:ok, Store.t()} | {:error, term()}
  def feature(store) do
    transact(fn ->
      order = featured_in_order()
      set_meta!(store, %{featured: true, featured_rank: length(order) + 1})
    end)
  end

  @spec unfeature(Store.t()) :: {:ok, Store.t()} | {:error, term()}
  def unfeature(store) do
    transact(fn ->
      updated = set_meta!(store, %{featured: false, featured_rank: nil})
      renumber!(featured_in_order())
      updated
    end)
  end

  @spec move(Store.t(), :up | :down) :: {:ok, Store.t()} | {:error, term()}
  def move(store, direction) when direction in [:up, :down] do
    transact(fn ->
      order = renumber!(featured_in_order())
      index = Enum.find_index(order, &(&1.id == store.id))

      case swap_index(index, direction, length(order)) do
        nil ->
          Enum.at(order, index) || store

        other_index ->
          current = Enum.at(order, index)
          neighbour = Enum.at(order, other_index)
          set_meta!(neighbour, %{featured_rank: index + 1})
          set_meta!(current, %{featured_rank: other_index + 1})
      end
    end)
  end

  @doc "1-based position of a featured store and the featured total, from the current order."
  @spec position(Store.t()) :: {pos_integer() | nil, non_neg_integer()}
  def position(store) do
    order = featured_in_order()
    index = Enum.find_index(order, &(&1.id == store.id))
    {index && index + 1, length(order)}
  end

  defp featured_in_order do
    Store
    |> Ash.Query.filter(featured == true)
    |> Ash.Query.sort([{:featured_rank, :asc_nils_last}, {:inserted_at, :asc}])
    |> Ash.read!(authorize?: false)
  end

  defp renumber!(order) do
    order
    |> Enum.with_index(1)
    |> Enum.map(fn {store, rank} ->
      if store.featured_rank == rank, do: store, else: set_meta!(store, %{featured_rank: rank})
    end)
  end

  defp swap_index(nil, _direction, _count), do: nil
  defp swap_index(0, :up, _count), do: nil
  defp swap_index(index, :up, _count), do: index - 1
  defp swap_index(index, :down, count) when index >= count - 1, do: nil
  defp swap_index(index, :down, _count), do: index + 1

  defp set_meta!(store, attrs) do
    store
    |> Ash.Changeset.for_update(:update_directory_meta, attrs)
    |> Ash.update!(authorize?: false)
  end

  defp transact(fun) do
    case Repo.transaction(fun) do
      {:ok, store} -> {:ok, store}
      {:error, reason} -> {:error, reason}
    end
  end
end
