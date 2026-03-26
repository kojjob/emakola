# Email/SMS Receipts Design

## Overview

Send itemized email receipts and enhanced SMS receipts to customers when their order is confirmed (payment succeeds). Hooks into the existing `OrderNotificationWorker` on the `:order_confirmed` event.

## Trigger

The receipt fires on `:order_confirmed`, dispatched by `Dispatcher.dispatch(order, :order_confirmed)`. The existing `OrderNotificationWorker` already handles this event for SMS and WhatsApp. We extend it to also send an email receipt and upgrade the SMS to include item count and total.

## Email Receipt

### Content
- **Header**: Store name (logo URL if available)
- **Order info**: Order number, date (formatted from `inserted_at`)
- **Itemized table**: Product name, quantity, unit price, line total (from LineItems)
- **Totals section**: Subtotal, delivery fee (if > 0), discount (if > 0), total
- **Payment**: Gateway name (Paystack/Hubtel)
- **Shipping address**: Formatted from order's `shipping_address` map
- **Footer**: Store contact email/phone

### Format
- HTML email with inline CSS (email-safe, no external stylesheets)
- Plain-text fallback version
- Built with Swoosh, sent via `Emakola.Mailer`

### Module: `Emakola.Notifications.ReceiptEmail`
- `send_receipt(order, store)` -- public entry point
- Loads order with `[:line_items, :customer]` if not already loaded
- Sends to `customer.email`
- Returns `{:ok, email}` or `{:error, reason}`

## SMS Receipt

Update the existing `order_confirmed_sms` template in `Templates` to include item count and total:

```
Receipt: Order ORD-20260326-ABC123 from Kente Kingdom.
2 items | Total: GH₵150.00
Payment confirmed. Thank you!
```

This replaces the current generic "Your order has been confirmed" message. Under 160 characters for single SMS.

## Files to Change

### Create: `lib/emakola/notifications/receipt_email.ex`
- `send_receipt(order, store)` -- builds and delivers the email
- HTML template with inline CSS
- Plain-text fallback
- Follows the same pattern as `LowStockAlertWorker.Email`

### Modify: `lib/emakola/notifications/workers/order_notification_worker.ex`
- In the `:order_confirmed` handler, after sending SMS/WhatsApp, call `ReceiptEmail.send_receipt(order, store)`
- Load `:line_items` on the order (currently only loads `:customer`)

### Modify: `lib/emakola/notifications/templates.ex`
- Update `order_confirmed_sms/2` to accept order with line_items loaded
- New signature: `order_confirmed_sms(order, store)` (same, but message content changes)
- Include item count from `length(order.line_items)` and formatted total

## Testing Strategy

### Unit Tests
- `ReceiptEmail.send_receipt/2` builds email with correct subject, recipient, and body content
- Email HTML contains order number, line items, totals, store name
- Email plain-text contains the same information
- Handles orders with no discount (doesn't show discount line)
- Handles orders with no delivery fee

### Integration Tests
- `OrderNotificationWorker` sends receipt email on `:order_confirmed`
- Updated SMS template includes item count and total

### Mocking
- Email delivery via Swoosh test adapter (already configured in test)
- SMS via LogSMS provider (already configured)
