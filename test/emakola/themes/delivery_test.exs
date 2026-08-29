defmodule Emakola.Themes.DeliveryTest do
  @moduledoc """
  The delivery callout should answer the question shoppers actually ask.

  "1–4 days to Greater Accra" answers half of it. What a merchant gets asked on
  WhatsApp all day is what delivery *costs*, and the store already told us:
  every zone carries a `fee`, and it is the same number checkout charges.

  Every line here is derived from zones the merchant configured. A store that
  has configured nothing still says nothing.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Delivery

  defp zone(attrs) do
    Map.merge(
      %{name: "Accra", fee: nil, estimated_days: nil, free_above_pesewas: nil, active: true},
      Map.new(attrs)
    )
  end

  defp assigns(zones), do: %{delivery_zones: zones, store: %{currency: "GHS"}}

  describe "callout/1 with a delivery fee" do
    test "leads with the cheapest zone's fee" do
      line =
        Delivery.callout(
          assigns([
            zone(name: "Accra", fee: 1500, estimated_days: 2),
            zone(name: "Kumasi", fee: 3000, estimated_days: 4)
          ])
        )

      assert line =~ "From GH₵ 15"
      assert line =~ "2–4 days"
      assert line =~ "Accra, Kumasi"
    end

    test "says the fee even when the store gave no delivery estimate" do
      assert Delivery.callout(assigns([zone(fee: 2000)])) =~ "From GH₵ 20"
    end

    test "a fee of zero is not announced as a price" do
      line = Delivery.callout(assigns([zone(fee: 0, estimated_days: 1)]))

      refute line =~ "From"
      refute line =~ "GH₵ 0"
      assert line =~ "Next day"
    end

    test "an inactive zone's cheaper fee is not quoted" do
      line =
        Delivery.callout(
          assigns([
            zone(name: "Accra", fee: 4000, estimated_days: 2),
            zone(name: "Ghost", fee: 100, estimated_days: 2, active: false)
          ])
        )

      assert line =~ "From GH₵ 40"
    end
  end

  describe "callout/1 without a fee to quote" do
    test "a free-delivery offer still wins the line" do
      line =
        Delivery.callout(
          assigns([zone(fee: 1500, estimated_days: 2, free_above_pesewas: 20_000)])
        )

      assert line =~ "Free delivery over GH₵ 200"
      refute line =~ "From GH₵ 15"
    end

    test "zones with no fee set fall back to the estimate alone" do
      assert Delivery.callout(assigns([zone(estimated_days: 3)])) == "About 3 days to Accra"
    end

    test "a store that configured nothing says nothing" do
      assert Delivery.callout(assigns([])) == nil
    end
  end
end
