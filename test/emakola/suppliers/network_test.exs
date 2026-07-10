defmodule Emakola.Suppliers.NetworkTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Suppliers.Network

  setup do
    wholesaler = create_store!()
    reseller = create_store!()
    outsider_store = create_store!()
    wholesaler_actor = create_merchant!()
    reseller_actor = create_merchant!()
    outsider = create_merchant!()

    create_store_membership!(wholesaler_actor, wholesaler, :owner)
    create_store_membership!(reseller_actor, reseller, :owner)
    create_store_membership!(outsider, outsider_store, :owner)

    %{
      wholesaler: wholesaler,
      reseller: reseller,
      wholesaler_actor: wholesaler_actor,
      reseller_actor: reseller_actor,
      outsider: outsider
    }
  end

  test "a participant requests and only the counterparty approves", ctx do
    assert {:ok, connection} =
             Network.request(ctx.reseller_actor, %{
               wholesaler_store_id: ctx.wholesaler.id,
               reseller_store_id: ctx.reseller.id,
               requested_by_store_id: ctx.reseller.id,
               terms: %{"currency" => "GHS"}
             })

    assert connection.status == :pending
    assert {:error, :forbidden} = Network.approve(ctx.reseller_actor, connection)
    assert {:error, :forbidden} = Network.approve(ctx.outsider, connection)

    assert {:ok, approved} = Network.approve(ctx.wholesaler_actor, connection)
    assert approved.status == :active
    assert approved.approved_at
  end

  test "either participant can suspend, reactivate, and terminate an active connection", ctx do
    {:ok, pending} =
      Network.request(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        reseller_store_id: ctx.reseller.id,
        requested_by_store_id: ctx.wholesaler.id
      })

    {:ok, active} = Network.approve(ctx.reseller_actor, pending)
    assert {:ok, suspended} = Network.suspend(ctx.reseller_actor, active, "quality review")
    assert suspended.status == :suspended
    assert suspended.status_reason == "quality review"

    assert {:ok, reactivated} = Network.reactivate(ctx.wholesaler_actor, suspended)
    assert reactivated.status == :active
    assert is_nil(reactivated.status_reason)

    assert {:ok, terminated} = Network.terminate(ctx.reseller_actor, reactivated, "ended")
    assert terminated.status == :terminated
  end

  test "outsiders cannot read connections and stores cannot connect to themselves", ctx do
    assert {:error, :stores_must_differ} =
             Network.request(ctx.wholesaler_actor, %{
               wholesaler_store_id: ctx.wholesaler.id,
               reseller_store_id: ctx.wholesaler.id,
               requested_by_store_id: ctx.wholesaler.id
             })

    {:ok, connection} =
      Network.request(ctx.reseller_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        reseller_store_id: ctx.reseller.id,
        requested_by_store_id: ctx.reseller.id
      })

    assert {:error, :forbidden} = Network.get(ctx.outsider, connection.id)
    assert {:ok, [listed]} = Network.list_for_store(ctx.wholesaler_actor, ctx.wholesaler.id)
    assert listed.id == connection.id
  end

  test "the same store pair cannot create duplicate connections", ctx do
    attrs = %{
      wholesaler_store_id: ctx.wholesaler.id,
      reseller_store_id: ctx.reseller.id,
      requested_by_store_id: ctx.reseller.id
    }

    assert {:ok, _} = Network.request(ctx.reseller_actor, attrs)
    assert {:error, :connection_exists} = Network.request(ctx.reseller_actor, attrs)
  end
end
