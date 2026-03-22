defmodule Emakola.Payments.Gateways.CashOnDelivery do
  @moduledoc """
  Cash on Delivery (COD) payment gateway.

  COD payments are not processed through an external gateway.
  They are created in a :pending_cod state and confirmed when the
  delivery rider marks the order as delivered.

  Refunds are not supported for COD payments.
  """

  @behaviour Emakola.Payments.Gateway

  @impl true
  def initiate_payment(params) do
    reference = generate_reference()

    {:ok,
     %{
       status: :pending_cod,
       reference: reference,
       amount: params[:amount],
       order_id: params[:order_id]
     }}
  end

  @impl true
  def verify_payment(reference) do
    {:ok, %{status: :pending_cod, reference: reference}}
  end

  @impl true
  def process_refund(_reference, _amount) do
    {:error, :not_supported}
  end

  @impl true
  def verify_webhook(_body, _headers) do
    {:error, :not_supported}
  end

  defp generate_reference do
    uuid = Ecto.UUID.generate()
    "COD-#{uuid}"
  end
end
