defmodule Emakola.Orders.SupplierAlertTest do
  @moduledoc """
  One value per order answering "does a supplier need me?", so the orders LIST
  can say it without opening anything.

  Before this, escalation lived only inside an order's detail page: the clock
  fired, the bell rang, and the merchant landed on a list that looked entirely
  normal. An escalation nobody can see on the list is close to an escalation
  that did not happen.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  setup do
    store = create_store!()
    supplier = create_supplier!(store)
    order = create_order!(store)

    %{store: store, supplier: supplier, order: order}
  end

  defp alert(order) do
    order
    |> Ash.load!(:supplier_alert, authorize?: false)
    |> Map.fetch!(:supplier_alert)
  end

  defp supplier_group(ctx, attrs \\ %{}) do
    create_fulfillment!(ctx.order, ctx.store, Map.merge(%{supplier_id: ctx.supplier.id}, attrs))
  end

  describe "nothing to say" do
    test "an order with no fulfillments at all", ctx do
      assert is_nil(alert(ctx.order))
    end

    test "an order with only the merchant's own stock", ctx do
      create_fulfillment!(ctx.order, ctx.store)

      assert is_nil(alert(ctx.order)),
             "there is no supplier to chase on the merchant's own goods"
    end

    test "a supplier group waiting quietly inside its deadline", ctx do
      supplier_group(ctx)

      assert is_nil(alert(ctx.order))
    end
  end

  describe "what it reports" do
    test "a supplier who accepted", ctx do
      f = supplier_group(ctx)
      {:ok, _} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      assert alert(ctx.order) == :accepted
    end

    test "a supplier who has not replied after the merchant was told", ctx do
      f = supplier_group(ctx)
      {:ok, f} = Emakola.Orders.escalate_fulfillment(f, %{to_level: 1}, authorize?: false)
      {:ok, _} = Emakola.Orders.escalate_fulfillment(f, %{to_level: 2}, authorize?: false)

      assert alert(ctx.order) == :waiting
    end

    test "a supplier who declined", ctx do
      f = supplier_group(ctx)

      {:ok, _} =
        Emakola.Orders.supplier_decline_fulfillment(f, %{decline_reason: :out_of_stock},
          authorize?: false
        )

      assert alert(ctx.order) == :blocked
    end

    test "a supplier who never responded at all", ctx do
      f = supplier_group(ctx)

      f =
        Enum.reduce(1..3, f, fn level, acc ->
          {:ok, next} =
            Emakola.Orders.escalate_fulfillment(acc, %{to_level: level}, authorize?: false)

          next
        end)

      assert f.escalation_level == 3
      assert alert(ctx.order) == :blocked
    end

    test "a message that never reached the supplier", ctx do
      f = supplier_group(ctx)

      {:ok, _} =
        Emakola.Orders.record_fulfillment_send_failure(f, %{last_send_error: "whatsapp:http_401"},
          authorize?: false
        )

      assert alert(ctx.order) == :unreachable
    end
  end

  describe "precedence — the most urgent thing wins" do
    test "blocked beats accepted", ctx do
      accepted = supplier_group(ctx)
      {:ok, _} = Emakola.Orders.supplier_accept_fulfillment(accepted, authorize?: false)

      blocked = supplier_group(ctx)

      {:ok, _} =
        Emakola.Orders.supplier_decline_fulfillment(blocked, %{decline_reason: :out_of_stock},
          authorize?: false
        )

      assert alert(ctx.order) == :blocked
    end

    test "unreachable beats waiting", ctx do
      waiting = supplier_group(ctx)
      {:ok, w} = Emakola.Orders.escalate_fulfillment(waiting, %{to_level: 1}, authorize?: false)
      {:ok, _} = Emakola.Orders.escalate_fulfillment(w, %{to_level: 2}, authorize?: false)

      unreachable = supplier_group(ctx)

      {:ok, _} =
        Emakola.Orders.record_fulfillment_send_failure(unreachable, %{last_send_error: "x"},
          authorize?: false
        )

      assert alert(ctx.order) == :unreachable
    end
  end

  describe "once the work is done" do
    test "a shipped supplier group is no longer an alert", ctx do
      f = supplier_group(ctx)
      {:ok, _} = Emakola.Orders.supplier_accept_fulfillment(f, authorize?: false)

      {:ok, _} =
        Emakola.Orders.mark_fulfillment_shipped(f, %{tracking_number: "GH-1"}, authorize?: false)

      assert is_nil(alert(ctx.order))
    end

    test "a cancelled supplier group is no longer an alert", ctx do
      f = supplier_group(ctx)

      {:ok, _} =
        Emakola.Orders.supplier_decline_fulfillment(f, %{decline_reason: :out_of_stock},
          authorize?: false
        )

      f = Ash.get!(Emakola.Orders.Fulfillment, f.id, authorize?: false)
      {:ok, _} = Emakola.Orders.cancel_fulfillment(f, authorize?: false)

      assert is_nil(alert(ctx.order))
    end
  end

  # The lesson from :declined, which raised in FulfillmentStatus and crashed
  # every order view. This calculation must never be the reason a page dies.
  test "every fulfillment status resolves without raising", ctx do
    statuses =
      Emakola.Orders.Fulfillment
      |> Ash.Resource.Info.attribute(:status)
      |> Map.fetch!(:constraints)
      |> Keyword.fetch!(:one_of)

    for status <- statuses do
      order = create_order!(ctx.store)
      create_fulfillment!(order, ctx.store, %{supplier_id: ctx.supplier.id, status: status})

      assert alert(order) in [nil, :accepted, :waiting, :blocked, :unreachable],
             "supplier_alert returned something unexpected for #{inspect(status)}"
    end
  end
end
