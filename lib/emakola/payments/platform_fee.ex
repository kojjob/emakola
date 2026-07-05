defmodule Emakola.Payments.PlatformFee do
  @moduledoc """
  Pure computation of the platform's transaction fee on a normal (non-dropship)
  order.

  Given a `base` amount and a fee rate in basis points, returns the integer
  (minor unit) `fee` the platform keeps and the `net` the merchant receives.
  The cardinal invariant is `fee + net == base` — no money is created or lost.

  The fee is **floored**, so the sub-unit rounding remainder accrues to the
  *merchant*: the platform never takes more than the stated rate. All arithmetic
  is integer; the rate is in basis points (e.g. `200` = 2%) so no floats ever
  touch money.

  This mirrors the purity of `Emakola.Payments.SplitCalculator` (the trustless
  dropship split off margin); this module handles the simpler flat fee on a
  merchant's own-stock sale, so the settlement math stays exhaustively unit
  testable without a database or gateway.
  """

  @bps_denominator 10_000

  @doc """
  Compute the platform `fee` and merchant `net` for `base` (minor units) at
  `fee_rate_bps` basis points.

  Returns `%{fee: integer, net: integer}` where `fee + net == base`.
  """
  def calculate(base, fee_rate_bps) do
    fee = div(base * fee_rate_bps, @bps_denominator)
    %{fee: fee, net: base - fee}
  end
end
