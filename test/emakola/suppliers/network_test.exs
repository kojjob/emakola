defmodule Emakola.Suppliers.NetworkTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo
  require Ash.Query

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

  describe "connection notifications" do
    test "request enqueues a requested notification", ctx do
      {:ok, conn} =
        Network.request(ctx.reseller_actor, %{
          wholesaler_store_id: ctx.wholesaler.id,
          reseller_store_id: ctx.reseller.id,
          requested_by_store_id: ctx.reseller.id,
          terms: %{"currency" => "GHS"}
        })

      assert [job] =
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      assert job.args["connection_id"] == conn.id
      assert job.args["event"] == "requested"
    end

    test "approve enqueues approved notification", ctx do
      {:ok, pending} =
        Network.request(ctx.reseller_actor, %{
          wholesaler_store_id: ctx.wholesaler.id,
          reseller_store_id: ctx.reseller.id,
          requested_by_store_id: ctx.reseller.id
        })

      # all_enqueued is read-only — the requested job is still present, so we
      # filter by event below to isolate the one this action enqueues.
      all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      {:ok, approved} = Network.approve(ctx.wholesaler_actor, pending)

      jobs = all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)
      approved_jobs = Enum.filter(jobs, fn j -> j.args["event"] == "approved" end)

      assert [job] = approved_jobs
      assert job.args["connection_id"] == approved.id
      assert job.args["event"] == "approved"
    end

    test "reject enqueues rejected notification", ctx do
      {:ok, pending} =
        Network.request(ctx.wholesaler_actor, %{
          wholesaler_store_id: ctx.wholesaler.id,
          reseller_store_id: ctx.reseller.id,
          requested_by_store_id: ctx.wholesaler.id
        })

      # all_enqueued is read-only — the requested job is still present, so we
      # filter by event below to isolate the one this action enqueues.
      all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)

      {:ok, rejected} = Network.reject(ctx.reseller_actor, pending, "not a good fit")

      jobs = all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)
      rejected_jobs = Enum.filter(jobs, fn j -> j.args["event"] == "rejected" end)

      assert [job] = rejected_jobs
      assert job.args["connection_id"] == rejected.id
      assert job.args["event"] == "rejected"
    end

    test "no duplicate jobs for the same connection+event", ctx do
      attrs = %{
        wholesaler_store_id: ctx.wholesaler.id,
        reseller_store_id: ctx.reseller.id,
        requested_by_store_id: ctx.reseller.id
      }

      {:ok, _conn1} = Network.request(ctx.reseller_actor, attrs)

      # Second request fails, but we should still have exactly one requested job
      {:error, :connection_exists} = Network.request(ctx.reseller_actor, attrs)

      jobs = all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)
      requested_jobs = Enum.filter(jobs, fn j -> j.args["event"] == "requested" end)

      assert length(requested_jobs) == 1
    end
  end

  # Module level, ABOVE the describe — ExUnit raises on defp inside describe.
  # Hammer's :fix_window buckets are epoch-aligned; if the test starts
  # within guard_ms of a boundary, counts split across two windows (PR #174).
  defp await_fresh_window(window_ms, guard_ms) do
    remaining = window_ms - rem(System.system_time(:millisecond), window_ms)
    if remaining < guard_ms, do: Process.sleep(remaining + 10)
  end

  defp request_attrs(ctx, partner) do
    %{
      wholesaler_store_id: partner.id,
      reseller_store_id: ctx.reseller.id,
      requested_by_store_id: ctx.reseller.id,
      terms: %{"currency" => "GHS"}
    }
  end

  describe "invite throttle" do
    test "the 4th request within a minute is denied and creates nothing", ctx do
      await_fresh_window(60_000, 3_000)

      for partner <- [create_store!(), create_store!(), create_store!()] do
        assert {:ok, _} = Network.request(ctx.reseller_actor, request_attrs(ctx, partner))
      end

      fourth = create_store!()

      assert {:error, :invite_rate_limited} =
               Network.request(ctx.reseller_actor, request_attrs(ctx, fourth))

      fourth_id = fourth.id

      assert {:ok, []} =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(wholesaler_store_id == ^fourth_id)
               |> Ash.read(authorize?: false)

      assert length(
               all_enqueued(worker: Emakola.Notifications.Workers.ConnectionNotificationWorker)
             ) == 3
    end

    test "the 11th request in a day is denied even when the burst window is fresh", ctx do
      for _ <- 1..10 do
        Emakola.RateLimit.check_rate("supply_invite:day:#{ctx.reseller.id}", 10, 86_400_000)
      end

      partner = create_store!()

      assert {:error, :invite_rate_limited} =
               Network.request(ctx.reseller_actor, request_attrs(ctx, partner))
    end
  end
end
