defmodule Emakola.Suppliers.IncomeGoalsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  alias Emakola.Suppliers.IncomeGoals

  test "creates one authorized active goal with computed dates" do
    {actor, store} = create_merchant_with_store!()

    assert {:ok, goal} =
             IncomeGoals.create(actor, store.id, %{
               "target_amount" => "80000",
               "timeframe_days" => "30",
               "daily_minutes" => "45",
               "channels" => ["whatsapp", "unknown"]
             })

    assert goal.target_amount == 80_000
    assert goal.channels == [:whatsapp]
    assert Date.diff(goal.ends_on, goal.starts_on) == 29
    assert {:ok, active} = IncomeGoals.active(actor, store.id)
    assert active.id == goal.id
  end

  test "rejects another store's actor and invalid ranges" do
    {actor, store} = create_merchant_with_store!()
    {_other_actor, other_store} = create_merchant_with_store!()

    assert {:error, :forbidden} = IncomeGoals.create(actor, other_store.id, valid_attrs())

    assert {:error, :invalid_goal} =
             IncomeGoals.create(
               actor,
               store.id,
               Map.put(valid_attrs(), :timeframe_days, 2)
             )
  end

  defp valid_attrs,
    do: %{target_amount: 20_000, timeframe_days: 14, daily_minutes: 20, channels: [:whatsapp]}
end
