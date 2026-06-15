defmodule Emakola.Platform.StatsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Platform.Stats

  # ── existing stats tests kept for regression ──────────────────────

  describe "store/merchant/order counts" do
    test "total_stores/0 counts all stores" do
      Factory.create_store!()
      Factory.create_store!()
      assert Stats.total_stores() >= 2
    end

    test "total_merchants/0 counts all merchants" do
      Factory.create_merchant!()
      assert Stats.total_merchants() >= 1
    end
  end

  # ── payment aggregations ───────────────────────────────────────────

  describe "payments" do
    setup do
      store_a = Factory.create_store!()
      store_b = Factory.create_store!()
      %{store_a: store_a, store_b: store_b}
    end

    # Seed helper: create a payment and drive it to the given status.
    defp pay!(store, gateway, status, attrs \\ %{}) do
      p =
        Factory.create_payment!(
          store,
          Map.merge(%{gateway: gateway, amount: 10_000}, attrs)
        )

      case status do
        :success ->
          p
          |> Ash.Changeset.for_update(:mark_success, %{})
          |> Ash.update!(authorize?: false)

        :failed ->
          p
          |> Ash.Changeset.for_update(:mark_failed, %{})
          |> Ash.update!(authorize?: false)

        :refunded ->
          succeeded =
            p
            |> Ash.Changeset.for_update(:mark_success, %{})
            |> Ash.update!(authorize?: false)

          succeeded
          |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: succeeded.amount})
          |> Ash.update!(authorize?: false)

        :pending ->
          p
      end
    end

    test "total_payments/0 counts across both stores", %{store_a: a, store_b: b} do
      before = Stats.total_payments()
      pay!(a, :paystack, :success)
      pay!(b, :hubtel, :failed)
      assert Stats.total_payments() == before + 2
    end

    test "successful_payment_count/0 counts only :success", %{store_a: a, store_b: b} do
      before = Stats.successful_payment_count()
      pay!(a, :paystack, :success)
      pay!(b, :hubtel, :success)
      pay!(a, :paystack, :failed)
      assert Stats.successful_payment_count() == before + 2
    end

    test "failed_payment_count/0 counts only :failed", %{store_a: a, store_b: b} do
      before = Stats.failed_payment_count()
      pay!(a, :paystack, :failed)
      pay!(b, :hubtel, :failed)
      pay!(a, :paystack, :success)
      assert Stats.failed_payment_count() == before + 2
    end

    test "total_refunded/0 sums refunded_amount across stores", %{store_a: a, store_b: b} do
      before = Stats.total_refunded()
      pay!(a, :paystack, :refunded, %{amount: 20_000})
      pay!(b, :hubtel, :refunded, %{amount: 5_000})
      pay!(a, :paystack, :success)
      # refunded_amount equals the payment's own amount (20_000 + 5_000 = 25_000)
      assert Stats.total_refunded() == before + 20_000 + 5_000
    end

    test "payment_gateway_breakdown/0 returns per-gateway success/failed counts and volume",
         %{store_a: a, store_b: b} do
      before = Stats.payment_gateway_breakdown()
      before_ps = before[:paystack]
      before_hb = before[:hubtel]

      # Paystack: 2 success, 1 failed
      pay!(a, :paystack, :success, %{amount: 30_000})
      pay!(b, :paystack, :success, %{amount: 20_000})
      pay!(a, :paystack, :failed)

      # Hubtel: 1 success, 1 failed
      pay!(b, :hubtel, :success, %{amount: 15_000})
      pay!(a, :hubtel, :failed)

      result = Stats.payment_gateway_breakdown()

      assert result[:paystack].success_count == before_ps.success_count + 2
      assert result[:paystack].failed_count == before_ps.failed_count + 1
      assert result[:paystack].success_volume == before_ps.success_volume + 50_000

      assert result[:hubtel].success_count == before_hb.success_count + 1
      assert result[:hubtel].failed_count == before_hb.failed_count + 1
      assert result[:hubtel].success_volume == before_hb.success_volume + 15_000
    end

    test "recent_failed_payments/1 returns only :failed, newest first, with store preloaded",
         %{store_a: a, store_b: b} do
      p1 = pay!(a, :paystack, :failed, %{customer_email: "fail-a@example.com"})
      p2 = pay!(b, :hubtel, :failed, %{customer_email: "fail-b@example.com"})
      _ok = pay!(a, :paystack, :success)

      results = Stats.recent_failed_payments(10)

      emails = Enum.map(results, & &1.customer_email)
      assert "fail-a@example.com" in emails
      assert "fail-b@example.com" in emails

      # No non-failed payments
      assert Enum.all?(results, &(&1.status == :failed))

      # Store preloaded
      found = Enum.find(results, &(&1.id == p1.id))
      assert found.store.name == a.name

      found2 = Enum.find(results, &(&1.id == p2.id))
      assert found2.store.name == b.name

      # Newest first: p2 was inserted after p1
      ids = Enum.map(results, & &1.id)
      p1_idx = Enum.find_index(ids, &(&1 == p1.id))
      p2_idx = Enum.find_index(ids, &(&1 == p2.id))
      assert p2_idx < p1_idx
    end

    test "recent_refunded_payments/1 returns only :refunded", %{store_a: a, store_b: b} do
      pay!(a, :paystack, :refunded)
      pay!(b, :hubtel, :refunded)
      pay!(a, :paystack, :failed)

      results = Stats.recent_refunded_payments(10)

      assert Enum.all?(results, &(&1.status == :refunded))
      assert length(results) >= 2
    end
  end
end
