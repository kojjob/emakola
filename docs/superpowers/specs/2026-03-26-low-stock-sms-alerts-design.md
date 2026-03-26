# Low-Stock SMS/WhatsApp Alerts Design

## Overview

Add real-time and daily digest SMS/WhatsApp alerts to merchants when product variants drop below a stock threshold. The existing daily email alert worker is extended with SMS/WhatsApp, and a new real-time alert fires immediately on checkout when stock first crosses below the threshold.

## Architecture

### Real-Time Alert Flow

1. During checkout, `CheckoutService` calls `Variant.adjust_stock(delta: -quantity)`
2. After each stock decrement, check: `stock_quantity < 10 AND low_stock_alerted == false`
3. If triggered:
   - Set `low_stock_alerted = true` on the variant (prevents duplicate alerts)
   - Enqueue `LowStockSmsWorker` Oban job with variant_id and store_id
4. Worker loads variant, store, and store merchants
5. Sends SMS to `store.contact_phone` and WhatsApp to `store.whatsapp_number`

### Restock Reset

When `adjust_stock` is called with a positive delta and the resulting `stock_quantity >= 10`, reset `low_stock_alerted = false`. This means the next time stock drops below threshold, a new alert fires.

### Daily Digest Extension

The existing `LowStockAlertWorker` (cron at 8 AM UTC) already queries all low-stock variants and sends email. Extend it to also send one consolidated SMS and WhatsApp message per store listing how many items are low.

### Deduplication

The `low_stock_alerted` boolean on Variant ensures:
- Real-time: only one alert per stock-drop event (fires on first cross below threshold)
- Restock resets the flag, so a subsequent drop triggers a new alert
- Daily digest is unaffected (it always reports all currently-low items regardless of flag)

## Threshold

Default: 10 units. This matches the dashboard's low-stock count in the alerts panel.

Hardcoded constant for now. Per-store configurable threshold is a future enhancement.

## Files to Change

### New Migration
- Add `low_stock_alerted` boolean column (default false) to `variants` table

### Modify: `lib/emakola/catalog/resources/variant.ex`
- Add attribute: `low_stock_alerted :boolean, default: false`
- Modify `adjust_stock` action: after atomic update, check threshold crossing and set/reset `low_stock_alerted`

### Create: `lib/emakola/inventory/workers/low_stock_sms_worker.ex`
- Oban worker on `:notifications` queue
- Args: `variant_id`, `store_id`
- Loads variant (with product), store, and merchants via StoreMembership
- Sends SMS via `Emakola.Notifications.Channels.SMS.send_sms/3` to `store.contact_phone`
- Sends WhatsApp via `Emakola.Notifications.Channels.WhatsApp` to `store.whatsapp_number`
- Idempotent: if variant's `low_stock_alerted` is false when job runs, skip (stock was replenished between enqueue and execution)

### Modify: `lib/emakola/inventory/workers/low_stock_alert_worker.ex`
- After sending email, also send one SMS per store: "{count} items low on stock. Check your dashboard."
- Also send WhatsApp with same message

### Modify: `lib/emakola/orders/checkout_service.ex`
- After the stock decrement loop, check each variant for threshold crossing
- Enqueue `LowStockSmsWorker` for any newly-below-threshold variants

### Modify: `lib/emakola/notifications/templates.ex`
- Add `low_stock_realtime/3` template: "Low stock alert: {product_title} ({sku}) has only {qty} units left. Restock soon! - {store_name}"
- Add `low_stock_digest/2` template: "{count} items are running low on stock at {store_name}. Check your dashboard for details."

## SMS/WhatsApp Message Content

### Real-time (per variant)
```
Low stock alert: Kente Cloth (SKU-001) has only 3 units left. Restock soon! - Kente Kingdom
```

### Daily digest (per store)
```
5 items are running low on stock at Kente Kingdom. Check your dashboard for details.
```

## Testing Strategy

### Unit Tests
- `Variant.adjust_stock` sets `low_stock_alerted = true` when stock drops below 10
- `Variant.adjust_stock` resets `low_stock_alerted = false` when stock goes back above 10
- `Variant.adjust_stock` does NOT set flag if already true (no duplicate)
- `LowStockSmsWorker` sends SMS and WhatsApp when variant is below threshold
- `LowStockSmsWorker` skips sending if `low_stock_alerted` is false (replenished)
- `LowStockAlertWorker` sends SMS/WhatsApp in addition to email

### Integration Tests
- Checkout flow: place order that depletes stock below threshold, verify worker is enqueued
- Checkout flow: place two orders on same low-stock variant, verify only one alert
- Restock: adjust stock above threshold, verify flag reset, then new checkout triggers new alert

### Mocking
- SMS and WhatsApp channels mocked via existing Mox setup (LogSMS, LogWhatsApp providers in test)
