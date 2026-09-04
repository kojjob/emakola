# Add products — one door

Consolidates the five ways into `/admin/products/new` (Take a photo, Choose
photos, Type it in, Upload a file, and Add by photo on the Products page)
into one page with one card model. Follows `design/add-products` (Photo
cards, chosen 2026-09-02, live since PR #595/#596). **Built 2026-09-04** on
branch `feature/add-products-one-door` (`ProductLive.AddProducts`); the
deviations are noted under "What moves where". The seeded canvas
(`add-products-one-door.html`) is generated, not committed.

- `Main.dc.html`        — the page while filling: one strip, one card per product
- `Start.dc.html`       — the page before any photo: one tile, Type it in, spreadsheet link
- `More.dc.html`        — a card with More opened (category chips, description, AI fill)
- `Done.dc.html`        — the done screen, unchanged from live
- `Desktop.dc.html`     — the content area at 1440
- `TodayMap.dc.html`, `OneDoorMap.dc.html` — the five doors today beside the one door
- `ShelfAlt.dc.html`    — low-fi alternate: no add page, the Products list takes photos
- `build.mjs`           — generates every artboard and `canvas.json`; edit this, not the `.dc.html`
- Images come from `../add-products/*.jpg` (crops of `design/stores-variations`)

Rebuild and re-seed after an edit (see the /design skill for the seeder path):

```bash
node build.mjs
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out add-products-one-door.html --title "Add Products One Door" \
  --artboard Main.dc.html --artboard Start.dc.html --artboard More.dc.html \
  --artboard Done.dc.html --artboard Desktop.dc.html \
  --artboard TodayMap.dc.html --artboard OneDoorMap.dc.html --artboard ShelfAlt.dc.html \
  --image ../add-products/eggs.jpg --image ../add-products/melon.jpg \
  --image ../add-products/citrus.jpg --image ../add-products/makeup.jpg \
  --image ../add-products/sewing.jpg --canvas canvas.json
```

## What these are matched to

- Tokens from `assets/css/app.css` `@theme` and the live admin shell: emerald
  `#059669` / `#047857`, soft `#ECFDF5`, slate borders `#E2E8F0`, text
  `#0F172A`, muted `#64748B`, Inter on the admin shell.
- Card, tile and control sizes are the ones the live page ships in
  `add_products_components.ex`: 54px fields and 56px CTA on a phone, 46px
  rows on a desktop, 13px field radius, 16px card radius, 200/170px photos,
  30px badges, the sticky publish bar.
- New pieces keep those sizes: the Gallery pill (40px), the More row (44px),
  category chips (42px / 36px), the Fill it in pill (34px), the amber
  "Makola wrote this" line (the edit page's existing copy).
- Copy stays under eight words. Prices are sample values.

## What moves where

- Camera + gallery: one tile, two hit areas (`capture="environment"` on the
  body input, none on the pill's input).
- Typed form (`/admin/products/new/form`): becomes a card without a photo on
  this page. Product type, SEO, digital files stay on the edit page. As
  built, the card's photo slot is static ("No photo yet"): one upload config
  cannot serve a per-card input, so a photo is added on the edit page.
- AI snap (`/admin/products/snap`): becomes the Fill it in pill, gated on
  `EmakolaWeb.AiGate.enabled?()` as before. There is no "Write it for me":
  a product published without a description already gets one from the
  backfill worker (PR #604/#605), which the field's placeholder now says.
- CSV: the existing `BulkUploadModal` slide-over. As built it still opens
  over the Products list (`/admin/products?upload=csv`), where the imported
  products then appear; the tap count is the same.
- Products page header: one button.
