defmodule EmakolaWeb.TrackingTokens do
  @moduledoc """
  Signs and verifies order-tracking buyer-authorization tokens with
  Phoenix.Token (TC-2 buyer protection).

  `EmakolaWeb.AuthTokens` is scoped to AshAuthentication session subjects —
  this is a distinct concern (an order-bound capability token handed to an
  anonymous buyer, not an authenticated session), so it gets its own module
  and salt rather than overloading AuthTokens.

  The merchant also knows the order number, so a bare tracking URL
  (`/track/:order_number`) must never let a viewer move money. Buyer-only
  actions on `EmakolaWeb.Storefront.TrackingLive` (confirm receipt, file a
  complaint) require this signed token, bound to the specific order and
  delivered to the buyer via the order SMS/WhatsApp notification.
  """

  @salt "order_tracking_v1"
  @max_age 60 * 60 * 24 * 90

  @doc "Signs an order id as a buyer-authorization token for its tracking link."
  def sign_order_tracking(order_id) when is_binary(order_id) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @salt, order_id)
  end

  @doc """
  Verifies a tracking token. Returns `{:ok, order_id}` or `{:error, reason}`.
  Safely rejects nil and non-binary input.
  """
  def verify_order_tracking(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @salt, signed, max_age: @max_age)
  end

  def verify_order_tracking(_), do: {:error, :missing}
end
