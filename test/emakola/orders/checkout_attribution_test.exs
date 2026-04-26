defmodule Emakola.Orders.CheckoutAttributionTest do
  @moduledoc """
  Pins the contract for attribution persistence at checkout:

    * When `:attribution` is passed in opts, it lands on `Order.attribution`
    * When omitted, `Order.attribution` defaults to `%{}` (resource default)
    * Attribution map is stored verbatim — the checkout layer doesn't transform
      keys/values
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Orders.CheckoutService

  setup do
    store = Factory.create_store!(%{name: "Attribution Shop", slug: "attribution-shop"})
    product = Factory.create_product!(store, %{title: "Test Item"})
    variant = Factory.create_variant!(product, store, %{price: 5_000, stock_quantity: 10})
    {:ok, store: store, product: product, variant: variant}
  end

  describe "checkout!/3 — attribution opt" do
    test "persists attribution map onto Order when supplied", %{store: store, variant: variant} do
      attribution = %{
        "utm_source" => "instagram",
        "utm_medium" => "bio_link",
        "utm_campaign" => "spring-2026",
        "first_seen_at" => "2026-04-26T08:21:11Z"
      }

      assert {:ok, order} =
               CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 1}],
                 attribution: attribution
               )

      assert order.attribution == attribution
    end

    test "stores click_to_whatsapp flag verbatim", %{store: store, variant: variant} do
      attribution = %{
        "utm_source" => "whatsapp",
        "click_to_whatsapp" => true
      }

      assert {:ok, order} =
               CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 1}],
                 attribution: attribution
               )

      assert order.attribution["click_to_whatsapp"] == true
      assert order.attribution["utm_source"] == "whatsapp"
    end

    test "defaults to empty map when attribution opt omitted", %{store: store, variant: variant} do
      assert {:ok, order} =
               CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 1}],
                 []
               )

      assert order.attribution == %{}
    end

    test "stores empty attribution map verbatim", %{store: store, variant: variant} do
      assert {:ok, order} =
               CheckoutService.checkout!(
                 store.id,
                 [%{variant_id: variant.id, quantity: 1}],
                 attribution: %{}
               )

      assert order.attribution == %{}
    end
  end
end
