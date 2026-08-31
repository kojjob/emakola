# Browse suppliers — catalog grid redesign

Canvas: https://claude.ai/code/artifact/241185dd-79cd-427f-a67f-2dbfe8ebc5ec

Static mockups for `/admin/supply/catalog`
(`EmakolaWeb.Admin.SupplyCatalogLive.Index`). Extends the vocabulary settled on
the offer page — see `design/supply-catalog-offer/` — with the same tokens
(emerald #059669, #0F172A on #F8FAFC, 16px card / 12px control radii, system
stack) and the same glyph family.

- `Main.dc.html`       — the grid, four cards covering four states
- `OptionRows.dc.html` — the alternative: one row per offer, columns aligned
- `Mobile.dc.html`     — 390px phone
- `canvas.json`        — layout and the notes beside each artboard

## What the redesign changes

The shipped grid shows a photo, a title, a supplier, `suggested retail`, a
dispatch line and three grey area chips. It never shows the margin — the number
a reseller is actually deciding on — so the only way to compare two suppliers is
to open both. It also has no stock signal, and `index.ex:137` renders a bare
`aspect-[4/3] bg-slate-100`, so an offer with no photo is an empty grey block.

- Every card answers the same three questions in the same order: what is it,
  what does it sell for, what do I keep.
- A connected merchant reads their margin on the card. An unconnected one gets
  the lock chip — "Connect to see your price" — rather than silence.
- Stock moves onto the card, so a dead offer stops looking alive.
- The three identical area chips collapse to one line: cheapest area, its price,
  and a count.
- No photo means the product glyph, the same slot rule as the offer page.

## The margin is free to show

`Offers.discoverable_offers/1` already loads `offer_variants: :source_variant`
in full (`offers.ex:227`), so `supplier_price` is in memory on this page
already. "The index never renders wholesale numbers" (the moduledoc) is a
RENDERING rule, not a data guarantee — showing the margin costs no new query and
no schema change, and it renders only where `connected?` is true, the same
server-side flag the offer page gates on.

## Open decisions

- **The two filters are a product decision.** "My suppliers" and "In stock" are
  new; they are the two cuts a merchant hunting stock actually wants, but they
  are scope beyond a visual pass.
- **Grid or rows.** The grid is what I would ship — the catalogue is small and
  the photo is how a merchant who reads slowly recognises a product. Rows start
  paying at roughly twenty offers.

`GH₵ 22` on the tote is the real seeded figure; `GH₵ 34` on the basket is a
sample.
