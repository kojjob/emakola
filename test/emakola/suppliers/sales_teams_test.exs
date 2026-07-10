defmodule Emakola.Suppliers.SalesTeamsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
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
end
