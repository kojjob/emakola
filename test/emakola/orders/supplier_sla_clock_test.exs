defmodule Emakola.Orders.SupplierSlaClockTest do
  @moduledoc """
  A paid order whose supplier never answers currently produces total silence.
  Nothing chases them, and the merchant finds out when the customer complains.

  The clock that fixes it is a stored deadline, and where it starts from is the
  whole design:

    * **Not `notified_at`** — that is the symptom, not the cause. It is written
      only when a provider returned `{:ok, _}`, and in production the WhatsApp
      credentials are a placeholder, so it is never written at all. A clock
      hung off it is a clock that never starts.

    * **Not `inserted_at`** — fulfilments are created at *checkout*, before
      payment. A clock from there chases suppliers about carts nobody ever
      bought, spending real SMS money on them.

  So it is stamped at `Order.:confirm`, which is the moment somebody actually
  paid.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.Fulfillment
  alias Emakola.Orders.Workers.SupplierSlaWorker

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    order = create_order!(store, %{status: :pending})

    supplier_group = create_fulfillment!(order, store, supplier_id: supplier.id)
    own_stock = create_fulfillment!(order, store)

    %{
      store: store,
      supplier: supplier,
      order: order,
      supplier_group: supplier_group,
      own_stock: own_stock
    }
  end

  defp reload(f), do: Ash.get!(Fulfillment, f.id, authorize?: false)

  describe "when the clock starts" do
    test "a fulfillment sitting in an unpaid checkout has no clock", ctx do
      assert is_nil(reload(ctx.supplier_group).respond_by),
             "checkout must not start the clock — nobody has paid yet"
    end

    test "confirming the order stamps a deadline on the supplier group", ctx do
      {:ok, _} = Emakola.Orders.confirm_order(ctx.order, authorize?: false)

      respond_by = reload(ctx.supplier_group).respond_by
      assert %DateTime{} = respond_by

      expected = DateTime.add(DateTime.utc_now(), SupplierSlaWorker.respond_hours(), :hour)
      assert_in_delta DateTime.diff(respond_by, expected, :second), 0, 5
    end

    test "the merchant's own-stock group never gets a clock", ctx do
      {:ok, _} = Emakola.Orders.confirm_order(ctx.order, authorize?: false)

      assert is_nil(reload(ctx.own_stock).respond_by),
             "there is no supplier to chase on the merchant's own stock"
    end

    test "a second confirm cannot push an existing deadline later", ctx do
      {:ok, _} = Emakola.Orders.confirm_order(ctx.order, authorize?: false)
      first = reload(ctx.supplier_group).respond_by

      # The webhook and the merchant's manual button can both land.
      Emakola.Orders.confirm_order(ctx.order, authorize?: false)

      assert reload(ctx.supplier_group).respond_by == first
    end

    test "a fresh fulfillment starts at escalation level zero", ctx do
      assert reload(ctx.supplier_group).escalation_level == 0
      assert is_nil(reload(ctx.supplier_group).escalated_at)
    end
  end

  describe "the escalate action" do
    setup ctx do
      {:ok, _} = Emakola.Orders.confirm_order(ctx.order, authorize?: false)
      Map.put(ctx, :clocked, reload(ctx.supplier_group))
    end

    test "moves one rung and stamps when it happened", %{clocked: clocked} do
      {:ok, escalated} =
        Emakola.Orders.escalate_fulfillment(clocked, %{to_level: 1}, authorize?: false)

      assert escalated.escalation_level == 1
      assert %DateTime{} = escalated.escalated_at
    end

    # Two runs racing — an Oban retry overlapping the next cron tick — both read
    # level 0 and both try to write level 1. The second must match zero rows.
    test "a second escalation from the same stale struct is refused", %{clocked: clocked} do
      {:ok, _} = Emakola.Orders.escalate_fulfillment(clocked, %{to_level: 1}, authorize?: false)

      assert {:error, _} =
               Emakola.Orders.escalate_fulfillment(clocked, %{to_level: 1}, authorize?: false)

      assert reload(clocked).escalation_level == 1
    end

    test "cannot skip a rung", %{clocked: clocked} do
      assert {:error, _} =
               Emakola.Orders.escalate_fulfillment(clocked, %{to_level: 3}, authorize?: false)

      assert reload(clocked).escalation_level == 0
    end

    test "cannot escalate a fulfillment that has already shipped", %{clocked: clocked} do
      {:ok, shipped} =
        Emakola.Orders.mark_fulfillment_shipped(clocked, %{tracking_number: "GH-1"},
          authorize?: false
        )

      assert {:error, _} =
               Emakola.Orders.escalate_fulfillment(shipped, %{to_level: 1}, authorize?: false)
    end
  end
end
