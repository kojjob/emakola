defmodule Emakola.Payments.PaystackWebhook do
  @moduledoc """
  Verifies and dispatches Paystack webhook events.

  Signature verification uses HMAC SHA-512 with the Paystack secret key.
  Event handling is synchronous but lightweight — heavy processing is
  delegated to the `PaystackWebhookHandler` Oban worker via the controller.

  This module can also be used standalone (outside the controller) when
  you need to process events directly, e.g. in tests or one-off scripts.
  """

  require Ash.Query

  alias Emakola.Payments.Payment

  @terminal_states [:success, :failed, :refunded]

  @doc """
  Verifies the HMAC SHA-512 signature of a Paystack webhook payload.

  Returns `:ok` if the signature matches, `{:error, :invalid_signature}` otherwise.
  """
  @spec verify_signature(binary(), String.t() | nil) :: :ok | {:error, :invalid_signature}
  def verify_signature(_raw_body, nil), do: {:error, :invalid_signature}
  def verify_signature(_raw_body, ""), do: {:error, :invalid_signature}

  def verify_signature(raw_body, signature) when is_binary(raw_body) and is_binary(signature) do
    computed =
      :crypto.mac(:hmac, :sha512, secret_key(), raw_body)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(computed, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  @doc """
  Handles a decoded Paystack webhook event.

  Supported events:
  - `charge.success` — marks payment as success, optionally confirms order
  - `charge.failed` — marks payment as failed
  - `refund.processed` — marks payment as refunded

  Unknown events are silently ignored (returns `:ok`).
  Processing is idempotent — terminal-state payments are not overwritten.
  """
  @spec handle_event(map()) :: :ok | {:error, term()}
  def handle_event(%{"event" => "charge.success", "data" => data}) do
    handle_charge(data, :mark_success)
  end

  def handle_event(%{"event" => "charge.failed", "data" => data}) do
    handle_charge(data, :mark_failed)
  end

  def handle_event(%{"event" => "refund.processed", "data" => data}) do
    reference = get_in(data, ["transaction", "reference"])
    refund_amount = data["amount"]

    with {:ok, payment} <- find_payment(reference) do
      if payment.status == :refunded do
        :ok
      else
        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: refund_amount})
        |> Ash.update!(authorize?: false)

        :ok
      end
    end
  end

  def handle_event(_), do: :ok

  # -- Private helpers -------------------------------------------------------

  defp handle_charge(data, action) do
    reference = data["reference"]

    with {:ok, payment} <- find_payment(reference),
         false <- terminal?(payment) do
      payment
      |> Ash.Changeset.for_update(action, %{gateway_response: data})
      |> Ash.update!(authorize?: false)

      if action == :mark_success, do: maybe_confirm_order(payment.order_id)

      :ok
    else
      true -> :ok
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
        order
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update(authorize?: false)

      _ ->
        :ok
    end
  end

  defp secret_key do
    Application.get_env(:emakola, :paystack_secret_key) ||
      raise "Paystack secret key not configured"
  end
end
