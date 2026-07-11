defmodule Emakola.Suppliers.OpportunityRadarTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.OpportunityRadar

  test "aggregates demand and only reveals regions at the privacy threshold" do
    product_id = "product-1"

    offer = %{
      id: "offer-1",
      source_product: %{title: "School Bag"},
      offer_variants: [
        %{
          supplier_price: 8_000,
          suggested_retail_price: 10_000,
          max_retail_price: 12_000,
          source_variant: %{stock_quantity: 12}
        }
      ]
    }

    listings = [%{offer_id: offer.id, reseller_product_id: product_id}]

    conversions =
      for id <- 1..3,
          do: %{
            order_id: "order-#{id}",
            order: %{
              fulfillments: [%{status: :delivered}],
              shipping_address: %{"city" => "Accra"}
            }
          }

    shares = [%{product_id: product_id, share_count: 4, conversions: conversions}]
    now = DateTime.utc_now()

    events = [
      %{
        event_name: "earn.product_view",
        metadata: %{"store_id" => "store-1", "product_id" => product_id},
        occurred_at: now
      },
      %{
        event_name: "earn.catalog_search",
        metadata: %{"store_id" => "store-1", "matched_product_ids" => [product_id]},
        occurred_at: now
      }
    ]

    [radar] = OpportunityRadar.build([offer], listings, shares, events, "store-1")
    assert radar.views == 1
    assert radar.searches == 1
    assert radar.shares == 4
    assert radar.fulfilled == 3
    assert radar.regions == [{"Accra", 3}]
    assert radar.stock == 12
    assert radar.explanation =~ "3 fulfilled"
    assert radar.freshness.observed_at == now
  end

  test "suppresses locations represented by fewer than three orders" do
    offer = %{
      id: "o",
      source_product: %{title: "Item"},
      offer_variants: [
        %{
          supplier_price: 100,
          suggested_retail_price: 200,
          max_retail_price: 250,
          source_variant: %{stock_quantity: 1}
        }
      ]
    }

    conversion = %{
      order_id: "order",
      order: %{fulfillments: [%{status: :delivered}], shipping_address: %{"city" => "Tamale"}}
    }

    [radar] =
      OpportunityRadar.build(
        [offer],
        [%{offer_id: "o", reseller_product_id: "p"}],
        [%{product_id: "p", share_count: 0, conversions: [conversion]}],
        [],
        "store"
      )

    assert radar.regions == []
  end
end
