# Supply catalog — offer page redesign

Canvas: https://claude.ai/code/artifact/df67fe4b-0d6c-4018-8f03-3f35866873aa

Static mockups for `/admin/supply/catalog/:offer_id`
(`EmakolaWeb.Admin.SupplyCatalogLive.Show`), matched to the app's real tokens
(emerald #059669 / #047857 / #ECFDF5, #0F172A on #F8FAFC, #E2E8F0 borders,
16px card and 12px control radii, `shadow-sm`, system font stack) and to the
anatomy of `admin_card`, `stat_card` and `supplier_stock_badge`.

- `Main.dc.html`      — desktop, not connected (the state merchants meet first)
- `Connected.dc.html` — desktop, connected: prices open, action becomes "Add to my store"
- `Mobile.dc.html`    — 390px phone, not connected
- `Icons.dc.html`     — the sixteen glyphs and the identity-slot rule

- `canvas.json`       — pages, layout and the notes beside each artboard

## The direction, and what it cost

Four ways of showing the money were drawn and compared on 2026-08-31: these
stat TILES, a ledger (sells for, minus what you pay, rule, what you keep), a
split bar drawn to scale, and a dark "deal card" with one gold figure. Kojo
chose the tiles.

Tiles won on fitting the admin's own `stat_card` vocabulary — no new pattern to
defend, and the row survives a fourth number later. What it costs is that three
equal tiles make nothing loudest, so the margin tile carries the colour in the
connected state to compensate. The sketches are deleted; if that trade ever
stops paying, the split bar is the one to revisit — its open problem was thin
margins, where the green slice gets too narrow to hold its own label.

## What the redesign fixes

The shipped page gives half its width to an `aspect-square` image well that is
EMPTY whenever the supplier uploaded no photo — the common case, and the case
for this very offer. It also renders locked wholesale and margin cells as a 🔒
emoji, which renders differently on every device and reads as decoration
rather than as a state.

- Identity costs 96px: the product glyph when there is no photo, the supplier's
  photo when there is one.
- The three numbers a reseller decides on (retail, wholesale, margin) become a
  tile row. Locked values are drawn as covered bars, not emptied cells.
- The sentence explaining the lock becomes the page's one primary band, sitting
  directly under the numbers it opens. Same band, same place, in both states.
- Dispatch areas and supplier terms lead with the icon that identifies them,
  so the cards can be read without being read word by word.
- No emoji anywhere; every icon is inline SVG on one 24×24 / 1.8–2.0-stroke grid.

Labels are plain words — Sells for / You pay / You keep — with the trade term in
small grey underneath, for merchants who read slowly. That is a product decision
to confirm, not a fait accompli.

`GH₵ 38` wholesale, `GH₵ 22` margin and the `GH₵ 70` cap are SAMPLE values,
marked as such on the artboards themselves; the seeded offer only carries the
`GH₵ 60` retail. Everything else — the title, supplier, description, SKU, the
`GH₵ 10` Accra dispatch, 7-day returns and 6-month warranty — is the real row
from `emakola_dev`. `58%` is margin on cost, matching `margin_pct/1`.

Prices use `GH₵` (U+20B5), never `&cent;` (¢, U+00A2) — an earlier draft shipped
the wrong glyph on all 34 prices. `lib/emakola/money.ex` documents the house
format.

To change anything: edit these files, then re-seed and republish to the SAME url
(see the `/design` skill). The seeded `.html` is generated — never edit it.
