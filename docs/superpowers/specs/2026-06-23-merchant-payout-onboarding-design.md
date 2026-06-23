# Merchant Payout Onboarding (SP1, path-independent slice) — Design

## Context

The revenue-first plan (`docs/REVENUE-FIRST-90-DAY-PLAN.md`) identifies **SP1 — merchant payout onboarding** as the monetization unlock: to pay a merchant *retail − platform fee*, the merchant must first register a payout destination. Exploration confirmed the rails are stubbed but unwired — `StorePayoutAccount` exists with `:create`/`:update`/`:record_subaccount` actions, but `create`/`record_subaccount` are **never called** (no onboarding UI), so 0 payout accounts exist; consequently dropship splits always fall back to `{:no_split}` and no platform fee is taken on any order.

**The plan says one ops question "decides SP1's design": can Paystack Ghana pay out to MoMo subaccounts?** That's unconfirmed (a founder action). So this spec builds **only the path-independent slice**: capture the merchant's payout details. It deliberately does **not** create a Paystack subaccount, apply a platform fee, or move money — those settlement pieces (subaccount-split vs ledger payout) wait on the ops answer. Zero money-movement risk.

**Decision (with user):** build the path-independent payout-onboarding form now; defer settlement.

Branch: `feature/merchant-payout-onboarding`. TDD throughout.

## Data — `Emakola.Stores.StorePayoutAccount`

The resource already exists (per-store, `:create`/`:update`/`:get_by_store`/`:record_subaccount`, `verification_status` `:unverified|:verified`, `payout_destination :map`). Changes:
- Expose `:create` and `:update` (and keep `get_by_store`) as code interfaces in the Stores domain (today only `get_payout_account` is defined).
- Persist the merchant's method in `payout_destination` (string-keyed map): `method` (`"mobile_money" | "bank"`); for mobile money → `provider` (`mtn`/`vodafone`/`airteltigo`), `number`, `account_name`; for bank → `bank_name`, `account_number`, `account_name`.
- `verification_status` stays `:unverified` (no subaccount created in this slice). No schema/migration change needed.

## Merchant page — `/admin/payouts` (`EmakolaWeb.Admin.PayoutLive`)

In the `:app` live_session (current_store available). Mirrors the `/admin/verification` page:
- Loads the store's `StorePayoutAccount` (or nil) in mount.
- Shows current payout details (or an empty state) + a status note: *"Saved — you'll be able to receive payouts once Makola enables payouts in your region."* (honest about the ops gate).
- A form: method selector (Mobile money / Bank) + the relevant fields; `phx-submit` creates the account if none exists, else updates it. Inputs validated for presence; `payout_destination` assembled from the form.
- Sidebar "Payouts" nav link (icon `payments` or `currency`).

Atom-from-form safety: the `method`/`provider` values are validated against fixed allowlists via `Emakola.SafeAtom.to_atom_in/3` if converted to atoms (or kept as strings in the map — preferred, since `payout_destination` is jsonb).

## Out of scope (next slice, after the ops answer)

Paystack subaccount creation (`create_subaccount/1` + `record_subaccount`), the platform fee on normal orders (split-remainder), the split/ledger settlement, and the platform-side payout-oversight dashboard.

## Files

- `lib/emakola/stores/stores.ex` (expose `create_payout_account` / `update_payout_account`)
- `lib/emakola_web/live/admin/payout_live.ex` (new) + router `:app` + sidebar nav (`app.html.heex`)

## Build sequence (tests → impl → green)

1. Code interfaces for `StorePayoutAccount` create/update → resource-interface test (create persists `payout_destination`; update changes it; one per store).
2. `Admin.PayoutLive` + route + nav → LiveView tests (empty state shows form; submit persists details + status; update path).
3. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

## Verification (end-to-end)

Automated: `StorePayoutAccount` create/update via the new interfaces; `PayoutLive` test (`setup_authenticated_merchant`; submit a MoMo payout → `payout_destination` persisted with `verification_status: :unverified`, status note shown; re-submit updates). Suite green + format + credo.

Manual: as a merchant open `/admin/payouts`, enter a MoMo number, save → details persist and show "verification pending."
