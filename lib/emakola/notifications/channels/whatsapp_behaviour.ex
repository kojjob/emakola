defmodule Emakola.Notifications.Channels.WhatsAppBehaviour do
  @moduledoc """
  Behaviour for WhatsApp Business API message delivery.

  Defines the contract for sending order lifecycle notifications via
  WhatsApp Cloud API template messages. Implementations must handle
  HTTP communication with the WhatsApp Business API.

  The existing `Emakola.Notifications.WhatsAppProvider` behaviour is
  for low-level message sending. This behaviour provides higher-level
  order-specific notification methods.
  """

  @type order :: map()
  @type tracking_info :: map()
  @type opts :: keyword()
  @type success :: {:ok, map()}
  @type error :: {:error, term()}

  @doc "Send an order confirmation WhatsApp message to the customer."
  @callback send_order_confirmation(order(), opts()) :: success() | error()

  @doc "Send a shipping update WhatsApp message with tracking info."
  @callback send_shipping_update(order(), opts()) :: success() | error()

  @doc "Send a delivery confirmation WhatsApp message."
  @callback send_delivery_confirmation(order(), opts()) :: success() | error()
end
