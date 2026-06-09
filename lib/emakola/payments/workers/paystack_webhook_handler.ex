defmodule Emakola.Payments.Workers.PaystackWebhookHandler do
  @moduledoc """
  Oban worker that processes Paystack webhook events.

  Handles:
  - charge.success — marks payment as success, confirms order
  - charge.failed — marks payment as failed
  - refund.processed — marks payment as refunded with amount

  Idempotent: skips processing if payment is already in a terminal state.
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    # Paystack replays the same payload on retry. Deduplicate at insert
    # time within a 24h window — `Oban.insert!/1` returns the existing
    # job rather than creating a duplicate. The terminal-state guard
    # inside perform/1 remains as defense-in-depth for non-identical
    # jobs that happen to converge on the same payment.
    unique: [period: 86_400, fields: [:args]]

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
      updated =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{gateway_response: data})
        |> Ash.update!(authorize?: false)

      # Confirm the associated order if present
      maybe_confirm_order(payment.order_id)

      # Notify any LiveView still polling on this reference so the
      # customer sees confirmation immediately rather than waiting up
      # to 3s for the next poll cycle.
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_succeeded, reference, updated}
      )

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_charge_failed(data) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      updated =
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: data})
        |> Ash.update!(authorize?: false)

      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_failed, reference, updated}
      )

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_refund_processed(data) do
    reference = get_in(data, ["transaction", "reference"])
    refund_amount = data["amount"]

    with {:ok, payment} <- find_payment(reference),
         false <- payment.status == :refunded,
         {:ok, updated} <-
           payment
           |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: refund_amount})
           |> Ash.update(authorize?: false) do
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "payment:#{reference}",
        {:payment_refunded, reference, updated}
      )

      :ok
    else
      # Already refunded — idempotent success
      true -> :ok
      # Payment not found or not in a refundable state (e.g. :failed, :pending)
      {:error, %Ash.Error.Invalid{}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_payment(reference) do
    case Payment
         |> Ash.Query.filter(gateway_reference == ^reference)
         |> Ash.read_one(authorize?: false) do
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
         |> Ash.read_one(authorize?: false) do
      {:ok, %{status: :pending} = order} ->
        result =
          order
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)

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
