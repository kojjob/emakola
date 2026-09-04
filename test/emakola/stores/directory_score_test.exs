defmodule Emakola.Stores.DirectoryScoreTest do
  @moduledoc """
  The directory merit score is pure integer arithmetic over signals the
  ranking worker collects. These tests are the contract: they pin the
  anti-gaming decisions (the Bayesian review prior above all) rather than
  the exact point values, which are expected to be tuned.
  """
  use ExUnit.Case, async: true

  alias Emakola.Stores.DirectoryScore

  defp signals(overrides) do
    Map.merge(
      %{
        delivered_orders_90d: 0,
        cancelled_orders_90d: 0,
        successful_payments_90d: 0,
        refunded_payments_90d: 0,
        review_count: 0,
        review_rating_sum_centi: 0,
        product_count: 0,
        days_since_last_publish: nil,
        taken_down_products_90d: 0,
        merchant_fault_returns_90d: 0,
        staff_refunded_holds_90d: 0
      },
      overrides
    )
  end

  test "a zero-signal store scores low but never negative" do
    {score, _breakdown} = DirectoryScore.compute(signals(%{}))

    assert score >= 0
    assert score < 200
  end

  test "one 5-star review does not outrank forty 4.6-star reviews" do
    {one_perfect, _} =
      DirectoryScore.compute(signals(%{review_count: 1, review_rating_sum_centi: 500}))

    {forty_good, _} =
      DirectoryScore.compute(signals(%{review_count: 40, review_rating_sum_centi: 40 * 460}))

    assert forty_good > one_perfect
  end

  test "a store with no orders gets zero fulfilment-rate points, not a penalty" do
    {score, breakdown} = DirectoryScore.compute(signals(%{}))
    {with_orders, _} = DirectoryScore.compute(signals(%{delivered_orders_90d: 5}))

    assert breakdown.fulfilment_rate == 0
    assert with_orders > score
  end

  test "refunds, takedowns, faulty returns and staff-adjudicated holds all cost points" do
    clean = signals(%{delivered_orders_90d: 10, successful_payments_90d: 10, product_count: 5})
    {clean_score, _} = DirectoryScore.compute(clean)

    for dirty <- [
          %{refunded_payments_90d: 5},
          %{taken_down_products_90d: 1},
          %{merchant_fault_returns_90d: 3},
          %{staff_refunded_holds_90d: 1}
        ] do
      {dirty_score, _} = DirectoryScore.compute(Map.merge(clean, dirty))
      assert dirty_score < clean_score, "expected #{inspect(dirty)} to cost points"
    end
  end

  test "the score clamps to 0..1000 at both extremes" do
    {floor, _} =
      DirectoryScore.compute(
        signals(%{
          successful_payments_90d: 1,
          refunded_payments_90d: 99,
          taken_down_products_90d: 10,
          merchant_fault_returns_90d: 20,
          staff_refunded_holds_90d: 10
        })
      )

    {ceiling, _} =
      DirectoryScore.compute(
        signals(%{
          delivered_orders_90d: 500,
          successful_payments_90d: 500,
          review_count: 200,
          review_rating_sum_centi: 200 * 500,
          product_count: 100,
          days_since_last_publish: 1
        })
      )

    assert floor == 0
    # The weight table sums to 900, so a perfect shop lands short of the
    # scale's ceiling — deliberate headroom, not a bug. What matters is the
    # bound, and that the floor clamp explains itself in the breakdown.
    assert ceiling <= 1000
    assert ceiling > 850

    {_floor, floor_breakdown} =
      DirectoryScore.compute(
        signals(%{
          successful_payments_90d: 1,
          refunded_payments_90d: 99,
          taken_down_products_90d: 10,
          merchant_fault_returns_90d: 20,
          staff_refunded_holds_90d: 10
        })
      )

    assert Map.has_key?(floor_breakdown, :clamp)
  end

  test "the breakdown always sums to the score" do
    for overrides <- [
          %{},
          %{delivered_orders_90d: 12, cancelled_orders_90d: 2},
          %{review_count: 7, review_rating_sum_centi: 7 * 480},
          %{refunded_payments_90d: 40, successful_payments_90d: 2, taken_down_products_90d: 4}
        ] do
      {score, breakdown} = DirectoryScore.compute(signals(overrides))
      assert score == breakdown |> Map.values() |> Enum.sum()
    end
  end

  test "everything is an integer — no floats anywhere in the output" do
    {score, breakdown} =
      DirectoryScore.compute(
        signals(%{delivered_orders_90d: 7, review_count: 3, review_rating_sum_centi: 1330})
      )

    assert is_integer(score)
    assert Enum.all?(Map.values(breakdown), &is_integer/1)
  end

  test "fresh stock beats a stale catalog of the same size" do
    {fresh, _} = DirectoryScore.compute(signals(%{product_count: 10, days_since_last_publish: 3}))

    {stale, _} =
      DirectoryScore.compute(signals(%{product_count: 10, days_since_last_publish: 200}))

    assert fresh > stale
  end

  test "identity is not scored — an approved KYC record earns nothing" do
    # L.I. 2523 retired the national-ID flow, so a `verified_trust` component
    # would only reward stores onboarded before June 2026. Passing the old
    # signal must be inert, not merely unused.
    {without, breakdown} = DirectoryScore.compute(signals(%{delivered_orders_90d: 5}))

    {with_kyc, _} =
      DirectoryScore.compute(signals(%{delivered_orders_90d: 5, kyc_approved?: true}))

    assert with_kyc == without
    assert without > 0
    refute Map.has_key?(breakdown, :verified_trust)
  end

  test "the perfect-shop ceiling is unchanged by dropping the identity component" do
    {ceiling, _} =
      DirectoryScore.compute(
        signals(%{
          delivered_orders_90d: 500,
          cancelled_orders_90d: 0,
          successful_payments_90d: 500,
          review_count: 200,
          review_rating_sum_centi: 200 * 500,
          product_count: 100,
          days_since_last_publish: 1
        })
      )

    # 892, not 900: the review prior means 200 five-star reviews land at 192
    # of the 200 available points, and that headroom is the prior working.
    # The number is identical before and after the redistribution
    # (250+200+192+150+100 = 300+250+192+150), which is the point — dropping
    # the identity component moved weight around without moving the ceiling.
    assert ceiling == 892
  end
end
