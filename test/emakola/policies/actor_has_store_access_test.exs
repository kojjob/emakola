defmodule Emakola.Policies.ActorHasStoreAccessTest do
  @moduledoc """
  Regression tests for the ActorHasStoreAccess policy check.

  Verifies that non-multitenant resources (e.g. StoreMembership) cannot be
  exploited via a caller-supplied tenant that belongs to the attacker's own
  store. The gate introduced in get_store_id/1 ensures that for non-multitenant
  resources the check always reads store_id from the row, never from the tenant
  argument passed by the caller.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  test "explicit tenant cannot shadow the row's store on a non-multitenant resource" do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()

    # merchant_b's membership row in store_b; merchant_a attacks it while
    # passing a tenant they DO belong to (store_a).
    membership_b =
      Emakola.Accounts.StoreMembership
      |> Ash.Query.filter(merchant_id == ^merchant_b.id and store_id == ^store_b.id)
      |> Ash.read_one!(authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             membership_b
             |> Ash.Changeset.for_update(:change_role, %{role: :admin},
               actor: merchant_a,
               tenant: store_a.id
             )
             |> Ash.update()
  end

  test "actor can update a membership row in their own store (positive case)" do
    {merchant_a, store_a} = create_merchant_with_store!()
    other_merchant = create_merchant!()
    create_store_membership!(other_merchant, store_a, :staff)

    membership =
      Emakola.Accounts.StoreMembership
      |> Ash.Query.filter(merchant_id == ^other_merchant.id and store_id == ^store_a.id)
      |> Ash.read_one!(authorize?: false)

    # merchant_a is an owner of store_a and should be allowed to update
    # another member's role within store_a.
    assert {:ok, updated} =
             membership
             |> Ash.Changeset.for_update(:change_role, %{role: :admin},
               actor: merchant_a,
               tenant: store_a.id
             )
             |> Ash.update()

    assert updated.role == :admin
  end
end
