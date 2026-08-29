defmodule EmakolaWeb.Admin.SupplyNetworkLive.PresentationTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  test "connection presentation uses the current store's side of the relationship" do
    connection = %{
      status: :pending,
      wholesaler_store_id: "wholesaler",
      reseller_store_id: "reseller",
      requested_by_store_id: "reseller",
      wholesaler_store: %{name: "Wholesale Store"},
      reseller_store: %{name: "Reseller Store"}
    }

    assert Presentation.partner(connection, "wholesaler").name == "Reseller Store"
    assert Presentation.relationship_label(connection, "wholesaler") == "You supply this store"
    assert Presentation.incoming?(connection, "wholesaler")

    assert Presentation.partner(connection, "reseller").name == "Wholesale Store"

    assert Presentation.relationship_label(connection, "reseller") ==
             "You sell this store's products"

    refute Presentation.incoming?(connection, "reseller")
  end

  test "money ranges expose exact merchant economics" do
    offer = %{
      offer_variants: [
        %{supplier_price: 5_000, suggested_retail_price: 6_500},
        %{supplier_price: 7_000, suggested_retail_price: 9_500}
      ]
    }

    assert Presentation.earning_range(offer) == "GH₵15.00–GH₵25.00"
    assert Presentation.retail_range(offer) == "GH₵65.00–GH₵95.00"
    assert Presentation.money(30_000) == "GH₵300.00"
  end

  test "select options retain product context and stable resource IDs" do
    offers = [
      %{
        id: "offer-1",
        source_product: %{title: "Kente Bag"},
        offer_variants: [%{id: "variant-123456789"}]
      }
    ]

    listings = [
      %{
        reseller_product: %{title: "Kente Bag"},
        listing_variants: [%{id: "mapping-1", retail_price: 6_500}]
      }
    ]

    assert Presentation.inventory_policy_options(offers) == [
             {"Kente Bag · varian", "variant-123456789"}
           ]

    assert Presentation.franchise_offer_options(offers) == [{"Kente Bag", "offer-1"}]
    assert Presentation.group_buy_options(listings) == [{"Kente Bag — GH₵65.00", "mapping-1"}]
  end

  test "error copy remains specific for recoverable policy failures" do
    assert Presentation.inventory_error(:not_eligible) =~ "passport tier"
    assert Presentation.group_buy_error(:refund_deadline_invalid) =~ "after"
    assert Presentation.sales_team_error(:split_total_must_equal_10000) =~ "100%"
    assert Presentation.franchise_error(:package_incomplete) =~ "training"
  end

  test "customer city accepts persisted string or atom address keys" do
    assert Presentation.customer_city(%{shipping_address: %{"city" => "Accra"}}) == "Accra"
    assert Presentation.customer_city(%{shipping_address: %{city: "Kumasi"}}) == "Kumasi"

    assert Presentation.customer_city(%{shipping_address: nil}) ==
             "Delivery address on order"
  end

  describe "fulfillment_status_classes/1" do
    # There is no catch-all clause on this function, so a status the merchant
    # can actually reach and this module has never heard of takes the whole
    # supply-network page down with a FunctionClauseError.
    test "covers every status a Fulfillment can hold" do
      statuses =
        Emakola.Orders.Fulfillment
        |> Ash.Resource.Info.attribute(:status)
        |> Map.fetch!(:constraints)
        |> Keyword.fetch!(:one_of)

      for status <- statuses do
        assert is_binary(Presentation.fulfillment_status_classes(status)),
               "fulfillment_status_classes/1 has no clause for #{inspect(status)}"
      end
    end
  end
end
