# Payout-Execution Engine — Design

## Context

The revenue rails (#206–#208) collect money and split it at the gateway, and the
`/platform/finance` page surfaces an **outstanding-payouts backlog**: successful **un-split**
(`split_mode: :none`) orders where the platform holds 100% and still owes the merchant. Today
there is **no way to move that money out** — no Paystack Transfer API, no payout ledger, no
transfer webhooks. (Split orders already settle automatically: `charge.success` marks their
`PaymentSplit`s `:settled` in `paystack_webhook_handler.ex`.)

This engine builds the missing capability: **disburse the held balance to merchants**, safely.

**Ops gate (resolved by research):** Paystack Ghana supports Transfers to mobile money wallets
and bank accounts. Recipient: `POST /transferrecipient` (`type: "mobile_money"`, `name`,
`account_number` = phone, `bank_code` = telco code [MTN/VOD/ATL, same as subaccount settlement
codes], `currency: "GHS"`) → `recipient_code`. Transfer: `POST /transfer` (`source: "balance"`,
`amount` in pesewas, `recipient`, `reason`, `reference` = our idempotency key, `currency`) →
`transfer_code` + status. Min GHS 1, max GHS 100,000.

Branch (Slice 1): `feature/payout-transfer-rails`. TDD throughout.

## Decisions (confirmed with the user)

- **D1 — Human-approval gate.** v1 never disburses unattended; a platform admin approves each
  payout before money moves.
- **D2 — Action on the Finance page.** The "Pay out" control lives on the per-store row of the
  existing `/platform/finance` page (no new queue surface for v1).
- **D3 — Double-pay protection.** Covered payments are stamped (`paid_out_at`, `payout_id`) when
  a payout is created, so outstanding excludes them and a payout can't be made twice for the
  same money; plus a unique Paystack transfer `reference`.

## Architecture

1. **Transfer rails** — `create_transfer_recipient/1` + `initiate_transfer/1` on the Paystack
   client + Gateway behaviour (mirrors `create_subaccount`).
2. **Payout ledger** — a `Payout` resource recording each disbursement and its lifecycle.
3. **Approval + execution** — an admin approves a store's outstanding balance → an idempotent
   worker creates the recipient + initiates the transfer. Audited.
4. **Confirmation** — `transfer.success` / `transfer.failed` webhooks finalize the Payout.

A payout's amount is the merchant's net owed. **v1 does not deduct a fee** from the backlog
payout (those `:none` orders never had a platform fee taken — the platform holds the full
amount and owes it in full); fee-on-backlog is out of scope.

---

# Slice 1 — Transfer rails + Payout ledger (ships dark)

No money moves: nothing creates a payout or fires a transfer until Slice 2. This slice is the
data layer + the gateway calls, fully unit-tested with Mox.

### Transfer rails
- `Emakola.Payments.Gateway` behaviour: add `@callback create_transfer_recipient(map())` and
  `@callback initiate_transfer(map())`.
- `Gateways.Paystack`: implement both → delegate to `paystack_client()`.
  - `create_transfer_recipient(%{type:, name:, account_number:, bank_code:, currency:})` →
    `{:ok, %{recipient_code: code, raw: data}}`.
  - `initiate_transfer(%{source:, amount:, recipient:, reason:, reference:, currency:})` →
    `{:ok, %{transfer_code:, status:, raw: data}}`.
- `PaystackClient`: `create_transfer_recipient/1` POSTs `/transferrecipient`;
  `initiate_transfer/1` POSTs `/transfer`.
- `Gateways.Mock` (test stub): both return deterministic `{:ok, …}`.
- `PaystackClientMock` (Mox): both added so tests can assert params / force errors.

### `Emakola.Payments.Payout` resource
- `postgres` table `payouts`; `multitenancy strategy: :attribute, attribute: :store_id,
  global?: true` (cross-store platform reads with `authorize?: false`, mirrors `Payment`).
- Attributes: `store_id` (uuid, not nil), `amount` (integer, not nil, minor units), `currency`
  (string, default "GHS"), `status` (atom, one_of `[:pending, :processing, :paid, :failed]`,
  default `:pending`), `recipient_code` (string, nil), `transfer_code` (string, nil),
  `transfer_reference` (string, nil — our idempotency key), `failure_reason` (string, nil),
  `gateway_response` (map, sensitive), `metadata` (map, default `%{}`), timestamps.
- Actions: `create` (accept store_id, amount, currency, transfer_reference, metadata);
  `mark_processing` (accept recipient_code, transfer_code; set `:processing`); `mark_paid`
  (accept gateway_response; set `:paid`); `mark_failed` (accept failure_reason, gateway_response;
  set `:failed`); reads `by_store` (arg store_id, sorted desc) and `by_transfer_reference`
  (arg reference).
- Code interfaces in `Emakola.Payments`: `create_payout`, `mark_payout_processing`,
  `mark_payout_paid`, `mark_payout_failed`, `list_payouts_by_store`,
  `get_payout_by_transfer_reference`.

### Payment stamping fields + finance exclusion
- Add to `Payment`: `paid_out_at` (utc_datetime_usec, nil) and `payout_id` (uuid, nil), both
  `public?`. Accept them in a new `mark_paid_out` update action (accept `[:payout_id]`, set
  `paid_out_at` to now) — Slice 2 calls it when a payout covers the payment.
- `FinanceStats.total_outstanding_payouts/0` and `per_store_finance/0` add
  `is_nil(paid_out_at)` to the outstanding filter so paid-out money drops out of the backlog.

### Migration
One `mix ash.codegen add_payouts` for the `payouts` table + the two `Payment` columns. Watch the
codegen drift trap (delete the unrelated phone_otps/merchant_identities/customers/merchants
snapshots + migration noise) and the `null: false`-on-its-own-line format gotcha.

### Build sequence (tests → impl → green)
1. Payout resource + interfaces + Payment fields → codegen migration → resource/action tests
   (create → pending; mark_processing/paid/failed transitions; reads).
2. Transfer rails (client/gateway/behaviour/mock/Mox) → gateway tests asserting recipient +
   transfer params route to `PaystackClientMock`; error passthrough.
3. FinanceStats exclusion → extend `finance_stats_test` (a paid-out payment drops from
   outstanding + per-store).
4. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new/changed files
   clean under `--warnings-as-errors`. PR.

---

# Slice 2 — Gated execution + confirmation (money moves)

- **`PayoutService` / `PayoutWorker`**: given a store, gather its outstanding `:none` successful
  payments (`paid_out_at` nil), sum them, create a `Payout` (`:pending`) with a unique
  `transfer_reference`, stamp each payment via `mark_paid_out`, create the transfer recipient
  from `StorePayoutAccount.payout_destination` (provider→bank_code), initiate the transfer, and
  `mark_processing`. Idempotent (unique on store + reference; guards on already-stamped
  payments). On gateway error → `mark_failed` + leave money reclaimable.
- **Webhook**: handle `transfer.success` / `transfer.failed` in `paystack_webhook(_handler)` →
  find the `Payout` by `transfer_reference`/`transfer_code` → `mark_paid` / `mark_failed`.
- **Finance-page approval**: a "Pay out" action on each store row → confirmation modal showing
  the amount + destination → on confirm, gate with `authorized/2` (`:manage_billing`) +
  `reload_current_user/1`, enqueue the worker, and audit (`:payout_approved` /
  `:payout_initiated` added to the `PlatformAuditLog` allowlist).
- Tests: worker (creates payout, stamps payments, routes transfer params, idempotent re-run is a
  no-op, gateway error → failed); webhook (success/failed finalize the payout); LiveView
  (permission gating, approval audits + enqueues, double-click can't double-pay).

## Out of scope (v1, whole engine)
Scheduled/automatic batch payouts; partial payouts; bank (non-MoMo) recipients if Paystack needs
different verification; supplier payouts (separate `SupplierLedgerEntry` flow); fee deduction on
backlog payouts; multi-currency.
