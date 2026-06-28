defmodule Emakola.Accounts.StoreMembershipTest do
  @moduledoc """
  StoreMembership is the tenant-authorization primitive (ActorHasStoreAccess
  keys off it). Membership creation is system-only — onboarding and admin
  staff-management call with `authorize?: false`. An actor-driven
  (`authorize?: true`) create must be forbidden, or a Customer / different-store
  merchant could mint themselves an owner membership (privilege escalation).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Accounts
  alias Emakola.Factory

  test "an authorized create is forbidden — no self-minted membership" do
    {attacker, _store_a} = Factory.create_merchant_with_store!()
    victim_store = Factory.create_store!()

    # Must be an explicit authorization denial — not an incidental failure from
    # relationship management — so the security boundary doesn't depend on side
    # effects that could change.
    assert {:error, %Ash.Error.Forbidden{}} =
             Accounts.create_store_membership(
               %{role: :owner, merchant_id: attacker.id, store_id: victim_store.id},
               actor: attacker,
               authorize?: true
             )
  end

  test "a system create (authorize?: false) still succeeds (onboarding path)" do
    merchant = Factory.create_merchant!()
    store = Factory.create_store!()

    assert {:ok, _} =
             Accounts.create_store_membership(
               %{role: :staff, merchant_id: merchant.id, store_id: store.id},
               authorize?: false
             )
  end
end
