# Makola — Revenue-First 90-Day Plan

> Created 2026-06-20 from a founder/investor strategy session.
> **This doc sequences existing plans for one goal — first real revenue in 90 days — given real constraints. It does not replace the strategy library; it prioritizes it.**
>
> Read alongside: [`BUSINESS_MODEL.md`](BUSINESS_MODEL.md) · [`SOCIAL_COMMERCE.md`](SOCIAL_COMMERCE.md) · [`ACTION_ROADMAP.md`](ACTION_ROADMAP.md) · [`ROADMAP-dropshipping.md`](ROADMAP-dropshipping.md)
>
> ---
> **📌 Status update (2026-06-24): Phase 0 build is COMPLETE — and overshot.** The revenue
> rails are all merged to `main`: subaccount creation (#206), the 2% platform fee on normal
> orders with a graceful no-split fallback (#207), the finance oversight page (#208), the
> payout-execution engine (#210/#211), payout operations — history/retry/notify (#212), and a
> UI fix (#213). The ops blocker below is **resolved**. We also delivered *Phase 2*-level
> capability early (paying merchants out, a "your sales" finance view). **Engineering is no
> longer the constraint** — the remaining critical path is **activation** (real provider keys →
> `LAUNCH_TODO.md`) and **go-to-market** (offer, niches, recruit sellers). The only
> revenue-moving build left in the near sequence is the **Smart Link / link-in-bio store page**
> (Phase 1/2, `SOCIAL_COMMERCE.md`).

## The situation (be honest)

| | State |
|---|---|
| Product | **Over-built relative to demand.** Onboarding, catalog, cart, checkout, Paystack MoMo+card, orders, outbound WhatsApp/SMS all production-ready. 53 Ash resources, ~1,900 tests, 11 themes. |
| Merchants | **Zero.** Production DB empty. |
| Can charge merchants? | **Not yet** — billing models exist but `Store` isn't linked to a subscription, and normal orders take no platform fee. |
| Founder | Diaspora / fully remote · side project / limited hours · wants **first revenue in 90 days**. |

**Implication:** risk has been retired on the supply side (code) where it was comfortable, not on the demand side where it's highest. The next 90 days add **no new product surface** — they prove that a reachable seller will adopt Makola *and* that money flows through it.

## What's already decided in our own docs (and still right)

- **Segment** — `BUSINESS_MODEL.md` GTM Phase 1 already = *"merchants already selling on Instagram/WhatsApp… Turn your Instagram shop into a real store in 10 minutes."* Keep this. It is the only segment a remote, part-time founder can reach (DMs, ads, content) and serve (smartphone-native, async support).
- **Transaction fee** — `BUSINESS_MODEL.md` already prices a per-sale fee (3.5% Free → 1.5% Pro). Keep this as the revenue mechanism.
- **Social distribution** — `SOCIAL_COMMERCE.md` already specifies the **Smart Link / link-in-bio page** (`makola.io/@store`) and shareable product links. This is the right growth surface.

## The two refinements this plan adds

1. **Lead with the transaction fee; defer the subscription.** `BUSINESS_MODEL.md` is written subscription-first (GH₵49/149/mo up front). For an unproven product, Ghanaian micro-merchants are subscription-averse — a small cut of a sale they'd otherwise fumble is an easy "yes"; a monthly charge is a hard "no". Subscriptions return later as the **"pay monthly to lower your fee"** upgrade (Shopify model), which is exactly what `lib/emakola/billing/` is shaped for.
2. **The monetization unlock is SP1, not new fee code.** Per `ACTION_ROADMAP.md`, the dropship split is **already wired into `CheckoutLive` + `PaystackWebhookHandler`**. On a *normal* (non-dropship) order, no split is sent, so **100% of the charge already lands in the platform's main Paystack account** (`order_settlement.ex`: *"the platform's cut… stays in the main account"*). To pay merchants their share minus a fee, finish **SP1: merchant payout-onboarding UI** (`StorePayoutAccount` + `create_subaccount/1` exist) and route **retail − fee** to the merchant subaccount, keeping the fee as the split remainder.

## ⚠️ One ops blocker to clear before building the split-based fee

> ✅ **RESOLVED (2026-06-24).** Paystack Ghana **does** support MoMo as a subaccount
> settlement destination (List Banks returns MTN / VOD / AirtelTigo, type `mobile_money`,
> GHS) and **does** support Transfers to MoMo wallets — so the split-remainder fee model and
> automated payouts both work directly. SP1 + the fee + the payout engine were built on this
> basis. The fallback below was not needed.

`ACTION_ROADMAP.md` already flags it: **"verify Paystack Ghana MoMo-as-subaccount support"** and **"Paystack fee bearer."**
- If Paystack Ghana **can** pay MoMo subaccounts → the split-remainder fee model works directly (merchant gets a verified subaccount in SP1).
- If it **cannot** → fall back to: platform holds funds in main account, deducts the fee, and pays merchants out on a schedule (manual/Oban) using the existing `SupplierLedgerEntry`-style ledger pattern.

**Action (founder, this week): confirm Paystack Ghana subaccount + MoMo payout support.** This decides SP1's design.

## The 90-day sequence

### Phase 0 — Revenue rails (Weeks 0–2) — ✅ BUILD COMPLETE (2026-06-24)
- ✅ **Decided:** fee % = **2%** (`platform_fee_rate_bps: 200`). ⏳ cohort offer wording is a founder/marketing task.
- ✅ **Built (TDD):** SP1 merchant payout-onboarding UI; subaccount creation (#206); **platform fee on normal orders** via split-remainder with a **graceful no-split fallback** (#207). Plus, ahead of schedule: payout-execution engine (#210/#211), payout operations (#212), finance oversight page (#208).
- ⏳ **Pick (founder):** the 1–2 launch niches + target seller list — still open.
- **Success metric:** ✅ proven in automated tests (fee routes; checkout safe on the no-split path). ⏳ the *real* end-to-end test order is gated on **activation** (real Paystack keys — `LAUNCH_TODO.md` steps 2/6/8), and requires the merchant to have a **verified subaccount first** (onboard payout → `SubaccountCreationWorker` succeeds → then the fee splits).

### Phase 1 — First merchants + first GMV (Weeks 2–8)
- Hand-recruit + white-glove-onboard **10–20 social sellers** (cap it — limited hours). Run them in one WhatsApp support group.
- Add a **shareable WhatsApp checkout link** (subset of the `SOCIAL_COMMERCE.md` Smart Link) if it unblocks sales.
- **Success metric:** **first cedi of platform revenue**; # sellers with ≥1 real sale/week; total GMV.

### Phase 2 — Repeatability (Weeks 8–16)
- Link-in-bio store page, referral loop, "your sales this week" view, escrow / "protected order" badge for the diaspora lane.
- **Success metric:** weekly transacting sellers (retention); seller-referral rate; rough CAC per onboarded seller.

### Later (post-revenue, do NOT pull forward)
Subscription "pay to lower your fee" tiers · SMS/WhatsApp credit bundles · full social-catalog sync · dropship supplier network · Flutter app · custom domains · Nigeria. All real; all premature until revenue exists.

## Kill / pivot signal

If, after genuine effort, you cannot get ~5 sellers taking real orders, the constraint is **demand or reach**, not code — fix the segment / offer / a commission-only local growth agent. **Do not respond by building more product.**

## Avoid list

More features · finishing subscription billing now · the mobile app · the marketplace · market-trader segment · any work that doesn't move toward first revenue.
