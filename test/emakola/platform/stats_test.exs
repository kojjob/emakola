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

    test "active_stores/0 excludes an archived store" do
      # `active` is the merchant's own open/closed switch; `status` is the
      # platform's. Archiving leaves `active` true, so a count that reads only
      # the merchant switch reported stores the marketplace no longer serves —
      # the tile said 41 while /stores showed 39.
      live = Factory.create_store!()
      archived = Factory.create_store!()

      before = Stats.active_stores()

      archived
      |> Ash.Changeset.for_update(:archive, %{reason: "test"}, authorize?: false)
      |> Ash.update!()

      assert Stats.active_stores() == before - 1
      assert live.id != archived.id
    end

    test "active_stores/0 excludes a suspended store" do
      store = Factory.create_store!()
      before = Stats.active_stores()

      store
      |> Ash.Changeset.for_update(:suspend, %{reason: "test"}, authorize?: false)
      |> Ash.update!()

      assert Stats.active_stores() == before - 1
    end

    test "total_stores/0 still counts an archived store" do
      # The platform view deliberately sees everything; only the active tile
      # narrows. Otherwise archiving a store would make it vanish from the
      # platform's own records.
      store = Factory.create_store!()
      before = Stats.total_stores()

      store
      |> Ash.Changeset.for_update(:archive, %{reason: "test"}, authorize?: false)
      |> Ash.update!()

      assert Stats.total_stores() == before
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

  # ── time series for the platform overview charts ───────────────────

  describe "time series" do
    test "gmv_by_day/1 returns one filled bucket per day with today's GMV last" do
      store = Factory.create_store!()

      payment = Factory.create_payment!(store, %{amount: 10_000})

      {:ok, _} =
        payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update(authorize?: false)

      %{labels: labels, values: values} = Stats.gmv_by_day(7)

      assert length(labels) == 7
      assert length(values) == 7
      assert List.last(values) >= 10_000
    end

    test "new_stores_by_week/1 returns one bucket per week counting this week's stores" do
      Factory.create_store!()

      %{labels: labels, values: values} = Stats.new_stores_by_week(8)

      assert length(labels) == 8
      assert length(values) == 8
      assert List.last(values) >= 1
    end
  end

  describe "stores page tiles" do
    defp backdate!(record, days) do
      Ash.Seed.update!(record, %{
        inserted_at: DateTime.add(DateTime.utc_now(), -days, :day)
      })
    end

    test "merchants_with_multiple_stores/0 counts merchants holding more than one store" do
      before = Stats.merchants_with_multiple_stores()

      {merchant, _store} = Factory.create_merchant_with_store!()
      Factory.create_store_membership!(merchant, Factory.create_store!(), :admin)
      {_single, _store} = Factory.create_merchant_with_store!()

      assert Stats.merchants_with_multiple_stores() == before + 1
    end

    test "merchants_joined_since/1 counts recent sign-ups only" do
      before = Stats.merchants_joined_since(7)

      Factory.create_merchant!()
      Factory.create_merchant!() |> backdate!(10)

      assert Stats.merchants_joined_since(7) == before + 1
    end

    test "orders, paid GMV and selling stores inside the window" do
      orders_before = Stats.orders_since(30)
      gmv_before = Stats.gmv_since(30)
      sellers_before = Stats.stores_with_orders_since(30)

      store = Factory.create_store!()
      Factory.create_order!(store)
      Factory.create_order!(store)
      store |> Factory.create_order!() |> backdate!(40)

      store
      |> Factory.create_payment!(amount: 5_000)
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

      store
      |> Factory.create_payment!(amount: 7_000)
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)
      |> backdate!(40)

      # A pending payment is not GMV.
      Factory.create_payment!(store, amount: 9_000)

      assert Stats.orders_since(30) == orders_before + 2
      assert Stats.gmv_since(30) == gmv_before + 5_000
      assert Stats.stores_with_orders_since(30) == sellers_before + 1
    end

    test "featured and featuring-eligible store counts" do
      featured_before = Stats.featured_stores()
      eligible_before = Stats.featuring_eligible_stores()

      featured = Factory.create_store!(featured: true)
      _plain = Factory.create_store!(featured: false)

      Emakola.Stores.DirectoryStanding
      |> Ash.Changeset.for_create(:record, %{
        store_id: featured.id,
        eligible: true,
        disqualifiers: [],
        score: 800,
        score_breakdown: %{},
        computed_at: DateTime.utc_now()
      })
      |> Ash.create!(authorize?: false)

      assert Stats.featured_stores() == featured_before + 1
      assert Stats.featuring_eligible_stores() == eligible_before + 1
    end
  end
end
