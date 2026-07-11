defmodule Emakola.Payments.HubtelWebhook do
  @moduledoc """
  Dispatches Hubtel webhook events to update payment and order records.

  Hubtel sends POST webhooks on payment status changes with a JSON body
  containing `ResponseCode`, `Data.ClientReference`, `Data.Amount`, etc.

  Unlike Paystack, Hubtel does not sign webhooks — verification is done
  by calling the Hubtel status check API in the background worker.
  This module handles the event dispatch after verification.

  Processing is idempotent — terminal-state payments are not overwritten.
  """

  require Ash.Query

  alias Emakola.Payments.Payment

  @terminal_states [:success, :failed, :refunded]

  @doc """
  Handles a decoded Hubtel webhook event.

  Supported response codes:
  - `"0000"` — Successful payment
  - Any other code — Failed/declined payment

  Unknown or malformed events are silently ignored (returns `:ok`).
  """
  @spec handle_event(map()) :: :ok | {:error, term()}
  def handle_event(%{"ResponseCode" => "0000", "Data" => data}) do
    reference = data["ClientReference"]
    amount = data["Amount"]

    with {:ok, payment} <- find_payment(reference) do
      payment =
        case payment.status do
          # Already success (webhook retry/replay) — fall through to the
          # idempotent post-processing below so a prior partial failure is
          # recovered rather than skipped (mirrors the Paystack handler).
          :success ->
            payment

          # A late success after a terminal failure/refund — don't override.
          status when status in [:failed, :refunded] ->
            payment

          _ ->
            gateway_response = %{
              "response_code" => "0000",
              "amount" => amount,
              "client_reference" => reference
            }

            payment
            |> Ash.Changeset.for_update(:mark_success, %{gateway_response: gateway_response})
            |> Ash.update!(authorize?: false)
        end

      if payment.status == :success do
        maybe_confirm_order(payment.order_id)
        Emakola.Suppliers.GroupBuys.confirm_payment(payment)
        Emakola.Suppliers.ProtectedPreorders.confirm_payment(payment)
        Emakola.Suppliers.SalesTeams.settle_attributed_payment(payment)

        Emakola.Suppliers.InventoryReservations.consume_for_order(
          payment.order_id,
          payment.store_id
        )
      end

      :ok
    end
  end

  def handle_event(%{"ResponseCode" => code, "Data" => data}) when is_binary(code) do
    reference = data["ClientReference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      gateway_response = %{
        "response_code" => code,
        "message" => data["Message"] || "Payment failed",
        "client_reference" => reference
      }

      payment
      |> Ash.Changeset.for_update(:mark_failed, %{gateway_response: gateway_response})
      |> Ash.update!(authorize?: false)

      :ok
    else
      true -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_event(_), do: :ok

  # -- Private helpers -------------------------------------------------------

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
