defmodule Emakola.Billing.Workers.PaymentHandler do
  @moduledoc "Processes payment webhook events via Oban. Implement in Phase 1.5."
  use Oban.Worker, queue: :billing, max_attempts: 5

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"gateway" => gateway, "event" => event, "data" => _data}}) do
    Logger.info("Payment webhook: gateway=#{gateway} event=#{event}")
    # TODO: Implement Paystack and Hubtel webhook handling in Phase 1.5
    :ok
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("Unhandled payment webhook args: #{inspect(args)}")
    :ok
  end
end
