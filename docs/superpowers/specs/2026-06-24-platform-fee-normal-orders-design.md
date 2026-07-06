# Platform Fee on Normal Orders (Revenue Rails — Slice 2) — Design

## Context

Revenue rails, slice 2 of 2. Slice 1 turned a merchant's saved MoMo payout account
into a verified Paystack subaccount. This slice uses that subaccount to **pay the
merchant directly at the gateway, minus the platform's transaction fee**, on normal
(own-stock) orders.

Today `OrderSettlement.prepare/2` only splits **dropship** orders. A normal order has
no dropship suppliers, so `DropshipSettlement.prepare` returns
`{:no_split, :no_dropship_items}` and the **entire** customer charge lands in the
platform's Paystack main account — the merchant is then paid out manually. That is the
opposite of the transaction-fee-first model: the platform should keep only its small fee
and route the rest to the merchant automatically.

Branch: `feature/platform-fee-normal-orders` (off `main`; code-independent of slice 1).
TDD throughout.

## Decisions (confirmed with the user)

- **Fee base:** `order.total` (simplest; clean `net + fee == total` invariant). Charging
  on the merchandise subtotal only is a later refinement.
- **Default rate:** `200` bps (2%), via new config `:platform_fee_rate_bps`. Separate from
  the existing `:dropship_fee_rate_bps` (1000).

## Architecture

Extend the **existing split-remainder model** (the platform's cut is the unassigned
remainder Paystack leaves in the main account — the same trick the dropship path uses).

### `OrderSettlement.prepare/2`
Add a branch on `{:no_split, :no_dropship_items}` (a genuinely own-stock order). Other
`:no_split` reasons (e.g. `:supplier_not_linked`) keep today's behavior untouched — we
only take a fee when the order is normal, never when a dropship split was attempted and
failed.

```
{:no_split, :no_dropship_items} -> prepare_platform_fee(order, store_id)
```

`prepare_platform_fee/2`:
1. Resolve the store's verified subaccount (mirror `DropshipSettlement.verified_subaccount/1`:
   `get_payout_account` → `%{verification_status: :verified, subaccount_code: code}` when
   `is_binary(code)`). No verified subaccount → `{:no_split, :payout_unverified}` (the
   merchant simply settles via the main account as before — graceful, no fee taken).
2. `%{fee: fee, net: net} = PlatformFee.calculate(order.total, platform_fee_rate_bps())`.
3. Guard `net > 0` (a pathological 100% rate) → else `{:no_split, :unrepresentable_split}`.
4. Build allocations and reuse `gateway_shares/1` (only allocations **with** a subaccount
   become shares; the platform fee has none, so it stays the remainder):
   - `%{role: :merchant, amount: net, subaccount_code: code}`
   - `%{role: :platform, amount: fee, subaccount_code: nil}`
5. Return `{:split, %{total: order.total, allocations: allocations,
   shares: gateway_shares(allocations), mode: :platform_fee}}`.

### Tagging the mode
The existing dropship `:split` returns gain `mode: :dropship_split`. `checkout_live`'s
`split_mode/1` changes from hard-coding `:dropship_split` to reading the map:
`split_mode({:split, %{mode: mode}}), do: mode`. `maybe_attach_split` (matches
`%{shares:}`) and `record_splits` (matches `%{allocations:}`) are unchanged.

### Resource constraints (one `ash.codegen` migration if needed)
- `Payment.split_mode` one_of += `:platform_fee`.
- `PaymentSplit.role` one_of += `:merchant`.

Recording **both** allocations (via the existing `record_splits!`) means "platform fees
collected" is immediately queryable (`PaymentSplit` where `role == :platform`), feeding the
future finance-oversight page. The merchant net is the `:merchant` split.

### Config
`platform_fee_rate_bps/0` → `Application.get_env(:emakola, :platform_fee_rate_bps, 200)`.

## Out of scope (this slice)
Payout *execution*/scheduling; per-store fee overrides; fee on dropship orders (those keep
their own 10% margin split); the finance reporting LiveView (a separate Part-2 feature);
fee-on-subtotal (delivery-exempt) basis.

## Build sequence (tests → impl → green)
1. Add `:platform_fee` / `:merchant` to the constraints; `mix ash.codegen` (migration only
   if a DB check constraint exists). Watch the codegen format gotcha (`null: false` on its
   own line).
2. `OrderSettlement` platform-fee branch → settlement tests: own-stock order + verified
   subaccount → `{:split, mode: :platform_fee}`, merchant share `net` to subaccount,
   platform fee = remainder, `net + fee == total`, allocations summable to total; no
   subaccount → `{:no_split, :payout_unverified}`; `record_splits!` persists `:merchant` +
   `:platform` rows; existing dropship tests still green with the new `mode` key.
3. `checkout_live.split_mode/1` reads `mode` → the checkout still compiles; a payment
   created for a platform-fee order records `split_mode: :platform_fee`.
4. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new/changed
   files clean under `--warnings-as-errors`. PR.

## Verification
Automated as above. Manual (post-merge, real Paystack keys): a store with a verified
subaccount takes a normal order → Paystack routes `net` to the merchant's subaccount and
keeps `fee` in the platform main account; the `Payment` shows `split_mode: :platform_fee`
and two `PaymentSplit` rows.
