defmodule Emakola.Payments.Gateways.Hubtel do
  @moduledoc """
  Hubtel payment gateway integration for mobile money payments in Ghana.

  Implements the Gateway behaviour for Hubtel's Online Checkout API:
  - Invoice creation (online checkout)
  - Invoice status verification
  - Refund processing (not supported — Hubtel refunds are manual)
  - Webhook verification (status check API, no signatures)

  CRITICAL: All internal amounts are in pesewas (minor units).
  Hubtel API expects cedis (major units). We convert:
    - To Hubtel:   pesewas / 100.0  → cedis
    - From Hubtel:  round(cedis * 100)  → pesewas

  The HTTP calls are delegated to HubtelClient (or a Mox mock in tests)
  so this module only handles parameter mapping and response normalisation.
  """

  @behaviour Emakola.Payments.Gateway

  # ── Callbacks ──────────────────────────────────────────────────

  @impl true
  def initiate_payment(params) do
    reference = generate_reference(params.store_id)
    amount_cedis = pesewas_to_cedis(params.amount)

    body = %{
      "totalAmount" => amount_cedis,
      "description" => params[:description] || "Order #{params[:order_reference]}",
      "callbackUrl" => params[:callback_url],
      "returnUrl" => params[:return_url],
      "clientReference" => reference
    }

    case hubtel_client().create_invoice(body) do
      {:ok, %{"responseCode" => "0000", "data" => data}} ->
        {:ok,
         %{
           authorization_url: data["checkoutUrl"],
           reference: data["clientReference"] || reference
         }}

      {:ok, %{"responseCode" => code} = resp} ->
        {:error, {:hubtel_error, resp["message"] || "Hubtel error (#{code})"}}

      {:error, reason} ->
        {:error, {:gateway_error, reason}}
    end
  end

  @impl true
  def verify_payment(reference) do
    case hubtel_client().check_invoice_status(reference) do
      {:ok, %{"responseCode" => "0000", "data" => data}} ->
        {:ok,
         %{
           status: map_status(data["invoiceStatus"]),
           amount: cedis_to_pesewas(data["totalAmount"]),
           reference: data["clientReference"] || reference,
           channel: data["paymentChannel"],
           raw: data
         }}

      {:ok, %{"responseCode" => code} = resp} ->
        {:error, {:hubtel_error, resp["message"] || "Hubtel error (#{code})"}}

      {:error, reason} ->
        {:error, {:gateway_error, reason}}
    end
  end

  @impl true
  def process_refund(_reference, _amount) do
    {:error, :not_supported}
  end

  @impl true
  def create_subaccount(_params) do
    # Hubtel has no split/subaccount API — dropship orders paid via Hubtel
    # fall back to the manual supplier ledger.
    {:error, :not_supported}
  end

  @impl true
  def verify_webhook(body, _headers) do
    # Hubtel doesn't use webhook signatures (uses IP allowlisting instead).
    # We verify by calling the payment status check API to confirm the transaction.
    with {:ok, parsed} <- Jason.decode(body),
         reference when is_binary(reference) <- parsed["ClientReference"],
         {:ok, %{status: status}} when status in [:paid, :completed] <-
           verify_payment(reference) do
      :ok
    else
      _ -> {:error, :invalid_signature}
    end
  end

  # ── Private Helpers ──────────────────────────────────────────────

  defp pesewas_to_cedis(pesewas) when is_integer(pesewas) do
    pesewas / 100.0
  end

  defp cedis_to_pesewas(cedis) when is_number(cedis) do
    round(cedis * 100)
  end

  defp map_status("paid"), do: :paid
  defp map_status("Paid"), do: :paid
  defp map_status("completed"), do: :completed
  defp map_status("Completed"), do: :completed
  defp map_status("failed"), do: :failed
  defp map_status("Failed"), do: :failed
  defp map_status("pending"), do: :pending
  defp map_status("Pending"), do: :pending
  defp map_status("cancelled"), do: :cancelled
  defp map_status("Cancelled"), do: :cancelled
  defp map_status(nil), do: :unknown
  defp map_status(_other), do: :unknown

  defp generate_reference(store_id) do
    prefix = store_id |> to_string() |> String.slice(0, 6)
    timestamp = System.system_time(:second)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "HUB-#{prefix}-#{timestamp}-#{random}"
  end

  defp hubtel_client do
    Application.get_env(:emakola, :hubtel_client, Emakola.Payments.HubtelClient)
  end
end
