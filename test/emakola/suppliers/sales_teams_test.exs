defmodule Emakola.Suppliers.SalesTeamsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query
  alias Emakola.Suppliers.SalesTeams

  test "requires exact flat splits and each member's consent before allocation" do
    {owner, store} = create_merchant_with_store!()
    seller = create_merchant!()

    assert {:ok, team} =
             SalesTeams.create(owner, store.id, "Launch crew", [
               %{merchant_id: owner.id, role: :owner, split_bps: 6_000},
               %{merchant_id: seller.id, role: :seller, split_bps: 4_000}
             ])

    assert {:error, :consent_incomplete} = SalesTeams.allocate(team, 10_001)
    invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
    assert is_nil(invited.consented_at)
    assert {:ok, accepted} = SalesTeams.accept(seller, invited.id)
    assert accepted.status == :active
    assert accepted.consented_at

    team = Ash.get!(Emakola.Suppliers.SalesTeam, team.id, authorize?: false)
    assert {:ok, allocations} = SalesTeams.allocate(team, 10_001)
    assert Enum.sum(Enum.map(allocations, & &1.amount)) == 10_001
    assert Enum.find(allocations, &(&1.role == :owner)).amount == 6_001
    assert Enum.find(allocations, &(&1.role == :seller)).amount == 4_000
  end

  test "rejects totals other than 100 percent, duplicate members, and unauthorized acceptance" do
    {owner, store} = create_merchant_with_store!()
    seller = create_merchant!()

    assert {:error, :split_total_must_equal_10000} =
             SalesTeams.create(owner, store.id, "Bad split", [
               %{merchant_id: owner.id, role: :owner, split_bps: 5_000},
               %{merchant_id: seller.id, role: :seller, split_bps: 4_000}
             ])

    assert {:error, :duplicate_member} =
             SalesTeams.create(owner, store.id, "Duplicate", [
               %{merchant_id: owner.id, role: :owner, split_bps: 6_000},
               %{merchant_id: owner.id, role: :seller, split_bps: 4_000}
             ])

    {:ok, team} =
      SalesTeams.create(owner, store.id, "Consent", [
        %{merchant_id: owner.id, role: :owner, split_bps: 5_000},
        %{merchant_id: seller.id, role: :seller, split_bps: 5_000}
      ])

    invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
    stranger = create_merchant!()
    assert {:error, :forbidden} = SalesTeams.accept(stranger, invited.id)
  end

  test "settles an attributed order's merchant proceeds exactly and reverses proportionally" do
    {owner, store} = create_merchant_with_store!()
    seller = create_merchant!()

    {:ok, team} =
      SalesTeams.create(owner, store.id, "Settlement crew", [
        %{merchant_id: owner.id, role: :owner, split_bps: 6_000},
        %{merchant_id: seller.id, role: :seller, split_bps: 4_000}
      ])

    invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
    {:ok, _accepted} = SalesTeams.accept(seller, invited.id)

    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: "ACCT_team"})
    |> Ash.update!(authorize?: false)

    product = create_product!(store, title: "Team Basket")
    variant = create_variant!(product, store, price: 5_000, stock_quantity: 10)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 2}],
        attribution: %{"sales_team_id" => team.id}
      )

    {:split, %{allocations: payment_allocations}} =
      Emakola.Payments.OrderSettlement.prepare(order.id, store.id)

    payment = create_payment!(store, order_id: order.id, amount: order.total)
    :ok = Emakola.Payments.OrderSettlement.record_splits!(payment, payment_allocations)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    assert :ok = SalesTeams.settle_attributed_payment(payment)
    assert :ok = SalesTeams.settle_attributed_payment(payment)

    settlements =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert length(settlements) == 2
    assert Enum.sum(Enum.map(settlements, & &1.amount)) == 9_800
    assert Enum.find(settlements, &(&1.role == :owner)).amount == 5_880
    assert Enum.find(settlements, &(&1.role == :seller)).amount == 3_920
    assert Enum.all?(settlements, &(&1.settlement_base == 9_800))

    payment =
      payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 5_000})
      |> Ash.update!(authorize?: false)

    assert :ok = SalesTeams.reverse_attributed_payment(payment)

    reversed =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert Enum.sum(Enum.map(reversed, & &1.reversed_amount)) == 4_900
    assert Enum.all?(reversed, &(&1.status == :partially_reversed))
  end

  # internal-settlement P3: the sell-gate no longer blocks unverified stores
  # (NetworkCheckoutEligibility), and OrderSettlement.prepare/2 routes an
  # unverified store's charge to the :internal rail instead of refusing it.
  # Mirrors "settles an attributed order's merchant proceeds exactly and
  # reverses proportionally" above, with the store left unverified — same
  # team, same order shape, same numbers — to prove settlement fires
  # identically regardless of rail.
  test "settles an attributed order identically on the internal rail for an unverified store" do
    {owner, store} = create_merchant_with_store!()
    seller = create_merchant!()

    {:ok, team} =
      SalesTeams.create(owner, store.id, "Settlement crew", [
        %{merchant_id: owner.id, role: :owner, split_bps: 6_000},
        %{merchant_id: seller.id, role: :seller, split_bps: 4_000}
      ])

    invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
    {:ok, _accepted} = SalesTeams.accept(seller, invited.id)

    # No StorePayoutAccount is created here — store stays unverified.

    product = create_product!(store, title: "Team Basket")
    variant = create_variant!(product, store, price: 5_000, stock_quantity: 10)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        store.id,
        [%{variant_id: variant.id, quantity: 2}],
        attribution: %{"sales_team_id" => team.id}
      )

    assert {:split, %{mode: :internal, allocations: payment_allocations}} =
             Emakola.Payments.OrderSettlement.prepare(order.id, store.id)

    payment = create_payment!(store, order_id: order.id, amount: order.total)
    :ok = Emakola.Payments.OrderSettlement.record_splits!(payment, payment_allocations)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    assert :ok = SalesTeams.settle_attributed_payment(payment)
    assert :ok = SalesTeams.settle_attributed_payment(payment)

    settlements =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert length(settlements) == 2
    assert Enum.sum(Enum.map(settlements, & &1.amount)) == 9_800
    assert Enum.find(settlements, &(&1.role == :owner)).amount == 5_880
    assert Enum.find(settlements, &(&1.role == :seller)).amount == 3_920
    assert Enum.all?(settlements, &(&1.settlement_base == 9_800))

    payment =
      payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 5_000})
      |> Ash.update!(authorize?: false)

    assert :ok = SalesTeams.reverse_attributed_payment(payment)

    reversed =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert Enum.sum(Enum.map(reversed, & &1.reversed_amount)) == 4_900
    assert Enum.all?(reversed, &(&1.status == :partially_reversed))
  end

  test "does not settle an unconsented team or an unattributed order" do
    {owner, store} = create_merchant_with_store!()
    seller = create_merchant!()

    {:ok, team} =
      SalesTeams.create(owner, store.id, "Pending crew", [
        %{merchant_id: owner.id, role: :owner, split_bps: 5_000},
        %{merchant_id: seller.id, role: :seller, split_bps: 5_000}
      ])

    order = create_order!(store, attribution: %{"sales_team_id" => team.id})
    payment = create_payment!(store, order_id: order.id, amount: 10_000)

    Emakola.Payments.create_payment_split!(
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: 9_800
      },
      authorize?: false
    )

    assert :ok = SalesTeams.settle_attributed_payment(payment)

    assert [] ==
             Emakola.Suppliers.SalesTeamSettlement
             |> Ash.Query.filter(payment_id == ^payment.id)
             |> Ash.read!(authorize?: false)
  end

  # Post-merge hardening (2026-07-11 review): a crash that persisted only some
  # member rows must be healed by the webhook retry — the old any-vs-all guard
  # skipped the whole payment, stranding the remaining members forever.
  test "a partial settlement crash is completed on retry, not skipped" do
    {owner, store} = create_merchant_with_store!()
    seller_a = create_merchant!()
    seller_b = create_merchant!()

    {:ok, team} =
      SalesTeams.create(owner, store.id, "Crash crew", [
        %{merchant_id: owner.id, role: :owner, split_bps: 3_334},
        %{merchant_id: seller_a.id, role: :seller, split_bps: 3_333},
        %{merchant_id: seller_b.id, role: :seller, split_bps: 3_333}
      ])

    for seller <- [seller_a, seller_b] do
      invited = Enum.find(team.members, &(&1.merchant_id == seller.id))
      {:ok, _} = SalesTeams.accept(seller, invited.id)
    end

    order = create_order!(store, attribution: %{"sales_team_id" => team.id})
    payment = create_payment!(store, order_id: order.id, amount: 10_000)

    Emakola.Payments.create_payment_split!(
      %{
        store_id: store.id,
        payment_id: payment.id,
        role: :merchant,
        recipient_store_id: store.id,
        amount: 9_800
      },
      authorize?: false
    )

    assert :ok = SalesTeams.settle_attributed_payment(payment)

    settled =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert length(settled) == 3

    # Simulate the crash aftermath: only the owner's row survived.
    lost_ids = settled |> Enum.reject(&(&1.role == :owner)) |> Enum.map(& &1.id)

    Emakola.Repo.delete_all(
      Ecto.Query.from(s in "earn_sales_team_settlements",
        where: s.id in type(^lost_ids, {:array, Ecto.UUID})
      )
    )

    assert :ok = SalesTeams.settle_attributed_payment(payment)

    healed =
      Emakola.Suppliers.SalesTeamSettlement
      |> Ash.Query.filter(payment_id == ^payment.id)
      |> Ash.read!(authorize?: false)

    assert length(healed) == 3
    assert Enum.sum(Enum.map(healed, & &1.amount)) == 9_800
    assert Enum.uniq_by(healed, & &1.team_member_id) == healed
  end
end
