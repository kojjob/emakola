defmodule Emakola.Suppliers.OpportunityRankerTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.OpportunityRanker

  test "ranks proven fulfillment before unproven high earnings and explains why" do
    ranked =
      OpportunityRanker.rank([
        %{id: "new", title: "New", earning: 10_000, ordered: 0, fulfilled: 0, refunded: 0},
        %{id: "proven", title: "Proven", earning: 2_000, ordered: 10, fulfilled: 9, refunded: 0},
        %{id: "risky", title: "Risky", earning: 4_000, ordered: 10, fulfilled: 5, refunded: 3}
      ])

    assert Enum.map(ranked, & &1.id) == ["proven", "risky", "new"]
    assert hd(ranked).fulfillment_rate_bps == 9_000
    assert hd(ranked).confidence == :high
    assert hd(ranked).reason =~ "9 fulfilled of 10"
    assert List.last(ranked).confidence == :new
  end

  test "excludes paused and zero-earning opportunities" do
    assert [] ==
             OpportunityRanker.rank([
               %{earning: 1_000, status: :paused},
               %{earning: 0, status: :active}
             ])
  end
end
