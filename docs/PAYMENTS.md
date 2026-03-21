# Emakola — Payment Integration Strategy

## Payment Landscape in West Africa

### Ghana (Launch Market)

| Method | Provider | Market Share | Integration |
|--------|----------|-------------|-------------|
| Mobile Money (MTN MoMo) | MTN | ~45% of digital payments | Paystack / Hubtel API |
| Mobile Money (Vodafone Cash) | Vodafone | ~20% | Paystack / Hubtel API |
| Mobile Money (AirtelTigo) | AirtelTigo | ~10% | Hubtel API |
| Debit/Credit Cards | Visa/Mastercard | ~15% | Paystack |
| Cash on Delivery | — | ~30% of ecommerce | Internal workflow |
| Bank Transfer | Various | ~5% | Manual / Paystack |

### Nigeria (Phase 3)

| Method | Provider | Market Share | Integration |
|--------|----------|-------------|-------------|
| Bank Transfer | All banks | ~40% | Paystack / Flutterwave |
| Cards | Visa/Mastercard/Verve | ~25% | Paystack / Flutterwave |
| Mobile Money | OPay, PalmPay | ~15% (growing) | Flutterwave |
| USSD | *737#, *966# etc | ~10% | Paystack |
| Cash on Delivery | — | ~25% | Internal workflow |

## Payment Architecture

### Abstract Payment Behaviour

```elixir
defmodule Emakola.Payments.Gateway do
  @doc "Behaviour for all payment gateway implementations"

  @callback initiate_payment(order :: map(), params :: map()) ::
    {:ok, payment_ref :: map()} | {:error, reason :: term()}

  @callback verify_payment(reference :: String.t()) ::
    {:ok, payment :: map()} | {:error, reason :: term()}

  @callback process_refund(payment_id :: String.t(), amount :: integer()) ::
    {:ok, refund :: map()} | {:error, reason :: term()}

  @callback handle_webhook(payload :: map(), signature :: String.t()) ::
    {:ok, event :: map()} | {:error, reason :: term()}
end
```

### Implementations

```elixir
# Card payments via Paystack
defmodule Emakola.Payments.Gateways.Paystack do
  @behaviour Emakola.Payments.Gateway
  # Handles: cards, bank transfer, USSD
end

# Mobile money via Hubtel
defmodule Emakola.Payments.Gateways.Hubtel do
  @behaviour Emakola.Payments.Gateway
  # Handles: MTN MoMo, Vodafone Cash, AirtelTigo
end

# Flutterwave (Nigeria expansion)
defmodule Emakola.Payments.Gateways.Flutterwave do
  @behaviour Emakola.Payments.Gateway
  # Handles: cards, bank transfer, mobile money (NG)
end

# Cash on delivery (internal)
defmodule Emakola.Payments.Gateways.CashOnDelivery do
  @behaviour Emakola.Payments.Gateway
  # Handles: COD workflow with driver confirmation
end
```

## Mobile Money Payment Flow

```
Customer              Emakola              Hubtel/Paystack          MTN MoMo
   │                    │                       │                      │
   │  Select MoMo       │                       │                      │
   │  Enter phone #     │                       │                      │
   ├───────────────────►│                       │                      │
   │                    │  Initiate payment      │                      │
   │                    ├──────────────────────►│                      │
   │                    │                       │  Send USSD prompt     │
   │                    │                       ├─────────────────────►│
   │                    │                       │                      │
   │  ◄── USSD prompt on phone ──────────────────────────────────────┤
   │  Enter PIN         │                       │                      │
   ├──────────────────────────────────────────────────────────────────►│
   │                    │                       │  Payment confirmed   │
   │                    │                       │◄─────────────────────┤
   │                    │  Webhook: success      │                      │
   │                    │◄──────────────────────┤                      │
   │                    │                       │                      │
   │  Order confirmed   │                       │                      │
   │  (SMS + WhatsApp)  │                       │                      │
   │◄───────────────────┤                       │                      │
```

**Key difference from card payments**: Mobile money is async — the customer gets a USSD prompt on their phone, enters their PIN, and we get a webhook callback. The checkout page must show a "Waiting for payment confirmation..." state with polling.

## Currency Handling

```elixir
# All amounts stored in minor units (pesewas, kobo)
# GHS 45.50 = 4550 pesewas
# NGN 15,000.00 = 1500000 kobo

defmodule Emakola.Money do
  defstruct [:amount, :currency]

  @type t :: %__MODULE__{
    amount: integer(),      # minor units
    currency: :GHS | :NGN | :XOF
  }

  def format(%__MODULE__{amount: amount, currency: :GHS}) do
    "GH₵ #{:erlang.float_to_binary(amount / 100, decimals: 2)}"
  end

  def format(%__MODULE__{amount: amount, currency: :NGN}) do
    "₦ #{:erlang.float_to_binary(amount / 100, decimals: 2)}"
  end
end
```

## Transaction Fees (Revenue Model)

| Plan | Monthly Fee | Transaction Fee |
|------|-----------|-----------------|
| Free | GH₵ 0 | 3.5% per transaction |
| Growth | GH₵ 49 | 2.0% per transaction |
| Pro | GH₵ 149 | 1.5% per transaction |
| Enterprise | Custom | Custom |

Paystack charges ~1.95% + fees. Our margin = our fee - gateway fee.
