# Recording a cash susu installment — where the fee actually lands

Written to unblock QR Phase 2b (scan a susu code, record a cash installment).
Phase 2b was deferred pending "the fee decision". Reading the code changes what
that decision is.

## Correction to the earlier framing

Phase 2b was described — in the QR plan and in PR #450 — as risking a **fee
leak**: "a cash chunk never touches Makola, so naively crediting
`contributed_amount` completes the order with zero platform fee on that
portion."

That is wrong. The fee is not taken per chunk.

`Emakola.Orders.SusuChunks` contains no fee logic at all. The platform's cut is
computed once, at completion, in `Emakola.Orders.SusuCompletion`
(`susu_completion.ex:183`):

```elixir
total_fee = PlatformFee.calculate(plan.total_amount, plan.fee_rate_bps).fee
```

It is a cut of **the whole plan total**, not of individual contributions. It is
then apportioned across the counted contributions — `Payment` records carrying
`metadata["susu_counted"] == true` — and withheld from each one's payable:

```elixir
%{payment: payment, fee: fee, payable: payment.amount - fee}
```

So the platform's revenue is a function of `plan.total_amount`, which a cash
installment does not change. **There is no leak.**

## What actually breaks

`assert_invariants!` (`susu_completion.ex:223`) raises when the per-contribution
fees do not sum to `total_fee`:

```elixir
unless sum_fees == total_fee do
  raise "susu completion fee apportionment mismatch ..."
end
```

If cash installments do not create `Payment` records, they are absent from
`contributions`, but `total_fee` is still computed on the full plan total. The
same fee must now be absorbed by a smaller set of payments, each capped at its
own headroom (`amount_i - fee_i`). When the online contributions cannot absorb
the whole fee, `distribute_backward/2` runs out of room, `sum_fees < total_fee`,
and **completion raises**.

The threshold is generous. Completion survives while:

```
Σ(online contributions) ≥ total_fee
```

At the default 200 bps (2%), that means cash may be up to ~98% of the plan total
before completion breaks. A mixed plan is fine; an almost-entirely-cash plan
crashes at the moment it completes — the worst possible time, since the buyer
has already paid in full.

Worth being precise about who bears the fee in the surviving case: the platform
still receives its full cut of the plan, withheld entirely from the online
chunks. The merchant is not overcharged — they are holding the cash — so the
arithmetic comes out right. Example, plan 1000 at 2%:

| | Cash | Online | Platform fee | Merchant nets |
|---|---|---|---|---|
| All online | 0 | 1000 | 20 | 980 |
| Mixed | 900 | 100 | 20 (all from the 100) | 900 + 80 = 980 |
| Near-all cash | 990 | 10 | 20 — **cannot fit in 10** | **raises** |

## The two designs, and what each costs

### A. Cash chunks create no `Payment` record

Credit `contributed_amount` directly and mark the plan progressed.

- Simplest to build.
- Economics correct for mixed plans.
- **Crashes on near-all-cash plans** unless guarded.
- Loses the audit trail: nothing records that money changed hands, who recorded
  it, or when. For a rail that already treats settlement integrity as
  load-bearing, that is the more serious cost.

### B. Cash chunks create a `Payment` with a cash gateway

A real record, `susu_counted`, apportioned like any other.

- Keeps the audit trail and reuses the whole existing path.
- The apportioned fee is withheld from a payment whose money the platform never
  held, so the fee on that portion is **recorded but not collectible** — it has
  to be netted from the merchant's next payout, which is a payout-engine change,
  not a susu change.
- No crash: every contribution is present, so headroom exists by construction.

### C. Refuse cash chunks above a threshold

Ship A or B, and cap cash at the level where the invariant still holds.

- A guard, not a design. Useful alongside either.

## Recommendation

**B, with the fee recorded as owed.** It preserves the audit trail, removes the
crash by construction, and puts the shortfall where the platform already has
machinery for balances owed. A is cheaper today and more expensive later,
because retro-fitting an audit trail onto money that has already moved is not
something this codebase should take on.

Whichever is chosen, the near-all-cash case needs a test that reaches
`SusuCompletion` — the failure is a raise at completion time, not a wrong number,
so it will not show up in any arithmetic assertion.

## What this does not decide

Whether merchants *should* be able to record cash against a susu plan at all is a
product question, not a settlement one. This note only establishes that the
blocker is an invariant and an audit-trail choice — not a revenue leak.
