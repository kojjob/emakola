defmodule Emakola.Stores.DirectoryEligibility do
  @moduledoc """
  The floor under every featured slot on the public directory.

  A shop that fails any check here appears in no featured slot — not the
  merit spotlight, not the staff picks, and not a paid slot if one ever
  exists. Money and staff taste may reorder shops inside a slot; neither
  may put an ineligible shop into one.

  The floor gates the featured slots only. An ineligible shop is still in
  the directory grid, still searchable, still selling — it just is not
  promoted.

  Pure: signals in, `{eligible?, disqualifiers}` out. The ranking worker
  collects the signals; nothing here touches the database.
  """

  @minimum_products 3
  @abandoned_after_days 90

  @doc """
  Evaluates the four disqualifiers against `now`.

  Returns `{true, []}` or `{false, disqualifiers}` where every failed
  check reports — a merchant fixing their shop deserves the whole list,
  not one item per attempt.
  """
  @spec evaluate(map(), DateTime.t()) :: {boolean(), [atom()]}
  def evaluate(signals, %DateTime{} = now) do
    disqualifiers =
      [
        incomplete: incomplete?(signals),
        no_payout: no_payout?(signals),
        abandoned: abandoned?(signals, now),
        conduct: conduct?(signals)
      ]
      |> Enum.filter(fn {_name, failed?} -> failed? end)
      |> Enum.map(fn {name, _} -> name end)

    {disqualifiers == [], disqualifiers}
  end

  # A shop that would look broken in a big slot: no picture, no words, no
  # way to be reached, nowhere on the map, or a near-empty shelf.
  defp incomplete?(signals) do
    missing_image? = blank?(signals.logo_url) and blank?(signals.cover_image_url)
    missing_words? = blank?(signals.tagline) and blank?(signals.description)

    missing_contact? =
      blank?(signals.contact_phone) and blank?(signals.whatsapp_number) and
        blank?(signals.contact_email)

    missing_image? or missing_words? or missing_contact? or blank?(signals.region) or
      signals.product_count < @minimum_products
  end

  # No verified payout account means an order strands the buyer's money —
  # the hardest bar of the four.
  defp no_payout?(signals), do: not signals.payout_verified?

  # Quiet on every clock for 90 days. The store's own creation date joins
  # the max deliberately: without it a brand-new shop with no orders and no
  # republished product is "abandoned" on day one, and the growth slot can
  # never fill. That grace period is the most important line in this module.
  defp abandoned?(signals, now) do
    [signals.last_product_published_at, signals.last_order_at, signals.inserted_at]
    |> Enum.reject(&is_nil/1)
    |> Enum.max(DateTime)
    |> DateTime.diff(now, :day)
    |> Kernel.<(-@abandoned_after_days)
  end

  # A recent product takedown, or a suspension/block on the platform audit
  # record (the worker folds that log into one flag per store).
  defp conduct?(signals) do
    signals.taken_down_products_90d >= 1 or signals.conduct_flagged?
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
end
