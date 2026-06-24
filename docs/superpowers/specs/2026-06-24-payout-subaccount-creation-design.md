# Payout Subaccount Creation (Revenue Rails — Slice 1) — Design

## Context

Revenue rails, slice 1 of 2. The payout-onboarding page (`/admin/payouts`, shipped)
captures a merchant's `payout_destination` but never creates a Paystack subaccount, so
`store_payout_accounts.verification_status` stays `:unverified`, `subaccount_code` is nil,
and `OrderSettlement.prepare` always falls through to `{:no_split}` — no order can route
the merchant their share, and the platform can't take a fee as the split remainder.

**Ops gate (resolved by research):** Paystack Ghana's List Banks returns mobile-money
providers as settlement destinations (`MTN`, `VOD` for Vodafone/Telecel, AirtelTigo), each
`type: "mobile_money"`, `currency: "GHS"`. So a subaccount can settle to a merchant's MoMo
number — split-at-source is viable.

This slice turns a saved payout account into a real Paystack subaccount. Slice 2 (platform
fee on normal orders, extending `OrderSettlement`) follows and depends on this.

Branch: `feature/payout-subaccount-creation`. TDD throughout.

## Architecture

A fire-and-forget Oban worker created after a payout account is saved. Async so the
Paystack network call never blocks the merchant's save and retries on transient failure.

### `Emakola.Payments.Workers.SubaccountCreationWorker`
- `queue: :default, max_attempts: 3, unique: [period: 600, fields: [:args]]` (idempotent).
- `enqueue(store_id)` — thin, never raises.
- `perform`:
  1. Load the store's `StorePayoutAccount` (via `get_payout_account`, `authorize?: false`).
  2. **Idempotency:** if it already has a `subaccount_code`, return `:ok` (no-op).
  3. **MoMo-only v1:** if `payout_destination["method"] != "mobile_money"`, log + `:ok`
     (bank subaccounts need a bank-name→code lookup; deferred).
  4. Build params and call the gateway:
     `gateway().create_subaccount(%{business_name:, settlement_bank:, account_number:, percentage_charge: 0})`
     where `gateway()` = `Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)`.
     - `business_name`: the store's name (loaded via `Stores.get_store`).
     - `settlement_bank`: provider→code — `"mtn" → "MTN"`, `"vodafone" → "VOD"`, `"airteltigo" → "ATL"`.
     - `account_number`: `payout_destination["number"]`.
     - `percentage_charge: 0` — we split flat per-transaction (split-remainder), never by %.
  5. On `{:ok, %{subaccount_code: code}}` → `Stores.record_payout_subaccount(account, %{subaccount_code: code}, authorize?: false)` (the existing `:record_subaccount` action sets `verification_status: :verified`).
  6. On `{:error, _}` → log + return `{:error, _}` so Oban retries.

### Wiring
- New code interface `define(:record_payout_subaccount, action: :record_subaccount)` on `StorePayoutAccount` in `Stores`.
- `EmakolaWeb.Admin.PayoutLive` enqueues `SubaccountCreationWorker.enqueue(store.id)` after a successful `create_payout_account` / `update_payout_account`.

## Out of scope (this slice)
Bank-account subaccounts (need List Banks resolution); the platform fee on normal orders
(Slice 2); the operational Paystack-dashboard subaccount verification (Paystack holds the
first payout to a new subaccount until a human verifies it — a launch runbook item, not code).

## Build sequence (tests → impl → green)
1. `record_payout_subaccount` interface + provider→code mapping → small resource/mapping test.
2. `SubaccountCreationWorker` → worker tests: MoMo account → Mox `PaystackClientMock.create_subaccount` returns a code → account becomes `:verified` with `subaccount_code`; bank/already-coded → no-op (no gateway call); gateway error → `{:error, _}` (retry). Build the payout account via `Factory.create_store!` + `Stores.create_payout_account`.
3. Enqueue from `PayoutLive` → LiveView test asserts `assert_enqueued worker: SubaccountCreationWorker, args: %{"store_id" => id}` after a MoMo save.
4. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new test files clean under `--warnings-as-errors`. PR.

## Verification
Automated as above. Manual (post-merge, with real Paystack keys): a merchant saves MoMo payout details → the worker creates a Paystack subaccount → `verification_status: :verified`, `subaccount_code` populated → confirmed in the Paystack dashboard (then verify it there to release the first payout).
