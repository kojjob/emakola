defmodule Emakola.Suppliers.GoalProgress do
  @moduledoc "Computes an income goal's progress from existing Earn attribution and payment ledgers."

  alias Emakola.Suppliers.{ListingImporter, SalesSharing}

  def load(actor, store_id, goal) do
    with {:ok, shares} <- SalesSharing.list_for_store(actor, store_id),
         {:ok, listings} <- ListingImporter.list(actor, store_id) do
      conversions = Enum.flat_map(shares, & &1.conversions)
      earnings = Map.new(conversions, &{&1.order_id, earning_result(&1, store_id)})
      {:ok, summarize(goal, listings, shares, earnings)}
    end
  end

  def summarize(goal, listings, shares, earnings_by_order) do
    conversions = Enum.flat_map(shares, & &1.conversions)
    delivered = Enum.filter(conversions, &SalesSharing.delivered_conversion?/1)
    refunded = Enum.count(conversions, &refunded?(&1, earnings_by_order))
    net_earned = Enum.sum(Enum.map(delivered, &earning(&1, earnings_by_order)))
    target = goal.target_amount

    %{
      published: Enum.count(listings, &(&1.status == :active)),
      shared: Enum.reduce(shares, 0, &(&1.share_count + &2)),
      clicked: Enum.reduce(shares, 0, &(&1.click_count + &2)),
      ordered: length(conversions),
      fulfilled: length(delivered),
      refunded: refunded,
      net_earned: net_earned,
      remaining: max(target - net_earned, 0),
      percent: if(target > 0, do: min(div(net_earned * 100, target), 100), else: 0),
      next_action: next_action(listings, shares, conversions, delivered)
    }
  end

  defp earning_result(conversion, store_id) do
    case Emakola.Payments.get_payment_by_order(conversion.order_id, authorize?: false) do
      {:ok, payment} ->
        net =
          if SalesSharing.delivered_conversion?(conversion),
            do: split_net(payment.id, store_id),
            else: 0

        %{net: net, refunded?: payment.refunded_amount > 0}

      _error ->
        %{net: 0, refunded?: false}
    end
  end

  defp split_net(payment_id, store_id) do
    case Emakola.Payments.list_payment_splits(payment_id, authorize?: false) do
      {:ok, splits} ->
        splits
        |> Enum.filter(&(&1.recipient_store_id == store_id and &1.role == :dropshipper))
        |> Enum.reduce(0, &(max(&1.amount - &1.reversed_amount, 0) + &2))

      _error ->
        0
    end
  end

  defp earning(conversion, earnings_by_order) do
    case Map.get(earnings_by_order, conversion.order_id, 0) do
      %{net: net} -> net
      net when is_integer(net) -> net
      _other -> 0
    end
  end

  defp refunded?(conversion, earnings_by_order) do
    case Map.get(earnings_by_order, conversion.order_id) do
      %{refunded?: refunded?} -> refunded?
      _other -> false
    end
  end

  defp next_action([], _shares, _conversions, _delivered), do: :publish
  defp next_action(_listings, [], _conversions, _delivered), do: :create_sales_kit

  defp next_action(_listings, shares, [], _delivered),
    do: if(Enum.sum(Enum.map(shares, & &1.share_count)) == 0, do: :share, else: :follow_up)

  defp next_action(_listings, _shares, conversions, delivered)
       when length(conversions) > length(delivered), do: :fulfill

  defp next_action(_listings, _shares, _conversions, _delivered), do: :share
end
