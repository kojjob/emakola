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
  require Ash.Query

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
end
