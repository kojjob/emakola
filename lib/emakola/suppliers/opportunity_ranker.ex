defmodule Emakola.Suppliers.OpportunityRanker do
  @moduledoc "Transparent ranking for Earn opportunities using economics and fulfilled-sales evidence."

  def rank(opportunities) do
    opportunities
    |> Enum.filter(&(Map.get(&1, :status, :active) == :active and Map.get(&1, :earning, 0) > 0))
    |> Enum.map(&with_evidence/1)
    |> Enum.sort_by(&sort_key/1)
  end

  defp with_evidence(opportunity) do
    ordered = Map.get(opportunity, :ordered, 0)
    fulfilled = Map.get(opportunity, :fulfilled, 0)
    refunded = Map.get(opportunity, :refunded, 0)
    fulfillment_rate = if ordered > 0, do: div(fulfilled * 10_000, ordered), else: nil

    opportunity
    |> Map.put(:fulfillment_rate_bps, fulfillment_rate)
    |> Map.put(:confidence, confidence(ordered))
    |> Map.put(:reason, reason(ordered, fulfilled, refunded, opportunity.earning))
  end

  defp sort_key(item) do
    evidence_group = if item.fulfillment_rate_bps, do: 0, else: 1
    rate = item.fulfillment_rate_bps || 0
    {evidence_group, -rate, Map.get(item, :refunded, 0), -item.earning, Map.get(item, :title, "")}
  end

  defp confidence(ordered) when ordered >= 10, do: :high
  defp confidence(ordered) when ordered >= 3, do: :medium
  defp confidence(ordered) when ordered >= 1, do: :early
  defp confidence(_ordered), do: :new

  defp reason(0, _fulfilled, _refunded, earning),
    do: "New opportunity ranked by transparent net earnings of #{earning} minor units per sale."

  defp reason(ordered, fulfilled, refunded, _earning),
    do:
      "Ranked from #{fulfilled} fulfilled of #{ordered} attributed orders and #{refunded} refunds."
end
