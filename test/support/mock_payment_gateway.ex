defmodule Emakola.Payments.Gateways.Mock do
  @moduledoc """
  Mock payment gateway for testing checkout flows.
  Always returns success for initiate_payment and verify_payment.
  """

  @behaviour Emakola.Payments.Gateway

  @impl true
  def initiate_payment(_params) do
    reference = "MOCK-#{System.unique_integer([:positive])}"

    {:ok,
     %{
       authorization_url: "https://mock.paystack.co/pay/#{reference}",
       access_code: "mock_access_#{reference}",
       reference: reference
     }}
  end

  @impl true
  def verify_payment(reference) do
    {:ok,
     %{
       status: :success,
       amount: 0,
       currency: "GHS",
       reference: reference,
       gateway_response: "Approved",
       channel: "mobile_money",
       paid_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       raw: %{}
     }}
  end

  @impl true
  def process_refund(reference, amount) do
    {:ok,
     %{
       amount: amount,
       status: :processed,
       reference: reference,
       refund_reference: "REF-#{reference}",
       raw: %{}
     }}
  end

  @impl true
  def verify_webhook(_body, _headers) do
    :ok
  end
end
