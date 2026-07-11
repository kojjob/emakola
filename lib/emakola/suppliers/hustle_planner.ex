defmodule Emakola.Suppliers.HustlePlanner do
  @moduledoc "Explainable, deterministic planning for a Makola Earn income goal."

  alias Emakola.Suppliers.OpportunityRanker

  def plan(goal, opportunities) do
    ranked =
      opportunities
      |> OpportunityRanker.rank()
      |> Enum.take(5)

    assumed_earning = median(Enum.map(ranked, &earning/1))

    required_sales =
      if assumed_earning == 0, do: 0, else: ceil_div(goal.target_amount, assumed_earning)

    %{
      target_amount: goal.target_amount,
      timeframe_days: goal.timeframe_days,
      recommended: ranked,
      assumed_earning_per_sale: assumed_earning,
      required_sales: required_sales,
      daily_sales_target: ceil_div(required_sales, goal.timeframe_days),
      actions: actions(goal, ranked),
      disclaimer:
        "This is a planning scenario, not guaranteed income. Results depend on real customer sales and successful fulfillment."
    }
  end

  defp earning(item), do: Map.get(item, :earning, 0)

  defp actions(goal, []),
    do: [
      %{
        day: 1,
        kind: :find_products,
        minutes: goal.daily_minutes,
        message: "Choose at least three eligible partner products."
      }
    ]

  defp actions(goal, ranked) do
    channels = if goal.channels == [], do: [:whatsapp], else: goal.channels

    for day <- 1..min(goal.timeframe_days, 7) do
      product = Enum.at(ranked, rem(day - 1, length(ranked)))
      channel = Enum.at(channels, rem(day - 1, length(channels)))

      %{
        day: day,
        kind: if(day == 1, do: :publish_and_share, else: :share_and_follow_up),
        product_id: Map.get(product, :id),
        channel: channel,
        minutes: goal.daily_minutes,
        message: "Share #{Map.get(product, :title, "a recommended product")} on #{channel}."
      }
    end
  end

  defp median([]), do: 0
  defp median(values), do: values |> Enum.sort() |> Enum.at(div(length(values) - 1, 2))
  defp ceil_div(0, _denominator), do: 0
  defp ceil_div(numerator, denominator), do: div(numerator + denominator - 1, denominator)
end
