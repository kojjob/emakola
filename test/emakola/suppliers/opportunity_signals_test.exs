defmodule Emakola.Suppliers.OpportunitySignalsTest do
  use Emakola.DataCase, async: true

  require Ash.Query
  alias Emakola.Suppliers.OpportunitySignals

  test "stores a fingerprint and matched products but never a raw search" do
    assert :ok = OpportunitySignals.track_search("store-1", "School Bags for Ama", [%{id: "p1"}])

    [event] =
      Emakola.Analytics.AppEvent
      |> Ash.Query.filter(event_name == "earn.catalog_search")
      |> Ash.read!(authorize?: false)

    assert event.metadata["query_fingerprint"] ==
             OpportunitySignals.fingerprint("school bags for ama")

    assert event.metadata["matched_product_ids"] == ["p1"]
    refute Map.has_key?(event.metadata, "query")
    refute inspect(event.metadata) =~ "School Bags for Ama"
  end

  test "emits one aggregate-only supplier alert per offer per day" do
    radar = [
      %{
        supplier_alert?: true,
        offer_id: "offer-1",
        wholesaler_store_id: "supplier-store",
        title: "School Bag",
        views: 25,
        searches: 8,
        orders: 0
      }
    ]

    assert :ok = OpportunitySignals.emit_supplier_alerts(radar)
    assert :ok = OpportunitySignals.emit_supplier_alerts(radar)
    assert {:ok, [alert]} = OpportunitySignals.supplier_alerts("supplier-store")
    assert alert.metadata["views"] == 25
    assert alert.metadata["matched_searches"] == 8
    refute Map.has_key?(alert.metadata, "query")
    refute Map.has_key?(alert.metadata, "customer_id")
  end

  test "dedup is scoped per offer — a second offer alerts even on the same day" do
    item = fn offer_id ->
      %{
        supplier_alert?: true,
        offer_id: offer_id,
        wholesaler_store_id: "supplier-store",
        title: "Item #{offer_id}",
        views: 10,
        searches: 2,
        orders: 0
      }
    end

    assert :ok = OpportunitySignals.emit_supplier_alerts([item.("offer-1")])
    assert :ok = OpportunitySignals.emit_supplier_alerts([item.("offer-2")])

    assert {:ok, alerts} = OpportunitySignals.supplier_alerts("supplier-store")
    assert Enum.map(alerts, & &1.metadata["offer_id"]) |> Enum.sort() == ["offer-1", "offer-2"]
  end

  test "supplier_alerts/2 excludes another wholesaler's alerts" do
    mine = %{
      supplier_alert?: true,
      offer_id: "offer-mine",
      wholesaler_store_id: "my-store",
      title: "Mine",
      views: 5,
      searches: 1,
      orders: 0
    }

    theirs = %{
      supplier_alert?: true,
      offer_id: "offer-theirs",
      wholesaler_store_id: "their-store",
      title: "Theirs",
      views: 5,
      searches: 1,
      orders: 0
    }

    assert :ok = OpportunitySignals.emit_supplier_alerts([mine, theirs])

    assert {:ok, [alert]} = OpportunitySignals.supplier_alerts("my-store")
    assert alert.metadata["offer_id"] == "offer-mine"
  end
end
