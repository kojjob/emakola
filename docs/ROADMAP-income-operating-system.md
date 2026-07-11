# Makola Earn — Income Operating System Roadmap

## Product thesis

Makola Earn should turn an income goal into an explainable sequence of legitimate product-sales actions. It must never promise income, reward recruitment, hide fees, invent product claims, or extend unlicensed credit.

## Existing rails to reuse

| Capability | Existing implementation | Decision |
|---|---|---|
| Shared supply | `SupplierOffer`, `SupplyConnection` | Extend; do not create another marketplace |
| Zero-capital listing | `ResellerListing` and `ListingImporter` | Reuse as the publication engine |
| Sales content and links | `SalesSharing`, `SalesShare`, UTM capture | Reuse as the campaign distribution layer |
| Conversion attribution | `SalesShareConversion` | Reuse for goal progress |
| Fulfillment | Cross-store fulfillment and delivery OTP | Reuse for successful-income measurement |
| Earnings | Payment splits and refund recovery | Reuse as the financial ledger |
| AI | Provider abstraction, prompts, usage limits, AI pricing | Reuse only for optional copy and explanations |
| Campaign UI | Admin campaign screen containing sample data | Replace progressively with persisted Earn plans |

## Non-negotiable safety rules

- Income projections are scenarios, never guarantees.
- Recommendations expose price, supplier net, fees, estimated reseller earnings, and the assumptions used.
- Generated content is grounded in approved supplier facts and remains a merchant-reviewed draft.
- No rewards for recruiting resellers, downlines, or deposits from participants.
- Reputation records observable commerce outcomes and supports correction/appeal.
- Credit is enabled only through a licensed financial or supplier-trade-credit partner; Makola does not silently become a lender.
- Customer deposits for group buys and preorders require explicit refund deadlines and a compliant payment design before launch.
- Dynamic pricing is bounded by supplier terms and anti-gouging controls.

## Delivery phases

### Phase A — Hustle Autopilot ✅

- [x] Persist a merchant income goal, timeframe, preferred channels, and daily time budget.
- [x] Produce a deterministic seven-day action plan and measurable sales target with a prominent non-guarantee disclosure.
- [x] Recommend eligible Earn listings using transparent economics and historical signals.
- [x] Create Sales Kits through the existing tracked-share service.
- [x] Track published, shared, clicked, ordered, fulfilled, refunded, and net-earned progress.
- [x] Give rule-based next-best actions; AI may rewrite copy but cannot change economics.
- [x] Add the goal form, recommendations, plan, and progress to the Earn Network UI.
  - [x] Goal form, economics-based recommendation input, and seven-day plan UI.
  - [x] Fulfilled net-earnings progress and next-action controls.

Acceptance: a reseller can create a goal, understand the assumptions, publish recommended products, share tracked links, and see fulfilled net earnings against the goal.

### Phase B — Voice-first Business-in-a-Box ✅

- [x] Create a starter storefront/catalog from a goal and niche.
- [x] Accept text and voice instructions, with confirmation before mutations.
- [x] Add locale-aware copy and translation with merchant review.
- [x] Generate fact-grounded product copy, images, short-video scripts, FAQs, and channel variants.
  - [x] Persist immutable supplier-fact snapshots and hashes for every content draft.
  - [x] Generate safe WhatsApp, Facebook, short-video, and FAQ drafts without requiring AI.
  - [x] Require explicit merchant approval/rejection and invalidate stale supplier facts.
  - [x] Add escaped SVG social-card generation grounded in supplier images/title/price and
        curated English/Twi rewriting that never translates unsupported free-form claims.
  - [x] Convert browser speech to editable instructions, parse a bounded command set,
        preview the exact action, and require confirmation before catalog/content mutations.
  - [x] Build a bounded niche starter catalog on the merchant's branded storefront with
        imported products, tracked Sales Kits, and reviewable fact-grounded drafts.

Acceptance: a new merchant can reach a reviewable storefront and first Sales Kit in under ten minutes without purchasing inventory.

### Phase C — Opportunity Radar and Ethical Pricing (build complete)

- [x] Aggregate privacy-safe search, view, share, stock, conversion, refund, and regional demand signals.
- [x] Explain why an opportunity is recommended and show data freshness/confidence.
- [x] Recommend bounded prices optimized for sustainable conversion, never scarcity exploitation.
- [x] Alert suppliers to unmet demand without exposing individual customer behavior.
- [ ] Complete the live controlled evaluation proving the radar beats a popularity-only baseline
      in fulfilled sales without increasing refunds or complaints.

Acceptance: recommendations beat a popularity-only baseline in fulfilled sales without increasing refund or complaint rates.

### Phase D — Collaborative Commerce

- [x] Threshold-based group-buy campaigns with clear deadlines and automatic refunds.
  - [x] Persist variant-specific thresholds, locked prices, payment commitments, campaign deadlines,
        refund deadlines, and transactional paid-quantity funding.
  - [x] Add merchant/customer UI and automatic gateway refund execution when a threshold is missed.
    - [x] Merchant creation/status UI with locked price, threshold, deadline, and refund-by date.
    - [x] Customer commitment/payment UI with authenticated, capacity-reserving quantities,
          gateway-linked payments, complete economics, and webhook-driven funding.
    - [x] Automatically cancel expired under-threshold campaigns every five minutes, claim each
          paid commitment once, execute the configured gateway refund, and persist retry/failure state.
- [x] Consent-based sales teams with declared roles and fixed transaction splits.
  - [x] Persist flat roles, immutable basis-point shares totaling exactly 100%, personal consent,
        and exact last-pesewa allocation.
  - [x] Attach consented team allocations to eligible attributed order settlement and merchant UI.
    - [x] Merchant team creation, invitation, declared-role/split display, and personal acceptance UI.
    - [x] Capture UUID-safe team links, disclose exact economics at checkout, and persist
          idempotent member allocations from merchant proceeds with proportional refund reversals.
- [x] Supplier-authored micro-franchise packages: training, brand rules, permissions, territory, and commission.
  - [x] Persist supplier-owned packages, connected-reseller discovery, explicit terms acceptance,
        supplier approval, training, rules, territory, channels, and commission.
  - [x] Add supplier/reseller package management UI and approved-package catalog activation.
    - [x] Supplier package authoring/publishing and connected-reseller discovery/application UI.
    - [x] Supplier-only approval UI with atomic activation of every package offer through the
          existing listing importer and persisted activation evidence on the enrollment.
- [x] No recruitment compensation or inherited/downline relationships.

Acceptance: every participant and customer sees the complete economics before committing, and totals reconcile exactly with payment splits.

### Phase E — Trust, Progression, and Partner Credit

- [x] Portable commerce passport based on fulfilled orders, service quality, refunds/disputes,
      and verified supplier training.
- [x] Evidence, reason codes, expiry, correction, and appeal for every reputation signal.
- [ ] Opportunity tiers and reserved inventory based on transparent eligibility.
- [ ] Licensed-partner or explicit supplier trade credit, repaid from sales only with informed consent.

Acceptance: merchants can inspect and challenge their passport; credit decisions are explainable and compliant.

### Phase F — Trust-protected Preorders

- Supplier milestone plans, delivery windows, minimum demand, and customer disclosures.
- Protected deposits only after legal/payment-provider approval of the funds flow.
- Automatic cancellation/refund rules and supplier performance consequences.

Acceptance: preorder funds, deadlines, milestones, refunds, and earnings reconcile end to end under failure simulations.

## North-star and guardrail metrics

North-star: zero-capital resellers with at least one successfully fulfilled sale per week.

Guardrails:

- fulfilled-order rate and median fulfillment time
- refund, dispute, and cancellation rate
- median realized earnings versus displayed estimate
- percentage of recommendations with a viewed explanation
- content-claim rejection/correction rate
- merchant opt-out and reputation appeal outcomes
- concentration of recommendations across suppliers and regions

## Implementation order

1. Income goals and deterministic plan engine. **Implemented and focused tests passing.**
2. Goal dashboard integrated into the existing Earn Network screen. **Implemented and focused tests passing.**
3. Goal progress from existing Sales Shares, conversions, fulfillments, and splits. **Implemented and focused tests passing.**
4. Fact-grounded content drafts and multilingual/voice input. **Implemented and focused tests passing.**
5. Opportunity signal warehouse and recommendation evaluation. **Warehouse/UI implemented;
   live controlled evaluation remains a rollout gate.**
6. Group buys, teams, and micro-franchise packages. **Next active slice.**
7. Commerce passport and partner-credit interfaces.
8. Preorders after payments/legal approval.

Each item ships as a small stacked pull request with migration, authorization boundary, tests, operational metrics, and rollback notes.
