defmodule Emakola.Payments.Workers.PaystackWebhookHandler do
  @moduledoc """
  Oban worker that processes Paystack webhook events.

  Handles:
  - charge.success — marks payment as success, confirms order
  - charge.failed — marks payment as failed
  - refund.processed — marks payment as refunded with amount

  Idempotent: skips processing if payment is already in a terminal state.
  """

  use Oban.Worker, queue: :webhooks, max_attempts: 5

  require Ash.Query

  alias Emakola.Payments.Payment

  @terminal_states [:success, :failed, :refunded]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event, "data" => data}}) do
    case event do
      "charge.success" -> handle_charge_success(data)
      "charge.failed" -> handle_charge_failed(data)
      "refund.processed" -> handle_refund_processed(data)
      _unknown -> :ok
    end
  end

  defp handle_charge_success(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      payment
      |> Ash.Changeset.for_update(:mark_success, %{gateway_response: data})
      |> Ash.update!()

      # Confirm the associated order if present
      maybe_confirm_order(payment.order_id)

      :ok
    else
      true -> :ok
      {:error, :payment_not_found} -> {:error, :payment_not_found}
    end
  end

  defp handle_charge_failed(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      payment
      |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: data})
      |> Ash.update!()

      :ok
    else
      true -> :ok
      {:error, :payment_not_found} -> {:error, :payment_not_found}
    end
  end

  defp handle_refund_processed(data) do
    reference = get_in(data, ["transaction", "reference"])
    refund_amount = data["amount"]

    with {:ok, payment} <- find_payment(reference) do
      if payment.status == :refunded do
        :ok
      else
        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: refund_amount})
        |> Ash.update!()

        :ok
      end
    end
  end

  defp find_payment(reference) do
    case Payment
         |> Ash.Query.filter(gateway_reference == ^reference)
         |> Ash.read_one() do
      {:ok, nil} -> {:error, :payment_not_found}
      {:ok, payment} -> {:ok, payment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp terminal?(%{status: status}) when status in @terminal_states, do: true
  defp terminal?(_), do: false

  defp maybe_confirm_order(nil), do: :ok

  defp maybe_confirm_order(order_id) do
    case Emakola.Orders.Order
         |> Ash.Query.filter(id == ^order_id)
         |> Ash.read_one() do
      {:ok, %{status: :pending} = order} ->
        result =
          order
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update()

        case result do
          {:ok, confirmed_order} ->
            try do
              Emakola.Notifications.Dispatcher.dispatch(confirmed_order, :order_confirmed)
            rescue
              _ -> :ok
            end

            {:ok, confirmed_order}

          error ->
            error
        end

      _ ->
        :ok
    end
  end
end
