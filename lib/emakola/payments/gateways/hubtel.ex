defmodule Emakola.Payments.Gateways.Hubtel do
  @moduledoc "Hubtel payment gateway integration (Phase 1.5)."
  @behaviour Emakola.Payments.Gateway

  # TODO: Implement in Phase 1.5
  def initiate_payment(_params), do: {:error, :not_implemented}
  def verify_payment(_reference), do: {:error, :not_implemented}
  def process_refund(_reference, _amount), do: {:error, :not_implemented}
  def verify_webhook(_body, _headers), do: {:error, :not_implemented}
end
