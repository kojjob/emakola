defmodule Emakola.Orders.Workers.SupplierSlaWorkerTest do
  @moduledoc """
  The sweeper that chases a silent supplier.

  Timing is deterministic here for one reason: the deadline is STORED, so the
  test writes it. Nothing inside the worker does date arithmetic a test could
  race. Deadlines are seeded a second in the past or an hour in the future,
  never exactly now — the `<` boundary is the epoch-bucket flake this codebase
  has been bitten by before.
  """
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory

  alias Emakola.Notifications.Workers.SupplierNotificationWorker
  alias Emakola.Orders.Fulfillment
  alias Emakola.Orders.Workers.SupplierSlaWorker

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    order = create_order!(store)

    %{store: store, supplier: supplier, order: order}
  end

  # Fulfillment's :create accepts only five fields, and rightly so — checkout
  # must never set a deadline. So the fixture writes the clock directly rather
  # than loosening the production action.
  defp clocked!(ctx, attrs) do
    fulfillment =
      create_fulfillment!(ctx.order, ctx.store, Map.take(attrs, [:supplier_id, :status]))

    fields =
      attrs
      |> Map.drop([:supplier_id, :status])
      |> Map.to_list()

    # Ecto rejects an empty `set:`, and "no clock at all" is a case this fixture
    # has to be able to express.
    if fields != [] do
      {1, _} =
        Emakola.Repo.update_all(
          Ecto.Query.from(f in "fulfillments", where: f.id == type(^fulfillment.id, :binary_id)),
          set: fields
        )
    end

    reload(fulfillment)
  end

  defp reload(f), do: Ash.get!(Fulfillment, f.id, authorize?: false)

  defp overdue(ctx, extra \\ %{}) do
    clocked!(
      ctx,
      Map.merge(
        %{
          supplier_id: ctx.supplier.id,
          respond_by: DateTime.add(DateTime.utc_now(), -1, :second)
        },
        extra
      )
    )
  end

  defp run, do: SupplierSlaWorker.perform(%Oban.Job{args: %{}})

  describe "who gets chased" do
    test "an overdue supplier fulfillment moves to level 1 and one chase is queued", ctx do
      f = overdue(ctx)

      assert :ok == run()

      assert reload(f).escalation_level == 1
      assert %DateTime{} = reload(f).escalated_at

      assert_enqueued(
        worker: SupplierNotificationWorker,
        args: %{fulfillment_id: f.id, escalation: 1}
      )
    end

    test "a deadline still in the future is left alone", ctx do
      f = overdue(ctx, %{respond_by: DateTime.add(DateTime.utc_now(), 1, :hour)})

      assert :ok == run()

      assert reload(f).escalation_level == 0
      refute_enqueued(worker: SupplierNotificationWorker)
    end

    # Guards the no-backfill decision: every fulfilment that predates the clock
    # has a nil deadline, and the first cron tick must not escalate all of them.
    test "a fulfillment with no clock at all is never chased", ctx do
      f = clocked!(ctx, %{supplier_id: ctx.supplier.id})

      assert is_nil(f.respond_by)
      assert :ok == run()

      assert reload(f).escalation_level == 0
      refute_enqueued(worker: SupplierNotificationWorker)
    end

    # The integration point with the action link: an accept leaves the status at
    # :notified on purpose, so a status check alone would keep chasing a
    # supplier who has already agreed.
    test "a supplier who has accepted leaves the ladder even though status is :notified", ctx do
      f =
        overdue(ctx, %{
          status: :notified,
          accepted_at: DateTime.utc_now()
        })

      assert reload(f).status == :notified
      assert :ok == run()

      assert reload(f).escalation_level == 0
      refute_enqueued(worker: SupplierNotificationWorker)
    end

    test "a shipped fulfillment is not chased", ctx do
      f = overdue(ctx, %{status: :shipped})

      assert :ok == run()
      assert reload(f).escalation_level == 0
    end

    test "a declined fulfillment is not chased — the supplier answered", ctx do
      f = overdue(ctx, %{status: :declined})

      assert :ok == run()
      assert reload(f).escalation_level == 0
    end

    test "the merchant's own-stock group is never chased", ctx do
      f =
        clocked!(ctx, %{respond_by: DateTime.add(DateTime.utc_now(), -1, :second)})

      assert is_nil(f.supplier_id)
      assert :ok == run()

      assert reload(f).escalation_level == 0
    end
  end

  describe "not chasing forever" do
    # The one that matters. Level 1 matches none of the worker's candidate
    # filters, so the row leaves the set permanently — a database fact rather
    # than a code convention.
    test "a fulfillment already at level 1 is never chased again", ctx do
      f = overdue(ctx)

      assert :ok == run()
      assert :ok == run()
      assert :ok == run()

      assert reload(f).escalation_level == 1

      assert 1 ==
               all_enqueued(worker: SupplierNotificationWorker)
               |> Enum.count(&(&1.args["fulfillment_id"] == f.id))
    end

    test "two ticks back to back queue exactly one chase", ctx do
      f = overdue(ctx)

      assert :ok == run()
      assert :ok == run()

      assert 1 ==
               all_enqueued(worker: SupplierNotificationWorker)
               |> Enum.count(&(&1.args["fulfillment_id"] == f.id))
    end
  end

  describe "isolation" do
    test "each store's overdue fulfillments escalate independently", ctx do
      mine = overdue(ctx)

      other_store = create_store!()
      other_supplier = create_supplier!(other_store)
      other_order = create_order!(other_store)

      theirs =
        clocked!(
          %{store: other_store, order: other_order},
          %{
            supplier_id: other_supplier.id,
            respond_by: DateTime.add(DateTime.utc_now(), -1, :second)
          }
        )

      assert :ok == run()

      assert reload(mine).escalation_level == 1
      assert reload(theirs).escalation_level == 1
    end
  end

  describe "the ladder" do
    # Rung 2 tells the MERCHANT, and it tells them in the bell rather than by
    # SMS. That one choice removes the quiet-hours problem — a 6h clock stamped
    # at 23:00 comes due at 05:00, and Ghana is UTC+0 with no tzdata here — and
    # the cost problem, together.
    test "a supplier who ignored the chase escalates to the merchant", ctx do
      f = overdue(ctx, %{escalation_level: 1, escalated_at: hours_ago(7)})

      assert :ok == run()

      assert reload(f).escalation_level == 2
      refute_enqueued(worker: SupplierNotificationWorker)
    end

    test "rung 2 writes a bell notification for the store's merchants", ctx do
      merchant = create_merchant!()

      Emakola.Accounts.StoreMembership
      |> Ash.Changeset.for_create(:create, %{
        merchant_id: merchant.id,
        store_id: ctx.store.id,
        role: :owner
      })
      |> Ash.create!(authorize?: false)

      overdue(ctx, %{escalation_level: 1, escalated_at: hours_ago(7)})

      assert :ok == run()

      notifications =
        Emakola.Notifications.Notification
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.recipient_id == merchant.id))

      assert [notification] = notifications
      assert notification.type == :supplier_overdue
      assert notification.recipient_kind == :merchant
    end

    test "rung 2 broadcasts so an open order page updates itself", ctx do
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{ctx.store.id}:orders")

      overdue(ctx, %{escalation_level: 1, escalated_at: hours_ago(7)})

      assert :ok == run()

      assert_receive {:order_event, :supplier_overdue, _order}, 1000
    end

    test "the cooldown holds — 30 minutes after rung 1 is too soon for rung 2", ctx do
      f = overdue(ctx, %{escalation_level: 1, escalated_at: minutes_ago(30)})

      assert :ok == run()

      assert reload(f).escalation_level == 1
    end

    test "rung 3 is the terminal state the merchant must act on", ctx do
      f = overdue(ctx, %{escalation_level: 2, escalated_at: hours_ago(13)})

      assert :ok == run()

      assert reload(f).escalation_level == 3
    end

    test "the cooldown holds for rung 3 too", ctx do
      f = overdue(ctx, %{escalation_level: 2, escalated_at: hours_ago(6)})

      assert :ok == run()

      assert reload(f).escalation_level == 2
    end

    # The ladder tops out. A level-3 row matches none of the three candidate
    # queries, so it leaves the set permanently.
    test "level 3 never escalates again, however many times the sweeper runs", ctx do
      f = overdue(ctx, %{escalation_level: 3, escalated_at: hours_ago(48)})

      for _ <- 1..3, do: run()

      assert reload(f).escalation_level == 3
    end

    test "a supplier declining jumps straight to the merchant's decision", ctx do
      f =
        clocked!(ctx, %{
          supplier_id: ctx.supplier.id,
          respond_by: DateTime.add(DateTime.utc_now(), 1, :hour)
        })

      {:ok, declined} =
        Emakola.Orders.supplier_decline_fulfillment(
          f,
          %{decline_reason: :out_of_stock},
          authorize?: false
        )

      assert declined.escalation_level == 3,
             "a decline is an answer — the merchant should not wait out the ladder"
    end
  end

  defp hours_ago(n), do: DateTime.add(DateTime.utc_now(), -n, :hour)
  defp minutes_ago(n), do: DateTime.add(DateTime.utc_now(), -n, :minute)
end
