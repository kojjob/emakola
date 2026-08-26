defmodule Emakola.Stores.DirectoryScore do
  @moduledoc """
  The merit score behind the directory's featured slots.

  Pure integer arithmetic: signals in, `{score, breakdown}` out, clamped to
  0..1000. No database, no structs, no floats — money-style discipline even
  though none of these numbers are money, because a ranking that drifts with
  floating-point rounding is a ranking nobody can reproduce.

  Two decisions here are anti-gaming and must survive any tuning:

  **Reviews carry a Bayesian prior** (`C = #{10}` phantom reviews at 3.5
  stars). Without it, one 5-star review from a friend outranks forty honest
  4.6-star reviews, and the whole ranking is gameable on day one. Ratings are
  handled in centi-stars (a 4.6 is 460) so the prior stays integer.

  **`view_count` is deliberately absent.** It measures traffic, not merit,
  and it is the one counter a motivated merchant could inflate. Behaviour
  scores; popularity does not.

  Weights are expected to be tuned; the tests pin the invariants (ordering
  under the prior, zero-signal floor, breakdown self-consistency), not the
  exact point values.
  """

  # Bayesian prior: C phantom reviews at m centi-stars.
  @prior_count 10
  @prior_mean_centi 350

  # A bayesian mean of 3.0 stars or below earns nothing; 5.0 earns full marks.
  @review_floor_centi 300

  @doc """
  Computes the score from a flat map of signals.

  Every count is over the last 90 days except `product_count` (current) and
  `days_since_last_publish` (nil when the shop never published anything).
  Returns `{score, breakdown}` where the breakdown's values always sum to
  the score — including a `:clamp` entry when the raw total fell outside
  0..1000, so the arithmetic stays auditable.
  """
  @spec compute(map()) :: {0..1000, %{atom() => integer()}}
  def compute(signals) do
    breakdown = %{
      fulfilment_volume: fulfilment_volume(signals),
      fulfilment_rate: fulfilment_rate(signals),
      review_quality: review_quality(signals),
      catalog_health: catalog_health(signals),
      verified_trust: verified_trust(signals),
      penalties: penalties(signals)
    }

    raw = breakdown |> Map.values() |> Enum.sum()
    score = raw |> max(0) |> min(1000)

    breakdown =
      if score == raw, do: breakdown, else: Map.put(breakdown, :clamp, score - raw)

    {score, breakdown}
  end

  # ── Components ─────────────────────────────────────────────────────────

  # 0..250 — recent delivered volume, saturating so a giant cannot lap the field.
  defp fulfilment_volume(%{delivered_orders_90d: delivered}) do
    min(delivered * 15, 250)
  end

  # 0..200 — delivered over delivered + cancelled. A shop with no orders gets
  # zero, not a penalty: silence is not evidence of failure.
  defp fulfilment_rate(%{delivered_orders_90d: 0, cancelled_orders_90d: _}), do: 0

  defp fulfilment_rate(%{delivered_orders_90d: delivered, cancelled_orders_90d: cancelled}) do
    rate_bps = div(delivered * 10_000, delivered + cancelled)
    div(rate_bps * 200, 10_000)
  end

  # 0..200 — Bayesian mean in centi-stars, mapped so 3.0 stars is the floor
  # and 5.0 is full marks. Zero reviews land at the prior (3.5 stars → a
  # modest benefit of the doubt), which is the point of a prior.
  defp review_quality(%{review_count: n, review_rating_sum_centi: sum_centi}) do
    bayes_centi = div(@prior_count * @prior_mean_centi + sum_centi, @prior_count + n)
    max(bayes_centi - @review_floor_centi, 0)
  end

  # 0..150 — a stocked catalog (up to 100) plus fresh stock (up to 50).
  # Freshness reads days-since-last-publish so the caller stays pure.
  defp catalog_health(%{product_count: count, days_since_last_publish: days}) do
    stocked = min(count * 10, 100)

    freshness =
      case days do
        nil -> 0
        d when d <= 30 -> 50
        d when d <= 90 -> 25
        _stale -> 0
      end

    stocked + freshness
  end

  # 0 or 100 — a real approved StoreVerification, never the manual
  # Store.verified boolean, which an admin can set with no KYC behind it.
  defp verified_trust(%{kyc_approved?: true}), do: 100
  defp verified_trust(%{kyc_approved?: false}), do: 0

  # ≤ 0 — money going backwards and platform interventions. Each term is
  # capped so one bad month wounds a score rather than erasing it; the floor
  # clamp catches genuinely rotten combinations.
  defp penalties(signals) do
    %{
      successful_payments_90d: successful,
      refunded_payments_90d: refunded,
      taken_down_products_90d: takedowns,
      merchant_fault_returns_90d: fault_returns,
      staff_refunded_holds_90d: staff_holds
    } = signals

    refund_penalty =
      case successful + refunded do
        0 -> 0
        settled -> min(div(div(refunded * 10_000, settled) * 300, 10_000), 300)
      end

    -(refund_penalty +
        min(takedowns * 150, 300) +
        min(fault_returns * 25, 100) +
        min(staff_holds * 100, 200))
  end
end
