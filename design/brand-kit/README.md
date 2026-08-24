# Makola.io brand kit — canvas sources

These are the working files behind the brand-kit canvas. The published canvas is
generated from them; it is **not** committed (see `.gitignore`).

- `*.dc.html` — one file per artboard (logo, motion, emails, newsletter, social, print)
- `canvas.json` — page layout, artboard positions, sticky notes
- `canopy*.svg` — the shipped mark. `canopy-appicon.svg` is what
  `priv/static/images/emakola-logo.svg` was built from
- `cowrie*.svg` — the runner-up direction, kept on file
- `ai-*.jpg` — generated references that informed the mark, kept for provenance

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
