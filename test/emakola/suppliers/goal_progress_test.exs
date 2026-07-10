defmodule Emakola.Suppliers.GoalProgressTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.GoalProgress

  test "counts the existing funnel and only fulfilled net earnings" do
    goal = %{target_amount: 10_000}
    listings = [%{status: :active}]

    delivered = %{
      order_id: "delivered",
      order: %{
        fulfillments: [%{status: :delivered}]
      }
    }

    pending = %{
      order_id: "pending",
      order: %{
        fulfillments: [%{status: :shipped}]
      }
    }

    shares = [%{share_count: 3, click_count: 8, conversions: [delivered, pending]}]

    progress =
      GoalProgress.summarize(goal, listings, shares, %{
        "delivered" => %{net: 4_000, refunded?: false},
        "pending" => %{net: 0, refunded?: true}
      })

    assert progress == %{
             published: 1,
             shared: 3,
             clicked: 8,
             ordered: 2,
             fulfilled: 1,
             refunded: 1,
             net_earned: 4_000,
             remaining: 6_000,
             percent: 40,
             next_action: :fulfill
           }
  end

  test "selects an executable action for each activation gap" do
    goal = %{target_amount: 10_000}

    assert GoalProgress.summarize(goal, [], [], %{}).next_action == :publish

    assert GoalProgress.summarize(goal, [%{status: :active}], [], %{}).next_action ==
             :create_sales_kit

    shares = [%{share_count: 0, click_count: 0, conversions: []}]
    assert GoalProgress.summarize(goal, [%{status: :active}], shares, %{}).next_action == :share
  end
end
