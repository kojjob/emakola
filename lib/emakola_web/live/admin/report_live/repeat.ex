defmodule EmakolaWeb.Admin.ReportLive.Repeat do
  @moduledoc """
  Buyers in the window who had a paid order before it started, against
  buyers new to the window.

  Extracted out of `EmakolaWeb.Admin.ReportLive.Index` to keep that module
  under the file-length guideline — this is one report card's data, not the
  page's own logic.
  """

  require Ash.Query

  alias Emakola.Orders.Order

  @doc "Returning vs new buyer figures for the \"Bought again\" card."
  @spec figures(binary() | nil, DateTime.t(), [Order.t()]) :: %{
          returning: non_neg_integer(),
          new: non_neg_integer(),
          share: String.t() | nil
        }
  def figures(nil, _from, _orders), do: %{returning: 0, new: 0, share: nil}

  def figures(store_id, from, orders) do
    buyer_ids = orders |> Enum.map(& &1.customer_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    earlier =
      if buyer_ids == [] do
        MapSet.new()
      else
        Order
        |> Ash.Query.filter(
          store_id == ^store_id and customer_id in ^buyer_ids and inserted_at < ^from and
            status in [:confirmed, :processing, :shipped, :delivered]
        )
        |> Ash.Query.select([:customer_id])
        |> Ash.read!(authorize?: false)
        |> MapSet.new(& &1.customer_id)
      end

    returning = Enum.count(buyer_ids, &MapSet.member?(earlier, &1))
    total = length(buyer_ids)

    %{
      returning: returning,
      new: total - returning,
      share: if(total > 0, do: :erlang.float_to_binary(returning / total * 100, decimals: 1), else: nil)
    }
  end
end
