defmodule Emakola.Notifications.SusuTemplatesTest do
  @moduledoc """
  TC-3 susu lay-away lifecycle notification copy (Task 8).

  Pre-completion buyer/merchant templates are PLAN-based (no order exists
  yet) and the buyer-facing ones must embed a SIGNED susu-plan link
  (`EmakolaWeb.SusuTokens.sign_susu_plan/1`) so a viewer can act on
  `EmakolaWeb.Storefront.SusuLinkLive` without signing in.
  `:susu_completed`/`:susu_merchant_completed` are order-based and mirror
  the TC-2 protection templates' signed-tracking-link pattern instead.
  """
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Templates
  alias EmakolaWeb.SusuTokens
  alias EmakolaWeb.TrackingTokens

  defp plan(attrs \\ %{}) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        code: "SUSU1234",
        contributed_amount: 5_000,
        total_amount: 15_000,
        deadline: DateTime.add(DateTime.utc_now(), 10, :day)
      },
      attrs
    )
  end

  defp store do
    %{name: "Adom Boutique", id: "susu-store-id", slug: "adom-boutique", currency: "GHS"}
  end

  defp order do
    %{
      id: Ash.UUID.generate(),
      order_number: "ORD-20260330-SUSU01",
      store_id: "susu-store-id"
    }
  end

  defp susu_token(msg) do
    msg |> String.split("?t=") |> List.last() |> String.trim()
  end

  # ── Pre-completion buyer templates ──────────────────────────────

  describe "susu_activated_sms/2" do
    test "reports progress and includes a signed susu-plan link" do
      msg = Templates.susu_activated_sms(plan(), store())

      assert msg =~ "active"
      assert msg =~ "50.00"
      assert msg =~ "150.00"
      assert msg =~ "/susu/SUSU1234?t="
    end

    test "the embedded token verifies to this plan's id" do
      buyer_plan = plan()
      msg = Templates.susu_activated_sms(buyer_plan, store())

      assert {:ok, plan_id} = SusuTokens.verify_susu_plan(susu_token(msg))
      assert plan_id == buyer_plan.id
    end
  end

  describe "susu_chunk_received_sms/2" do
    test "reports progress and includes a signed susu-plan link" do
      msg = Templates.susu_chunk_received_sms(plan(), store())

      assert msg =~ "Chunk received"
      assert msg =~ "50.00"
      assert msg =~ "/susu/SUSU1234?t="
    end
  end

  describe "susu_nudge_sms/2" do
    test "reports the remaining balance and includes a signed link" do
      msg = Templates.susu_nudge_sms(plan(), store())

      assert msg =~ "week"
      assert msg =~ "100.00"
      assert msg =~ "/susu/SUSU1234?t="
    end
  end

  describe "susu_deadline_warning_sms/2" do
    # `deadline_days_left/1` floors `DateTime.diff(deadline, now, :day)` — a
    # deadline set to exactly "N days from now" can truncate down to N-1 by
    # the time the template function reads `DateTime.utc_now/0` a moment
    # later, so fixtures pad with a few extra hours to keep the floor
    # landing on the intended day count.
    test "interpolates the real number of days left and includes a signed link" do
      near_plan =
        plan(%{
          deadline: DateTime.utc_now() |> DateTime.add(3, :day) |> DateTime.add(1, :hour)
        })

      msg = Templates.susu_deadline_warning_sms(near_plan, store())

      assert msg =~ "3 days"
      assert msg =~ "100.00"
      assert msg =~ "/susu/SUSU1234?t="
    end

    test "singularizes a single day left" do
      near_plan =
        plan(%{
          deadline: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.add(1, :hour)
        })

      msg = Templates.susu_deadline_warning_sms(near_plan, store())

      assert msg =~ "1 day!"
      refute msg =~ "1 days"
    end
  end

  describe "susu_refunded_sms/3" do
    test "confirms the refund amount, no signed link (nothing left to do)" do
      msg = Templates.susu_refunded_sms(plan(), store(), 5_000)

      assert msg =~ "ended"
      assert msg =~ "50.00"
      assert msg =~ "refunded"
      refute msg =~ "?t="
    end

    # The real bug this arg exists for: `plan.contributed_amount` is 0 on
    # the insufficient-stock path (the activating chunk's payment
    # succeeded but was flagged for refund instead of counted), even
    # though real money is being refunded — the caller must pass the
    # ACTUAL refunded figure, not read it off the plan.
    test "shows the real refunded amount even when the plan's contributed_amount is 0" do
      zero_cost_plan = plan(%{contributed_amount: 0})

      msg = Templates.susu_refunded_sms(zero_cost_plan, store(), 3_000)

      assert msg =~ "30.00"
      refute msg =~ "₵0.00"
    end
  end

  # ── Pre-completion merchant templates ───────────────────────────

  describe "susu_merchant_activated_sms/2" do
    test "names the plan code and the buyer's first-chunk amount" do
      msg = Templates.susu_merchant_activated_sms(plan(), store())

      assert msg =~ "SUSU1234"
      assert msg =~ "50.00"
      refute msg =~ "?t="
    end
  end

  describe "susu_merchant_expired_sms/2" do
    test "names the plan code and mentions the refund" do
      msg = Templates.susu_merchant_expired_sms(plan(), store())

      assert msg =~ "SUSU1234"
      assert msg =~ "refunded"
    end
  end

  # ── Post-completion, order-based templates ──────────────────────

  describe "susu_completed_sms/2" do
    test "names the order and includes a signed order-tracking link" do
      buyer_order = order()
      msg = Templates.susu_completed_sms(buyer_order, store())

      assert msg =~ "ORD-20260330-SUSU01"
      assert msg =~ "complete"
      assert msg =~ "/s/adom-boutique/track/ORD-20260330-SUSU01?t="
    end

    test "the embedded token verifies to the order's id" do
      buyer_order = order()
      msg = Templates.susu_completed_sms(buyer_order, store())

      token = msg |> String.split("?t=") |> List.last() |> String.trim()
      assert {:ok, order_id} = TrackingTokens.verify_order_tracking(token)
      assert order_id == buyer_order.id
    end
  end

  describe "susu_merchant_completed_sms/2" do
    test "names the order, no buyer tracking link" do
      msg = Templates.susu_merchant_completed_sms(order(), store())

      assert msg =~ "ORD-20260330-SUSU01"
      assert msg =~ "completed"
      refute msg =~ "?t="
    end
  end
end
