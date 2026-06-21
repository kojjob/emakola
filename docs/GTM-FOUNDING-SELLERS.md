# Makola — Founding Sellers Playbook (first 10–20 merchants)

> Created 2026-06-20. The demand-side companion to [`REVENUE-FIRST-90-DAY-PLAN.md`](REVENUE-FIRST-90-DAY-PLAN.md).
> Goal: land your first paying sellers **remotely, part-time**, and get to a real customer order.
> This needs **no new code and no Paystack decision** — you can start today.

## Honesty guardrail (read first)

Promise only what's live: **a professional storefront + MoMo/card checkout + order alerts + order tracking, free to set up, no monthly fee.** Do **not** promise buyer "escrow / protected orders" to sellers yet — that engine is half-wired. Use the trust angle as *"your customers get a proper checkout and tracking instead of DM screenshots,"* not a guarantee you can't yet honor.

---

## 1. The Founding Seller offer (cap it at 20)

> **Founding Seller program — free setup, no monthly fee, lock in the lowest rate forever.**

- **I set up your online shop for you** — just send product photos + prices. Live in a day at `yourshop.makola.io`.
- **Customers pick items and pay you by MoMo or card in one tap** — no more "send to this number" + screenshots + "have you paid?".
- **You get an alert for every order** (WhatsApp/SMS) and can see what's pending, paid, and delivered.
- **Cash-on-delivery is built in** for customers who don't want to pay online.
- **No monthly fee. You keep ~98% of every sale** (a small ~2% covers payment + platform). You only pay when you actually sell.
- **Founding sellers lock in the lowest fee forever** and help shape the product.
- **No lock-in** — your customers and data are yours, export anytime. If it's not helping you sell, walk away.

Why this converts: zero upfront cost, zero commitment, you do the work, and the ask ("can I set one up for you free?") is a soft yes.

---

## 2. Where to find the first 20 (remote sourcing)

**Instagram** — search hashtags + location tags:
`#accrafashion #madeinghana #ghanafashion #accrathrift #kantamanto #okrika #ghanasmallbusiness #kumasibusiness #accrabaker #ghanahair #ghanacosmetics` — plus location tags: Accra, Osu, East Legon, Oxford Street, Makola Market, Kumasi.

**TikTok** — same terms + "GH"; look for sellers doing product videos with *"DM to order"* / *"link in bio"*.

**Signals of a great fit:**
- Posts a few times/week, clear product photos, prices shown (or "DM for price").
- Evidence of real orders: "sold out", "restocked", reposted customer photos, comments asking *"price?" / "how much?" / "is it available?"*.
- Takes payment by **MoMo**; coordinates orders in **DMs/WhatsApp** (← this is the pain you remove).
- A reachable owner (WhatsApp/contact in bio, often a Linktree).

**Skip:** dormant accounts, big brands (already on Shopify), drop-only resellers with no real inventory.

**Niches to start (pick 1–2):** women-led **fashion, thrift (okrika/Kantamanto), beauty/cosmetics/hair, baked goods/food, accessories.**

---

## 3. Outreach DMs (copy-paste, then personalize the first line)

**A — Instagram cold DM (default):**
> Hi [Name] 👋 Love what you're doing with [shop] — [specific product] caught my eye. Quick question: are you still taking orders through DMs and MoMo screenshots? I'm building a free tool for Ghanaian sellers that gives you a proper checkout link — your customers pick what they want and pay you by MoMo or card in one tap, and you get an alert for every order. I'm setting it up **free** for a small group of founding sellers (no monthly fee, you keep ~98% per sale). Can I set one up for you this week — no commitment? Would value your feedback either way 🙏

**B — WhatsApp follow-up (after they reply / from bio number):**
> Thanks [Name]! 🙌 Easiest way: send me **5–10 product photos with prices** and I'll build your shop today — you'll get a link to share in your bio and posts. Takes you 5 minutes, I do the rest. Want to try it?

**C — Ghanaian-English / light pidgin (for rapport, use judgment):**
> Hi [Name], your [shop] dey nice 🔥 I dey build something free for sellers for Ghana — make your customers fit order and pay you by MoMo one-time, no more "send am make I check". I go set yours up free, you no go pay any monthly. Make I do one for you make you try?

**D — Referral ask (after a seller is happy):**
> So glad it's working for you 🙏 I'm onboarding a few more founding sellers this month — is there one seller friend you'd recommend I set up free too?

Tips: personalize the **first sentence** (real shop/product), keep it short, one clear ask, reply within minutes when they respond.

---

## 4. Funnel math (fits limited hours)

- Good personalized DM → ~**10–20% reply**, of which ~**50% convert** to a live store.
- So **~100–150 well-targeted DMs → ~10–15 founding sellers.**
- Pace **10–15 DMs/day** over 2 weeks. ~30–45 min/day. That's the whole part-time ask.

---

## 5. Objection handling

| They say | You say |
|---|---|
| "Is it really free?" | Setup's free, no monthly fee. Small ~2% only when you make a sale. |
| "I already sell on IG/WhatsApp." | Keep them! This just adds a checkout link so you stop losing orders and chasing MoMo. Your IG stays your shopfront. |
| "Why should I trust you with my customers?" | They stay *your* customers — you can export everything anytime, no lock-in. I set it up free; you risk nothing. |
| "My customers won't pay online." | MoMo is one tap, and cash-on-delivery is built in for the rest. |
| "I don't have time." | I do the setup — send photos + prices, your shop's live tomorrow. |

---

## 6. Two-week action checklist

**Week 1**
- [ ] Build a target list of 60–80 sellers (sheet: handle, niche, why-fit, contact).
- [ ] Send 10–15 personalized DMs/day (template A).
- [ ] For each "yes": collect photos + prices → build their store → send the live link + a 60-sec screen-recording tour.
- [ ] Start a **"Makola Founding Sellers"** WhatsApp group for onboarded sellers.

**Week 2**
- [ ] Keep outreach at 10–15/day.
- [ ] Help sellers share their link in bio + a launch post; aim for each to get a first real order.
- [ ] Ask every happy seller for **1 referral** (template D).

**Success metric for the fortnight:** ≥1 seller takes a **real customer order** through their Makola store. That single event flips Makola from "unvalidated" to "people use it."

---

## 7. What this unlocks for the code side

The moment a seller wants to *get paid through Makola* (not just take orders), you'll have the concrete answer to the Paystack MoMo-subaccount question from a real merchant's account — which is exactly the input the fee-routing build (`PlatformFee` is already done; `OrderSettlement` wiring + SP1 payout UI remain) is waiting on. **Demand first, then the rails follow the real requirement.**
