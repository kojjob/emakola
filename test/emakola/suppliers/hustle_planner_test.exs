defmodule Emakola.Suppliers.HustlePlannerTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.HustlePlanner

  test "turns a target into an explainable seven-day plan" do
    goal = %{target_amount: 80_000, timeframe_days: 30, daily_minutes: 45, channels: [:whatsapp]}

    opportunities = [
      %{id: "low", title: "Bag", earning: 8_000, status: :active},
      %{id: "high", title: "Shoes", earning: 12_000, status: :active},
      %{id: "paused", title: "Watch", earning: 50_000, status: :paused}
    ]

    plan = HustlePlanner.plan(goal, opportunities)

    assert Enum.map(plan.recommended, & &1.id) == ["high", "low"]
    assert plan.assumed_earning_per_sale == 8_000
    assert plan.required_sales == 10
    assert plan.daily_sales_target == 1
    assert length(plan.actions) == 7
    assert Enum.all?(plan.actions, &(&1.channel == :whatsapp))
    assert plan.disclaimer =~ "not guaranteed income"
  end

  test "does not invent a sales target when no eligible offer exists" do
    plan =
      HustlePlanner.plan(
        %{target_amount: 20_000, timeframe_days: 14, daily_minutes: 20, channels: []},
        []
      )

    assert plan.recommended == []
    assert plan.required_sales == 0
    assert [%{kind: :find_products}] = plan.actions
  end
end
