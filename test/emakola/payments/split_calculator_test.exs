defmodule Emakola.Payments.SplitCalculatorTest do
  @moduledoc """
  Unit tests for the pure dropship split calculator — the testable heart of the
  trustless settlement engine (SP5). All amounts are integer minor units
  (pesewas/kobo); the cardinal invariant is that allocations sum exactly to the
  order total with no money created or lost.
  """
  use ExUnit.Case, async: true

  alias Emakola.Payments.SplitCalculator

  describe "calculate/2 — mixed cart (wholesaler item + own-stock item)" do
    setup do
      supplier_id = "supplier-1"

      line_items = [
        # dropship: R = 5000*2 = 10000, C = 800*2 = 1600, M = 8400
        %{unit_price: 5_000, cost_price: 800, quantity: 2, supplier_id: supplier_id},
        # own-stock: R = 3000, no cost, no supplier
        %{unit_price: 3_000, cost_price: nil, quantity: 1, supplier_id: nil}
      ]

      opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{supplier_id => "ACCT_whole"},
        dropshipper_subaccount: "ACCT_drop"
      ]

      {:ok, line_items: line_items, opts: opts, supplier_id: supplier_id}
    end

    test "total equals the sum of every line's retail", %{line_items: items, opts: opts} do
      assert %{total: 13_000} = SplitCalculator.calculate(items, opts)
    end

    test "wholesaler receives their cost (Σ cost_price × qty) at their subaccount", ctx do
      %{allocations: allocs} = SplitCalculator.calculate(ctx.line_items, ctx.opts)

      assert %{
               role: :wholesaler,
               supplier_id: "supplier-1",
               subaccount_code: "ACCT_whole",
               amount: 1_600
             } = find_role(allocs, :wholesaler)
    end

    test "platform receives fee_rate of the dropship margin", %{line_items: items, opts: opts} do
      %{allocations: allocs} = SplitCalculator.calculate(items, opts)
      # 10% of margin 8400 = 840
      assert %{role: :platform, amount: 840} = find_role(allocs, :platform)
    end

    test "dropshipper receives own-stock revenue plus net dropship margin", %{
      line_items: items,
      opts: opts
    } do
      %{allocations: allocs} = SplitCalculator.calculate(items, opts)
      # own-stock 3000 + (margin 8400 - fee 840) = 3000 + 7560 = 10560
      assert %{role: :dropshipper, subaccount_code: "ACCT_drop", amount: 10_560} =
               find_role(allocs, :dropshipper)
    end

    test "allocations sum exactly to the total — no money created or lost", %{
      line_items: items,
      opts: opts
    } do
      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end
  end

  describe "calculate/2 — multiple wholesalers" do
    test "produces one wholesaler allocation per supplier, each to its own subaccount" do
      items = [
        %{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: "s1"},
        %{unit_price: 2_000, cost_price: 500, quantity: 2, supplier_id: "s2"}
      ]

      opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{"s1" => "ACCT_1", "s2" => "ACCT_2"},
        dropshipper_subaccount: "ACCT_drop"
      ]

      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)

      wholesalers = Enum.filter(allocs, &(&1.role == :wholesaler))
      assert length(wholesalers) == 2

      assert %{subaccount_code: "ACCT_1", amount: 800} =
               Enum.find(wholesalers, &(&1.supplier_id == "s1"))

      assert %{subaccount_code: "ACCT_2", amount: 1_000} =
               Enum.find(wholesalers, &(&1.supplier_id == "s2"))

      # Reconciliation still holds across multiple suppliers.
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    test "sums cost across multiple lines from the same supplier into one allocation" do
      items = [
        %{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: "s1"},
        %{unit_price: 3_000, cost_price: 600, quantity: 2, supplier_id: "s1"}
      ]

      opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{"s1" => "ACCT_1"},
        dropshipper_subaccount: "ACCT_drop"
      ]

      %{allocations: allocs} = SplitCalculator.calculate(items, opts)
      wholesalers = Enum.filter(allocs, &(&1.role == :wholesaler))
      # One allocation: cost = 800*1 + 600*2 = 2000
      assert [%{supplier_id: "s1", amount: 2_000}] = wholesalers
    end
  end

  describe "calculate/2 — own-stock only (no dropship)" do
    test "dropshipper gets all revenue; platform fee is zero; no wholesaler allocation" do
      items = [%{unit_price: 3_000, cost_price: nil, quantity: 2, supplier_id: nil}]
      opts = [fee_rate_bps: 1_000, subaccounts: %{}, dropshipper_subaccount: "ACCT_drop"]

      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)

      assert total == 6_000
      assert [] == Enum.filter(allocs, &(&1.role == :wholesaler))
      assert %{role: :platform, amount: 0} = find_role(allocs, :platform)
      assert %{role: :dropshipper, amount: 6_000} = find_role(allocs, :dropshipper)
    end
  end

  describe "calculate/2 — integer rounding" do
    test "rounding remainder accrues to the platform, and the split still reconciles" do
      # margin = (5001 - 1) * 1 = 5000; 7% of 5000 = 350 exactly is too clean —
      # use a margin where the fee does not divide evenly.
      items = [%{unit_price: 5_003, cost_price: 0, quantity: 1, supplier_id: "s1"}]
      # 333 bps of 5003 = 166.5999 -> dropshipper floor keeps 4669, platform takes the rest.
      opts = [
        fee_rate_bps: 333,
        subaccounts: %{"s1" => "ACCT_1"},
        dropshipper_subaccount: "ACCT_drop"
      ]

      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)

      dropshipper_net = div(5_003 * (10_000 - 333), 10_000)
      platform_fee = 5_003 - dropshipper_net

      assert %{role: :dropshipper, amount: ^dropshipper_net} = find_role(allocs, :dropshipper)
      assert %{role: :platform, amount: ^platform_fee} = find_role(allocs, :platform)
      # The wholesaler cost here is 0, so total = margin = 5003 and everything reconciles.
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end
  end

  describe "calculate/2 — dispatch fees" do
    test "wholesaler amount includes its dispatch fee; total grows by the fee" do
      items = [%{unit_price: 5_000, cost_price: 800, quantity: 2, supplier_id: "s1"}]

      opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{"s1" => "ACCT_1"},
        dropshipper_subaccount: "ACCT_drop",
        dispatch_fees: %{"s1" => 1_500}
      ]

      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)

      # wholesaler cost 1600 + dispatch fee 1500 = 3100
      assert %{role: :wholesaler, amount: 3_100} = find_role(allocs, :wholesaler)
      # retail 10000 + dispatch fee 1500 = 11500
      assert total == 11_500
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    test "each wholesaler's fee applies only to its own allocation" do
      items = [
        %{unit_price: 5_000, cost_price: 800, quantity: 1, supplier_id: "s1"},
        %{unit_price: 2_000, cost_price: 500, quantity: 2, supplier_id: "s2"}
      ]

      opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{"s1" => "ACCT_1", "s2" => "ACCT_2"},
        dropshipper_subaccount: "ACCT_drop",
        dispatch_fees: %{"s1" => 300, "s2" => 700}
      ]

      %{total: total, allocations: allocs} = SplitCalculator.calculate(items, opts)
      wholesalers = Enum.filter(allocs, &(&1.role == :wholesaler))

      assert %{amount: 1_100} = Enum.find(wholesalers, &(&1.supplier_id == "s1"))
      assert %{amount: 1_700} = Enum.find(wholesalers, &(&1.supplier_id == "s2"))
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    test "omitting :dispatch_fees behaves exactly like a %{} fee map" do
      items = [%{unit_price: 5_000, cost_price: 800, quantity: 2, supplier_id: "s1"}]

      base_opts = [
        fee_rate_bps: 1_000,
        subaccounts: %{"s1" => "ACCT_1"},
        dropshipper_subaccount: "ACCT_drop"
      ]

      assert SplitCalculator.calculate(items, base_opts) ==
               SplitCalculator.calculate(items, base_opts ++ [dispatch_fees: %{}])
    end
  end

  defp find_role(allocations, role) do
    Enum.find(allocations, &(&1.role == role))
  end
end
