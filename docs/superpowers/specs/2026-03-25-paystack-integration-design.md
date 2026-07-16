# Paystack Payment Gateway Integration — Design Spec

**Date:** 2026-03-25
**Status:** Approved

---

## Goal

Integrate Paystack as the primary payment gateway for Emakola, enabling merchants to accept card payments, mobile money (MTN MoMo, Telecel Cash, AirtelTigo), and bank transfers via Paystack's hosted checkout page.

## Architecture

Implements the existing `Emakola.Payments.Gateway` behaviour. Three modules: Gateway implementation, HTTP client, and webhook handler.

---

## Payment Flow

```
1. Customer clicks "Pay" at checkout
2. CheckoutService calls Paystack.initiate_payment/1
3. PaystackClient POSTs to /transaction/initialize
4. Paystack returns authorization_url
5. Customer redirected to Paystack hosted page
6. Customer pays (card, MoMo, bank transfer)
7. Paystack redirects to callback_url with reference
8. App calls Paystack.verify_payment/1 to confirm
9. Webhook (charge.success) arrives as backup confirmation
10. Order status updated to :paid
```

---

## Modules

### 1. `Emakola.Payments.Gateways.Paystack`

Implements `Emakola.Payments.Gateway` behaviour:

```elixir
@callback initiate_payment(map()) :: {:ok, map()} | {:error, term()}
@callback verify_payment(String.t()) :: {:ok, map()} | {:error, term()}
@callback process_refund(String.t(), integer()) :: {:ok, map()} | {:error, term()}
```

**initiate_payment/1** accepts:
```elixir
%{
  amount: 50000,           # pesewas (GHS 500.00)
  email: "customer@example.com",
  currency: "GHS",
  reference: "ORD-12345",  # order reference (idempotency key)
  callback_url: "https://store.emakola.com/s/slug/orders/ORD-12345/confirmation",
  metadata: %{
    order_id: "uuid",
    store_id: "uuid",
    store_name: "Kente Kingdom"
  }
}
```

Returns: `{:ok, %{authorization_url: "https://checkout.paystack.com/...", reference: "ORD-12345"}}`

**verify_payment/1** accepts reference string.
Returns: `{:ok, %{status: "success", amount: 50000, currency: "GHS", channel: "mobile_money", paid_at: ~U[...]}}`

**process_refund/2** accepts reference string and amount in pesewas.
Returns: `{:ok, %{status: "processed", refund_reference: "..."}}`

### 2. `Emakola.Payments.PaystackClient`

HTTP client using `Req` (already a dependency) or `HTTPoison`:

```elixir
def initialize_transaction(params)   # POST /transaction/initialize
def verify_transaction(reference)     # GET /transaction/verify/:reference
def create_refund(params)             # POST /refund
def list_banks()                      # GET /bank (for bank transfer)
```

**Config:**
```elixir
# config/runtime.exs
config :emakola, Emakola.Payments.PaystackClient,
  secret_key: System.get_env("PAYSTACK_SECRET_KEY"),
  public_key: System.get_env("PAYSTACK_PUBLIC_KEY"),
  base_url: "https://api.paystack.co"
```

All requests include `Authorization: Bearer SECRET_KEY` header.

### 3. `Emakola.Payments.PaystackWebhook`

Handles webhook events from Paystack:

**Signature verification:**
- Paystack sends `x-paystack-signature` header
- HMAC SHA512 of raw request body with secret key
- Reject if signature doesn't match

**Events handled:**
- `charge.success` — Mark payment as successful, update order status
- `refund.processed` — Mark refund as complete
- All other events — log and ignore

**Idempotency:** Check if payment/order already processed before applying. Webhooks can be delivered multiple times.

---

## Webhook Route

Already exists in router:
```elixir
scope "/webhooks" do
  pipe_through [:api]
  post "/paystack", WebhookController, :paystack
end
```

Update `WebhookController.paystack/2` to:
1. Read raw body
2. Verify HMAC signature
3. Parse JSON
4. Dispatch to `PaystackWebhook.handle_event/1`
5. Return 200 OK (always, even if event is ignored)

---

## Checkout Integration

Modify `Emakola.Orders.CheckoutService` to:
1. After creating order, call `Paystack.initiate_payment/1`
2. Return `authorization_url` to the LiveView
3. LiveView redirects customer to Paystack
4. On return, verify payment and show confirmation

---

## Testing Strategy

**Unit tests with Mox:**
- Define `Emakola.Payments.PaystackClientBehaviour`
- Mock in tests, never hit real Paystack API
- Test: successful payment init, failed payment, verification, refund
- Test: webhook signature verification (valid, invalid, missing)
- Test: webhook event handling (charge.success, refund.processed, unknown)
- Test: idempotency (same webhook delivered twice)

**No sandbox/live API calls in tests.**

---

## Files

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/emakola/payments/gateways/paystack.ex` | Gateway behaviour implementation |
| Create | `lib/emakola/payments/paystack_client.ex` | HTTP client wrapper |
| Create | `lib/emakola/payments/paystack_client_behaviour.ex` | Behaviour for mocking |
| Create | `lib/emakola/payments/paystack_webhook.ex` | Webhook event handler |
| Modify | `lib/emakola_web/controllers/webhook_controller.ex` | Wire up Paystack webhook |
| Modify | `lib/emakola/orders/checkout_service.ex` | Integrate Paystack payment init |
| Modify | `config/runtime.exs` | Add Paystack config |
| Create | `test/emakola/payments/gateways/paystack_test.exs` | Gateway tests |
| Create | `test/emakola/payments/paystack_webhook_test.exs` | Webhook tests |
| Create | `test/support/mocks.ex` | Mox mock definitions (if not exists) |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `PAYSTACK_SECRET_KEY` | Paystack secret key (starts with `sk_test_` or `sk_live_`) |
| `PAYSTACK_PUBLIC_KEY` | Paystack public key (starts with `pk_test_` or `pk_live_`) |

Test mode is auto-detected from the key prefix.

---

## Out of Scope

- Paystack inline/popup checkout (using hosted page instead — simpler, more secure)
- Paystack subscriptions/recurring billing
- Multi-currency beyond GHS (future)
- Paystack Transfer API (for merchant payouts)
