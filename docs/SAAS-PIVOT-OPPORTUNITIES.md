# Makola — Adjacent SaaS Opportunities (Repurposing the Engine)

*Strategy memo, 2026-06-24. The premise: Makola isn't "an ecommerce app." It's a
**multi-tenant, mobile-money commerce-and-payouts engine for West Africa.** Ecommerce is
vertical #1. This memo maps the reusable core to other profitable verticals, ranked by how
much of the hard, defensible work they reuse.*

---

## What's actually reusable (the moat)

Ranked by how hard it was to build (≈ how hard for a competitor to copy):

1. **Split-at-source settlement** — collect via MoMo, auto-divide between multiple parties,
   keep a platform fee, all in one transaction. The crown jewel; almost nobody has this.
2. **MoMo collection + payout** (the payout-execution engine, in progress) — money *in* and
   *out*, to wallets and banks.
3. **Multi-tenancy + per-tenant branded subdomains** — spin up isolated, branded instances at
   scale.
4. **WhatsApp/SMS rails + phone/OTP & WhatsApp auth** — reach and identify users the way West
   Africa actually works (no email, no passwords).
5. **Compliance-grade admin** — KYC/verification, moderation, audit trail, finance oversight,
   impersonation.

A viable pivot reuses #1–#2. A *great* one reuses all five. Pure-SaaS pivots that touch no
money (a plain CMS, a bare booking calendar) under-use the moat and aren't worth it.

---

## The pivots, ranked by reuse + profit

### Lightest lift / highest reuse

- **Events & ticketing.** Events = products, tickets = variants; digital delivery already
  exists (QR via WhatsApp). The killer feature is **instant organizer payout minus a fee** —
  organizers hate waiting weeks for ticket money. High margin, inherently viral (every buyer
  sees your checkout), a near-reskin of catalog + checkout.

- **Invoicing / "get paid" for freelancers & SMEs.** Strip the catalog, keep the money engine:
  send a MoMo payment link over WhatsApp, get paid, auto-settle minus a fee. The *lightest
  possible* pivot, a proven model (Wave/FreshBooks) with no strong MoMo-native incumbent. Same
  transaction-fee monetization already chosen for ecommerce.

- **Donations / giving for churches, NGOs, fundraisers.** Churches and NGOs move enormous MoMo
  volume today with zero tooling (raw MoMo numbers). Give them a branded giving page
  (subdomain), WhatsApp receipts, instant payout, and a dashboard; take a small fee. Sticky,
  recurring, WA-perfect.

### Medium lift, deep reuse

- **Bookings / appointments** (salons, clinics, mechanics, tutors, event vendors). Order
  lifecycle → appointment lifecycle. MoMo deposits to cut no-shows, WhatsApp reminders (the #1
  pain for these businesses), split for marketplace versions. "Calendly + Square for West
  African services."

- **School-fees + parent comms.** Fees collection is a massive, painful, recurring MoMo use
  case. Per-school subdomain, installment plans, WhatsApp reminders to parents, payout to the
  school. Sticky and seasonal-recurring; hard to churn once fees flow through you.

- **Rentals / classifieds** (short-lets, cars, equipment). Listings = catalog, deposits held
  by platform + payout to owner, KYC/verification, WhatsApp. Property short-lets are booming in
  Accra/Lagos.

### The biggest swing (the split engine is the unlock)

- **Marketplace-in-a-box / any multi-party vertical** — food delivery (restaurant + rider +
  platform), logistics/errands, agritech (farmer + aggregator + platform), B2B wholesale.
  Anywhere money must be divided between 3+ parties at the moment of sale, the trustless split
  is a genuine ~12-month head start over competitors.

---

## Recommendation

The two sharpest for *us* specifically — because they monetize identically to the current
transaction-fee model and reach overlapping customers (IG/WhatsApp sellers, per the
revenue-first strategy):

1. **Invoicing / payment links** — lightest lift, fastest demand validation, same fee model.
2. **Events/ticketing or church-giving** — "collect-and-instantly-payout" plays that are pure
   showcases for the payout engine.

## The connective insight

Every pivot above depends on **freely sending money out** — the payout-execution engine
currently in progress. Right now the system can *collect and split* but not freely
*disburse*. Finishing payout execution doesn't just close the ecommerce loop; it converts the
codebase from "an ecommerce app" into "a MoMo money-movement platform with N possible
front-ends." That makes it the highest-leverage item on the roadmap.

*Not a commitment to build any of these — a map of where the engine could go. Each would get
its own brainstorm → spec → plan cycle if pursued.*
