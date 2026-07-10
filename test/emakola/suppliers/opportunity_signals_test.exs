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
end
