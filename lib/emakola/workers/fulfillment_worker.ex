defmodule Emakola.Workers.FulfillmentWorker do
  @moduledoc """
  Oban worker that fulfills a confirmed order — dispatches each line item
  through `Emakola.Fulfillment.Dispatcher` based on the line item's
  product type. Enqueued by the `Emakola.Orders.Order.:confirm` action's
  `after_action` callback.

  ## Idempotency and retries

  Pipelines are idempotent (e.g. `Pipelines.DigitalDownload` checks for
  an existing grant before issuing). Oban's automatic retries on
  transient failure (`max_attempts: 5`) are therefore safe.

  ## Per-line-item error handling

  Individual `{:error, reason}` returns from pipelines are **logged but
  not failed**. During the phased rollout, a mixed-cart order with both
  `:physical` (still `:not_implemented`) and `:digital_download` (wired)
  line items must not have its digital fulfillment blocked by the
  physical stub. The worker treats `:not_implemented` and similar
  per-line-item errors as "deferred / pending its phase," not "kill the
  job." Only infrastructure failures (DB errors loading the order)
  cause the job to fail and retry.
  """

  use Oban.Worker, queue: :orders, max_attempts: 5

  require Ash.Query
  require Logger

  alias Emakola.Fulfillment.Dispatcher

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id}}) do
    case Ash.get(Emakola.Orders.Order, order_id, authorize?: false) do
      {:ok, order} ->
        fulfill_order(order)

      {:error, _} ->
        Logger.warning("[fulfillment_worker] order #{order_id} not found")
        {:error, :order_not_found}
    end
  end

  defp fulfill_order(order) do
    line_items =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, load: [variant: :product])

    Enum.each(line_items, &fulfill_line_item(order, &1))

    # Strictly after dispatch: a pipeline failure must not mark an undelivered
    # download as delivered.
    auto_deliver_digital_groups(line_items)
    :ok
  end

  # Per fulfillment group, not per order — a mixed cart's single merchant group
  # contains both lines and correctly stays :pending for the merchant to ship,
  # while a multi-supplier digital order delivers each group independently.
  defp auto_deliver_digital_groups(line_items) do
    line_items
    |> Enum.reject(&is_nil(&1.fulfillment_id))
    |> Enum.group_by(& &1.fulfillment_id)
    |> Enum.filter(fn {_id, lines} -> Enum.all?(lines, &non_shippable_line?/1) end)
    |> Enum.each(fn {fulfillment_id, _lines} -> deliver_digitally(fulfillment_id) end)
  end

  # A nil variant is a custom pay-link line, which ships — never treat the
  # absence of a product as "nothing to deliver".
  defp non_shippable_line?(%{variant: nil}), do: false

  defp non_shippable_line?(%{variant: variant}) do
    not Emakola.Catalog.Product.requires_shipping?(variant.product)
  end

  defp deliver_digitally(fulfillment_id) do
    with {:ok, fulfillment} <-
           Ash.get(Emakola.Orders.Fulfillment, fulfillment_id, authorize?: false),
         {:ok, _updated} <-
           fulfillment
           |> Ash.Changeset.for_update(:mark_delivered_digitally, %{})
           |> Ash.update(authorize?: false) do
      :ok
    else
      # Log and continue, per this module's contract that a per-item problem
      # never fails the job. The usual cause is a retry finding the group
      # already delivered, which the status guard correctly refuses.
      {:error, reason} ->
        Logger.info(
          "[fulfillment_worker] fulfillment=#{fulfillment_id} not auto-delivered: " <>
            inspect(reason)
        )

        :ok
    end
  end

  defp fulfill_line_item(order, line_item) do
    case line_item.variant do
      nil ->
        # Custom (variant-less) pay-link line — no product to dispatch/notify.
        :ok

      variant ->
        dispatch_line_item(order, line_item, variant.product.product_type)
    end
  end

  defp dispatch_line_item(order, line_item, product_type) do
    case Dispatcher.dispatch(product_type, line_item, %{customer_id: order.customer_id}) do
      {:ok, :deferred} ->
        Logger.debug(
          "[fulfillment_worker] order=#{order.id} line_item=#{line_item.id} " <>
            "type=#{product_type} deferred (stub)"
        )

      {:ok, result} ->
        Logger.info(
          "[fulfillment_worker] order=#{order.id} line_item=#{line_item.id} " <>
            "type=#{product_type} fulfilled: #{inspect(result)}"
        )

      {:error, reason} ->
        # Per-line-item errors are logged but don't fail the job (see moduledoc).
        Logger.info(
          "[fulfillment_worker] order=#{order.id} line_item=#{line_item.id} " <>
            "type=#{product_type} deferred: #{inspect(reason)}"
        )
    end
  end
end
