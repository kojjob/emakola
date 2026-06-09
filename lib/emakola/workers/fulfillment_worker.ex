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
    :ok
  end

  defp fulfill_line_item(order, line_item) do
    product_type = line_item.variant.product.product_type

    case Dispatcher.dispatch(product_type, line_item, %{}) do
      {:ok, result} ->
        Logger.info(
          "[fulfillment_worker] order=#{order.id} line_item=#{line_item.id} " <>
            "type=#{product_type} fulfilled: #{inspect(result)}"
        )

      {:error, reason} ->
        # Per-line-item errors are logged but don't fail the job (see moduledoc).
        # Pipelines that aren't wired yet return :not_implemented; that's
        # expected during phased rollout.
        Logger.info(
          "[fulfillment_worker] order=#{order.id} line_item=#{line_item.id} " <>
            "type=#{product_type} deferred: #{inspect(reason)}"
        )
    end
  end
end
