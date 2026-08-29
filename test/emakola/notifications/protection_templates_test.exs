defmodule Emakola.Notifications.ProtectionTemplatesTest do
  @moduledoc """
  TC-2 buyer protection lifecycle notification copy (Task 10).

  The two buyer-facing templates (`protection_held_sms/2`,
  `protection_delivery_nudge_sms/2`) must embed a SIGNED tracking link —
  `EmakolaWeb.TrackingTokens.sign_order_tracking/1` had no production caller
  before this — so a viewer of the link can act on `TrackingLive` (confirm
  receipt / file a complaint) without signing in. The merchant-facing
  templates carry no such link — the merchant already has dashboard access.
  """
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates
  alias EmakolaWeb.TrackingTokens

  defp order do
    %{
      id: Ash.UUID.generate(),
      order_number: "ORD-20260330-PRO001",
      total: 42_000,
      currency: "GHS",
      store_id: "protection-store-id"
    }
  end

  defp store do
    %{name: "Adom Boutique", id: "protection-store-id", slug: "adom-boutique"}
  end

  # ── Buyer templates ─────────────────────────────────────────────

  describe "protection_held_sms/2" do
    test "tells the buyer their payment is held and includes a signed tracking link" do
      buyer_order = order()
      msg = Templates.protection_held_sms(buyer_order, store())

      assert msg =~ "ORD-20260330-PRO001"
      assert msg =~ "held"
      assert msg =~ "confirm"
      assert msg =~ "/adom-boutique/track/ORD-20260330-PRO001?t="
    end

    test "the embedded token verifies to this order's id" do
      buyer_order = order()
      msg = Templates.protection_held_sms(buyer_order, store())

      token = msg |> String.split("?t=") |> List.last() |> String.trim()
      assert {:ok, order_id} = TrackingTokens.verify_order_tracking(token)
      assert order_id == buyer_order.id
    end
  end

  describe "protection_delivery_nudge_sms/2" do
    test "prompts the buyer to confirm receipt within the auto-release window and includes a signed link" do
      buyer_order = order()
      msg = Templates.protection_delivery_nudge_sms(buyer_order, store())

      assert msg =~ "ORD-20260330-PRO001"
      assert msg =~ "confirm"
      assert msg =~ "5 days"
      assert msg =~ "/adom-boutique/track/ORD-20260330-PRO001?t="
    end

    test "the embedded token verifies to this order's id" do
      buyer_order = order()
      msg = Templates.protection_delivery_nudge_sms(buyer_order, store())

      token = msg |> String.split("?t=") |> List.last() |> String.trim()
      assert {:ok, order_id} = TrackingTokens.verify_order_tracking(token)
      assert order_id == buyer_order.id
    end
  end

  # ── Merchant templates ──────────────────────────────────────────

  describe "protection_released_merchant_sms/2" do
    test "tells the merchant the hold has released, with no buyer tracking link" do
      msg = Templates.protection_released_merchant_sms(order(), store())

      assert msg =~ "ORD-20260330-PRO001"
      assert msg =~ "released"
      refute msg =~ "?t="
    end
  end

  describe "protection_complaint_merchant_sms/2" do
    test "tells the merchant a complaint froze the hold, with no buyer tracking link" do
      msg = Templates.protection_complaint_merchant_sms(order(), store())

      assert msg =~ "ORD-20260330-PRO001"
      assert msg =~ "complaint"
      assert msg =~ "held"
      refute msg =~ "?t="
    end
  end
end
