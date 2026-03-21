# Emakola — Messaging & Communication

## Priority Order
1. **WhatsApp** — 93% penetration in Ghana, highest open rates
2. **SMS** — fallback for non-WhatsApp users
3. **Email** — supplementary (receipts, marketing)

## Message Matrix

### Transactional (must send)
| Event | WhatsApp | SMS | Email |
|-------|----------|-----|-------|
| Order confirmed | Primary | Fallback | Receipt |
| Payment received (MoMo) | Primary | Fallback | Receipt |
| Payment failed | Primary | Fallback | — |
| Order shipped + tracking | Primary | Fallback | — |
| Order delivered | Primary | Fallback | — |
| Refund processed | Primary | Fallback | Receipt |
| Password reset | — | OTP | Link |
| Account verification | — | OTP | Link |
| Low stock alert (merchant) | Primary | Fallback | — |

### Marketing (opt-in)
| Event | WhatsApp | SMS | Email |
|-------|----------|-----|-------|
| Abandoned cart (1hr) | Primary | — | Backup |
| Abandoned cart (24hr) | Primary | Fallback | Backup |
| Review request (3d post-delivery) | Primary | — | Backup |
| Sale/promotion | Primary | Opt-in | Primary |
| New collection | Primary | — | Primary |

## SMS Templates (Ghana — via Hubtel)

```
ORDER CONFIRMED
Hi {name}! Order #{num} confirmed. Total: GH₵{amount}.
Track: {url}
-{store}

PAYMENT RECEIVED
GH₵{amount} received via {method} for #{num}. Preparing your order!
-{store}

SHIPPED
#{num} is on its way! Track: {url}
Est. delivery: {date}
-{store}

DELIVERED
#{num} delivered! Rate your experience: {url}
-{store}

ABANDONED CART
Hi {name}, you left items at {store}. Complete your order: {url}
Reply STOP to unsubscribe

OTP
Your Emakola code is {code}. Valid for 10 minutes. Do not share.
```

## WhatsApp Business API

### Provider Options
- **Meta Cloud API** (direct) — free tier available, most control
- **360dialog** — easier setup, per-message pricing
- **Recommendation**: Start with 360dialog for MVP, migrate to Meta direct at scale

### Template Messages (pre-approved)
```
# order_confirmation
Hi {{1}}! Your order #{{2}} has been confirmed.

Total: GH₵{{3}}
Items: {{4}}

Track your order: {{5}}

Thank you for shopping with {{6}}!

# shipping_update
Great news! Your order #{{1}} has been shipped.

Courier: {{2}}
Tracking: {{3}}
Estimated delivery: {{4}}

# payment_received
We've received your payment of GH₵{{1}} via {{2}}.

Order #{{3}} is being prepared. We'll notify you when it ships.
```

## Implementation

```elixir
defmodule Emakola.Messaging do
  @moduledoc "Unified messaging with fallback chain"

  def notify(recipient, event, data) do
    preferences = get_preferences(recipient)

    cond do
      preferences.whatsapp && whatsapp_available?() ->
        queue_whatsapp(recipient, event, data)
      preferences.sms ->
        queue_sms(recipient, event, data)
      preferences.email ->
        queue_email(recipient, event, data)
      true ->
        Logger.warning("no_delivery_channel", %{recipient: mask(recipient), event: event})
    end
  end

  defp queue_whatsapp(recipient, event, data) do
    %{recipient: recipient, event: event, data: data}
    |> Emakola.Messaging.Workers.SendWhatsApp.new()
    |> Oban.insert()
  end

  defp queue_sms(recipient, event, data) do
    %{recipient: recipient, event: event, data: data}
    |> Emakola.Messaging.Workers.SendSMS.new()
    |> Oban.insert()
  end
end
```

### Oban Workers
```elixir
defmodule Emakola.Messaging.Workers.SendSMS do
  use Oban.Worker,
    queue: :messaging,
    max_attempts: 3,
    priority: 1  # transactional = high priority

  @impl true
  def perform(%Oban.Job{args: %{"recipient" => phone, "event" => event, "data" => data}}) do
    template = Emakola.Messaging.Templates.sms_template(event, data)
    case sms_provider().send(phone, template) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}  # Oban retries
    end
  end
end
```

## Phone Number Handling

| Country | Format | Example |
|---------|--------|---------|
| Ghana | +233XXXXXXXXX | +233241234567 |
| Nigeria | +234XXXXXXXXXX | +2348012345678 |

```elixir
defmodule Emakola.Phone do
  def normalize("+233" <> _ = phone), do: {:ok, phone}
  def normalize("0" <> rest) when byte_size(rest) == 9, do: {:ok, "+233" <> rest}
  def normalize("233" <> _ = phone), do: {:ok, "+" <> phone}
  def normalize(_), do: {:error, :invalid_phone}

  def mask("+233" <> rest), do: "+233****" <> String.slice(rest, -4, 4)
end
```
