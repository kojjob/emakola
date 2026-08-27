defmodule Emakola.Notifications.TrackingSmsTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates

  # ── Test data ──────────────────────────────────────────────────

  defp order do
    %{
      order_number: "ORD-20260327-TRK001",
      total: 35_000,
      currency: "GHS",
      store_id: "tracking-store-id"
    }
  end

  defp order_with_tracking_url do
    Map.put(order(), :tracking_url, "https://dhl.com/track/DHL12345")
  end

  defp store do
    %{name: "Kente Kingdom", id: "tracking-store-id", slug: "kente-kingdom"}
  end

  # ── Shipped SMS with external tracking URL ─────────────────────

  describe "order_shipped_sms/2 with external tracking URL" do
    test "includes the external tracking URL when order has tracking_url" do
      msg = Templates.order_shipped_sms(order_with_tracking_url(), store())

      assert msg =~ "shipped"
      assert msg =~ "ORD-20260327-TRK001"
      assert msg =~ "Kente Kingdom"
      assert msg =~ "Track here: https://dhl.com/track/DHL12345"
    end

    test "does not include storefront URL when external tracking URL is present" do
      msg = Templates.order_shipped_sms(order_with_tracking_url(), store())

      refute msg =~ "Track at:"
      refute msg =~ "/kente-kingdom/track/"
    end
  end

  # ── Shipped SMS with storefront tracking URL ───────────────────

  describe "order_shipped_sms/2 without external tracking URL" do
    test "includes storefront tracking URL when order has no tracking_url" do
      msg = Templates.order_shipped_sms(order(), store())

      assert msg =~ "shipped"
      assert msg =~ "ORD-20260327-TRK001"
      assert msg =~ "Kente Kingdom"
      assert msg =~ "Track at:"
      assert msg =~ "/kente-kingdom/track/ORD-20260327-TRK001"
    end

    test "does not include 'Track here:' when no external tracking URL" do
      msg = Templates.order_shipped_sms(order(), store())

      refute msg =~ "Track here:"
    end

    test "storefront URL uses the store slug" do
      custom_store = %{name: "Accra Styles", id: "other-id", slug: "accra-styles"}
      msg = Templates.order_shipped_sms(order(), custom_store)

      assert msg =~ "/accra-styles/track/"
    end
  end

  # ── Template output format ─────────────────────────────────────

  describe "order_shipped_sms/2 output format" do
    test "with external tracking URL produces expected message format" do
      msg = Templates.order_shipped_sms(order_with_tracking_url(), store())

      assert msg ==
               "Your order ORD-20260327-TRK001 from Kente Kingdom has been shipped! " <>
                 "Track here: https://dhl.com/track/DHL12345"
    end

    test "without tracking URL produces expected message format with storefront URL" do
      msg = Templates.order_shipped_sms(order(), store())

      assert msg =~
               ~r/Your order ORD-20260327-TRK001 from Kente Kingdom has been shipped! Track at: https?:\/\/.+\/kente-kingdom\/track\/ORD-20260327-TRK001/
    end

    test "nil tracking_url falls back to storefront URL" do
      order_nil_tracking = Map.put(order(), :tracking_url, nil)
      msg = Templates.order_shipped_sms(order_nil_tracking, store())

      assert msg =~ "Track at:"
      refute msg =~ "Track here:"
    end
  end
end
