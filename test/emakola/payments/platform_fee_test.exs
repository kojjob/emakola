defmodule Emakola.Payments.PlatformFeeTest do
  @moduledoc """
  Unit tests for the pure platform transaction-fee calculation applied to a
  normal (non-dropship) order. All amounts are integer minor units
  (pesewas/kobo); the cardinal invariant is that `fee + net == base`, so no
  money is created or lost. The rounding remainder accrues to the merchant.
  """
  use ExUnit.Case, async: true

  alias Emakola.Payments.PlatformFee

  describe "calculate/2 — standard fee" do
    test "fee is fee_rate of the base; the merchant keeps the rest" do
      assert %{fee: 200, net: 9_800} = PlatformFee.calculate(10_000, 200)
    end

    test "fee + net reconcile exactly to the base — no money created or lost" do
      %{fee: fee, net: net} = PlatformFee.calculate(10_000, 200)
      assert fee + net == 10_000
    end
  end

  describe "calculate/2 — integer rounding" do
    test "fee is floored so the remainder accrues to the merchant, and it still reconciles" do
      # 200 bps of 5_003 = 100.06 -> floored to 100; the merchant keeps 4_903.
      assert %{fee: 100, net: 4_903} = PlatformFee.calculate(5_003, 200)

      %{fee: fee, net: net} = PlatformFee.calculate(5_003, 200)
      assert fee + net == 5_003
    end
  end

  describe "calculate/2 — edge cases" do
    test "a zero fee rate takes nothing; the merchant keeps the full base" do
      assert %{fee: 0, net: 7_500} = PlatformFee.calculate(7_500, 0)
    end

    test "a zero base yields a zero fee and a zero net" do
      assert %{fee: 0, net: 0} = PlatformFee.calculate(0, 200)
    end
  end
end
