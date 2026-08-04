defmodule EmakolaWeb.Admin.SupplyNetworkLive.InputsTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Admin.SupplyNetworkLive.Inputs

  test "connection attributes preserve the requested supply direction" do
    assert Inputs.connection_attrs("current", "partner", "supply") == %{
             wholesaler_store_id: "current",
             reseller_store_id: "partner",
             requested_by_store_id: "current"
           }

    assert Inputs.connection_attrs("current", "partner", "resell") == %{
             wholesaler_store_id: "partner",
             reseller_store_id: "current",
             requested_by_store_id: "current"
           }
  end

  test "group-buy inputs convert money and local datetimes at the boundary" do
    mapping = %{id: "mapping-1", listing_id: "listing-1"}

    assert Inputs.group_buy_attrs(
             %{
               "title" => "Ten bag circle",
               "threshold_quantity" => "10",
               "unit_price" => "60.00",
               "deadline" => "2026-08-11T12:30",
               "refund_deadline" => "2026-08-13T12:30"
             },
             mapping
           ) == %{
             listing_id: "listing-1",
             listing_variant_id: "mapping-1",
             title: "Ten bag circle",
             threshold_quantity: "10",
             unit_price: "6000",
             deadline: "2026-08-11T12:30:00Z",
             refund_deadline: "2026-08-13T12:30:00Z"
           }
  end

  test "group-buy defaults are deterministic from the supplied clock" do
    form = Inputs.group_buy_form(~U[2026-08-04 12:30:00Z])

    assert form.params["deadline"] == "2026-08-11T12:30"
    assert form.params["refund_deadline"] == "2026-08-13T12:30"
    assert form.params["threshold_quantity"] == "10"
  end

  test "percentage parsing produces basis points and rejects unsafe totals" do
    assert Inputs.percent_bps("60") == {:ok, 6_000}
    assert Inputs.percent_bps(" 40.25 ") == {:ok, 4_025}
    assert Inputs.percent_bps("0") == {:error, :invalid_percent}
    assert Inputs.percent_bps("101") == {:error, :invalid_percent}
    assert Inputs.percent_bps(nil) == {:error, :invalid_percent}
  end

  test "forms that coexist in streams receive stable distinct IDs" do
    first = Inputs.inventory_reservation_form("policy-1")
    second = Inputs.inventory_reservation_form("policy-2")
    appeal = Inputs.passport_appeal_form("signal-1")

    assert first.id == "inventory-reservation-policy-1"
    assert second.id == "inventory-reservation-policy-2"
    assert appeal.id == "appeal-signal-1"
  end

  test "franchise and income-goal params are translated without losing declared terms" do
    assert Inputs.franchise_attrs(%{
             "name" => "Accra seller kit",
             "offer_id" => "offer-1",
             "training" => "Product safety",
             "brand_rules" => "Approved facts only",
             "channel_permissions" => nil,
             "territory" => "Accra",
             "commission_bps" => "1000"
           }) == %{
             name: "Accra seller kit",
             offer_ids: ["offer-1"],
             training: %{"summary" => "Product safety"},
             brand_rules: %{"rules" => "Approved facts only"},
             channel_permissions: ["storefront"],
             territory: "Accra",
             commission_bps: "1000"
           }

    assert Inputs.income_goal_attrs(%{"target_amount" => "300.00", "timeframe_days" => "30"}) ==
             %{"target_amount" => "30000", "timeframe_days" => "30"}
  end
end
