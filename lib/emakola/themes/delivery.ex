defmodule Emakola.Themes.Delivery do
  @moduledoc """
  What a store can truthfully say about delivery.

  Every claim here is derived from the merchant's own
  `Emakola.Shipping.DeliveryZone` rows — the same rows the checkout charges
  from, so what the storefront promises and what the customer pays come from
  one source.

  Themes used to hardcode these promises: "Free delivery on orders over GHS
  500", "Same-Day Delivery in Accra", "30-day returns". The merchant never
  wrote them, could not edit them, and two themes stated different numbers for
  the same store. **A store that has configured no zones has promised nothing**,
  so every function here returns `nil` for it, and the theme falls back to
  linking the merchant's own policies page — which is authoritative.

  Returns and warranty are not derived — they are a promise, so only the
  merchant can make one. They live in `Emakola.Themes.Terms`, which reads what
  the merchant typed and says nothing when they have typed nothing.
  """

  alias EmakolaWeb.Helpers.Currency

  @doc "The store's active delivery zones, from the assigns map the LiveViews already build."
  def zones(assigns) do
    assigns
    |> Map.get(:delivery_zones)
    |> List.wrap()
    |> Enum.filter(&Map.get(&1, :active, true))
  end

  @doc """
  The store's free-delivery offer, or `nil` when it has made none.

  Returns `%{threshold: pesewas, zones: nil | "Accra, Tema"}`. When several
  zones carry different thresholds the lowest one is reported *scoped to the
  zones that actually offer it* — saying "free over GH₵200" unscoped would
  overpromise for a zone that is only free over GH₵500. `zones: nil` means the
  offer holds everywhere the store delivers.
  """
  def free_delivery(zones) do
    case Enum.filter(zones, &is_integer(&1.free_above_pesewas)) do
      [] ->
        nil

      offering ->
        threshold = offering |> Enum.map(& &1.free_above_pesewas) |> Enum.min()
        at_threshold = Enum.filter(offering, &(&1.free_above_pesewas == threshold))

        %{
          threshold: threshold,
          zones: if(length(at_threshold) == length(zones), do: nil, else: names(at_threshold))
        }
    end
  end

  @doc """
  The store's own delivery estimate — "Same day", "Next day", "About 3 days",
  or "1–3 days" when zones differ. `nil` when the store has configured none.
  """
  def estimate(zones) do
    case zones |> Enum.map(& &1.estimated_days) |> Enum.reject(&is_nil/1) do
      [] ->
        nil

      days ->
        {low, high} = Enum.min_max(days)
        if low == high, do: label(low), else: "#{low}–#{high} days"
    end
  end

  @doc ~S(The zones the store delivers to — "Accra, Tema" — or `nil` when it has configured none.)
  def zone_names([]), do: nil
  def zone_names(zones), do: names(zones)

  @doc """
  The free-delivery offer as one line: "Free delivery over GH₵ 200" (or
  "… in Accra" when it is scoped). `nil` when the store has made no offer.
  """
  def free_delivery_line(zones, currency) do
    case free_delivery(zones) do
      nil ->
        nil

      %{threshold: threshold, zones: nil} ->
        "Free delivery over #{Currency.format_price(threshold, currency)}"

      %{threshold: threshold, zones: scope} ->
        "Free delivery over #{Currency.format_price(threshold, currency)} in #{scope}"
    end
  end

  @doc ~S"""
  The detail half of a "Free delivery" pill, where the title already says
  "Free delivery": `"Over GH₵ 200 · Accra, Tema"`. Names the zones it applies
  to, so a shopper knows where the offer actually reaches.
  """
  def free_delivery_detail(zones, currency) do
    case free_delivery(zones) do
      nil ->
        nil

      %{threshold: threshold, zones: scope} ->
        case scope || zone_names(zones) do
          nil -> "Over #{Currency.format_price(threshold, currency)}"
          where -> "Over #{Currency.format_price(threshold, currency)} · #{where}"
        end
    end
  end

  @doc """
  The cheapest delivery the store charges, as a line: `"From GH₵ 15"`.

  `nil` when no active zone carries a fee at all, and also when the cheapest is
  zero — "From GH₵ 0" is not a price, and a store that delivers free somewhere
  says so through its free-delivery offer instead.

  The number is `DeliveryZone.fee`, the same row checkout charges from, so the
  product page and the bill cannot disagree.
  """
  def from_fee_line(zones, currency) do
    zones
    |> Enum.map(& &1.fee)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
    |> case do
      nil -> nil
      0 -> nil
      cheapest -> "From #{Currency.format_price(cheapest, currency)}"
    end
  end

  @doc """
  The one line a product page can honestly say about delivery — the store's
  free-delivery offer if it has one, else what it charges and how long it
  takes, else `nil`. A `nil` means the page says nothing, which is what a store
  that has configured nothing has earned.

  Cost leads when there is one: "how much is delivery" is the question
  merchants answer on WhatsApp all day, and the store has already answered it
  in its zones.
  """
  def callout(assigns) do
    zones = zones(assigns)
    currency = assigns.store.currency

    free_delivery_line(zones, currency) ||
      compose(from_fee_line(zones, currency), estimate(zones), zone_names(zones))
  end

  defp compose(nil, nil, _names), do: nil
  defp compose(nil, estimate, nil), do: estimate
  defp compose(nil, estimate, names), do: "#{estimate} to #{names}"
  defp compose(fee, nil, nil), do: fee
  defp compose(fee, nil, names), do: "#{fee} to #{names}"
  defp compose(fee, estimate, nil), do: "#{fee} · #{estimate}"
  defp compose(fee, estimate, names), do: "#{fee} · #{estimate} to #{names}"

  defp names(zones), do: zones |> Enum.map(& &1.name) |> Enum.join(", ")

  defp label(0), do: "Same day"
  defp label(1), do: "Next day"
  defp label(n), do: "About #{n} days"
end
