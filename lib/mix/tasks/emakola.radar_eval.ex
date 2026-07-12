defmodule Mix.Tasks.Emakola.RadarEval do
  @shortdoc "Prints the Opportunity Radar controlled-evaluation report"

  @moduledoc """
  Prints fulfilled sales, refunds, and revenue per evaluation arm
  (radar-ranked vs popularity-only baseline). Run against production data
  during the concierge pilot to judge the income-OS Phase C exit criterion.

      mix emakola.radar_eval
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    report = Emakola.Suppliers.RadarEvaluation.report()

    Mix.shell().info("Opportunity Radar controlled evaluation")
    Mix.shell().info("Arm assignment is a pure hash of store_id — stable across runs.\n")

    for {arm, label} <- [radar: "RADAR (blended ranking)", popularity: "POPULARITY (baseline)"] do
      side = Map.fetch!(report, arm)

      Mix.shell().info("""
      #{label}
        stores:            #{side.stores}
        orders:            #{side.orders}
        fulfilled:         #{side.fulfilled}
        refunded:          #{side.refunded}
        fulfilled revenue: #{side.fulfilled_revenue} (minor units)
      """)
    end

    Mix.shell().info(
      "Exit criterion: radar beats popularity in fulfilled sales without a higher refund rate. " <>
        "Judge only once both arms have meaningful volume."
    )
  end
end
