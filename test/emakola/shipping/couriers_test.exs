defmodule Emakola.Shipping.CouriersTest do
  @moduledoc """
  A tracking number is only useful if the buyer knows where to type it.

  URL templates are only included for couriers whose public tracking URL is
  known. Guessing one produces a link that 404s on someone else's site, which
  is worse than showing the number plainly — so an unknown courier returns nil
  and the number renders as text.
  """
  use ExUnit.Case, async: true

  alias Emakola.Shipping.Couriers

  test "lists couriers a Ghanaian merchant plausibly uses" do
    ids = Enum.map(Couriers.list(), & &1.id)

    assert :dhl in ids
    assert :ems_ghana in ids
    assert :other in ids
  end

  test "every listed courier has a human label" do
    for courier <- Couriers.list() do
      assert is_binary(courier.label) and courier.label != ""
    end
  end

  test "builds a tracking URL for a courier with a known template" do
    url = Couriers.tracking_url(:dhl, "1234567890")

    assert is_binary(url)
    assert url =~ "1234567890"
    assert String.starts_with?(url, "https://")
  end

  # The number is user-controlled and goes into a query string.
  test "escapes the tracking number" do
    url = Couriers.tracking_url(:dhl, "12 34&x=1")

    refute url =~ "&x=1"
  end

  test "returns nil rather than guessing a URL" do
    assert is_nil(Couriers.tracking_url(:other, "1234567890"))
    assert is_nil(Couriers.tracking_url(nil, "1234567890"))
    assert is_nil(Couriers.tracking_url(:dhl, nil))
    assert is_nil(Couriers.tracking_url(:dhl, ""))
  end

  test "an unknown courier id is not a crash" do
    assert is_nil(Couriers.tracking_url(:not_a_courier, "123"))
    assert Couriers.label(:not_a_courier) == "Courier"
  end

  # The resource inlines its one_of to avoid a compile-order dependency on this
  # module. That is only safe if something fails loudly when they drift.
  test "stays in lockstep with Order's :courier one_of constraint" do
    one_of =
      Emakola.Orders.Order
      |> Ash.Resource.Info.attribute(:courier)
      |> Map.fetch!(:constraints)
      |> Keyword.fetch!(:one_of)

    assert Enum.sort(one_of) == Enum.sort(Couriers.ids())
  end
end
