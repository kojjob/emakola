# Makola.io brand kit — canvas sources

These are the working files behind the brand-kit canvas. The published canvas is
generated from them; it is **not** committed (see `.gitignore`).

- `*.dc.html` — one file per artboard (logo, motion, emails, newsletter, social,
  print, stationery, pitch deck)
- `canvas.json` — page layout, artboard positions, sticky notes
- `cowrie-coin*.svg` — **the mark** (chosen 2026-08-28): full cut, `-small`
  (≤32px), `-appicon`, `-lockup`, `-mono`, `-mono-reverse`
- `canopy*.svg` — the previous mark (round 1, 2026-08-24). Still what the app
  ships (`priv/static/images/emakola-logo.svg` was built from
  `canopy-appicon.svg`) until the in-app swap PR lands
- `cowrie*.svg` (without `-coin`) — the round-1 runner-up drawing, kept on file
- `explorations-v2/` — the round-2 exploration canvas sources (its own README-free
  record; eleven directions, decided: 09 Cowrie Coin)
- `ai-*.jpg` — generated references that informed the marks, kept for provenance

## Re-seeding after an edit

```bash
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out makola-brand-kit.html --title "Makola.io Brand Kit" \
  --artboard Main.dc.html … --image ai-stall-a.jpg … --canvas canvas.json
```

## Rules baked into these templates

- **No fee percentage anywhere.** The advertised plan rates and what
  `OrderSettlement` charges do not agree yet.
- **No merchant counts.** Every real fact sits in `[BRACKETS]`; order and payout
  amounts are sample data.
- **Picture first.** A 72px pictogram opens every email, the amount is the
  largest thing on the page, and copy stays under eight words where it can.
