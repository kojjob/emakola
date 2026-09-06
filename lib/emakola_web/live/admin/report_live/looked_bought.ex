defmodule EmakolaWeb.Admin.ReportLive.LookedBought do
  @moduledoc """
  Per product: people who opened its page against orders that contain it.

  Extracted out of `EmakolaWeb.Admin.ReportLive.Index` to keep that module
  under the file-length guideline — this is one report card's data, not the
  page's own logic.
  """

  require Ash.Query

  alias Emakola.Analytics.StoreVisits

  @doc "Rows for the \"Looked, then bought\" card, busiest-looked first, capped at 8."
  @spec rows(binary() | nil, DateTime.t(), DateTime.t(), [Emakola.Orders.Order.t()]) :: [
          %{title: String.t(), looked: non_neg_integer(), bought: non_neg_integer()}
        ]
  def rows(nil, _from, _to, _orders), do: []

  def rows(store_id, from, to, orders) do
    looked = StoreVisits.product_visitors(store_id, from, to)
    order_ids = Enum.map(orders, & &1.id)

    bought =
      if order_ids == [] do
        %{}
      else
        Emakola.Orders.LineItem
        |> Ash.Query.filter(order_id in ^order_ids and not is_nil(variant_id))
        |> Ash.Query.load(variant: [:product_id])
        |> Ash.read!(authorize?: false)
        |> Enum.group_by(& &1.variant.product_id, & &1.order_id)
        |> Map.new(fn {product_id, ids} -> {product_id, ids |> Enum.uniq() |> length()} end)
      end

    product_ids = (Map.keys(looked) ++ Map.keys(bought)) |> Enum.uniq()

    titles =
      if product_ids == [] do
        %{}
      else
        # Product is `global?(true)` multitenant, so an id-only filter would
        # read across every store's catalog. `product_ids` should already be
        # this store's own (from product_visitors/3 and this store's line
        # items), but pinning store_id here means a bug upstream can't turn
        # into a title read off someone else's shop.
        Emakola.Catalog.Product
        |> Ash.Query.filter(id in ^product_ids and store_id == ^store_id)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{&1.id, &1.title})
      end

    product_ids
    |> Enum.map(fn id ->
      %{
        title: Map.get(titles, id, "Product"),
        looked: Map.get(looked, id, 0),
        bought: Map.get(bought, id, 0)
      }
    end)
    |> Enum.sort_by(&{-&1.looked, -&1.bought})
    |> Enum.take(8)
  end
end
