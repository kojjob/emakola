# Admin metrics pages — canvas sources

Working files behind the "Makola Admin Pages" canvas
(https://claude.ai/code/artifact/63140d84-f5d7-480a-a96a-cfde13215a0f),
drawn 2026-09-01. The published canvas is generated from them and is not
committed.

- `Main.dc.html` — Partners (`/admin/settings/supply-network`) rebuilt as a hub
- `Mobile.dc.html` — the same hub at 390px
- `Delivery.dc.html` — Delivery Zones with the metrics the page lacked
- `Stores.dc.html` — Platform Stores with merchant and activity metrics
- `Team.dc.html` — Platform Team with roster filters and presence
- `canvas.json` — layout and the sticky notes that record every data-source decision

Photos are `../stores-variations/shop-eggs.jpg`, `shop-fruit.jpg` and
`../supplier-handover/product.jpg`, standing in for supplier photos.

## Re-seeding after an edit

```bash
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out makola-admin-pages.html --title "Makola Admin Pages" \
  --artboard Main.dc.html --artboard Mobile.dc.html --artboard Delivery.dc.html \
  --artboard Stores.dc.html --artboard Team.dc.html \
  --image ../stores-variations/shop-eggs.jpg --image ../stores-variations/shop-fruit.jpg \
  --image ../supplier-handover/product.jpg --canvas canvas.json
```

## Rules baked into these artboards

- Every number has a source in the codebase (the notes name it); all values are samples.
- No on-time or delivery-days metric: Orders carry no `delivered_at` / `shipped_at`.
- Merchant pages lead with pictures and digits; labels stay under eight words.
