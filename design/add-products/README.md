# Add products — three directions

Canvas: https://claude.ai/code/artifact/7e9e8250-463c-4b25-bbaf-97e46dd1b2a4

Three ways to redesign `/admin/products/new` so that one product and thirty
products go through the same door, drawn for merchants who do not read well.
**Photo cards was chosen** (2026-09-02); the other two sit on the canvas's
"Not chosen" page for the record.

- `Main.dc.html`                   — Photo cards, the page itself: every photo is a card with name + price
- `CardsStart.dc.html`, `CardsDone.dc.html`, `CardsDesktop.dc.html` — its start, done and desktop frames
- `Today.dc.html`                  — not chosen page: the live page at phone width, full length
- `Step*.dc.html`                  — not chosen: B · One at a time, one question per screen
- `Say*.dc.html`                   — not chosen: C · Snap and say, the AI names it, you say the price
- `build.mjs`                      — generates every artboard and `canvas.json`; edit this, not the `.dc.html`
- `eggs.jpg` … `makeup.jpg`        — cropped from `design/stores-variations/*.jpg`; `melon`/`citrus` reused from `design/checkout-literacy`

Rebuild and re-seed after an edit (see the /design skill for the seeder path):

```bash
node build.mjs
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out add-products.html --title "Add Products Redesign" \
  --artboard Main.dc.html --artboard Today.dc.html --artboard CardsStart.dc.html \
  --artboard CardsDone.dc.html --artboard CardsDesktop.dc.html \
  --artboard StepName.dc.html --artboard StepPrice.dc.html --artboard StepReady.dc.html \
  --artboard StepDesktop.dc.html \
  --artboard SaySnap.dc.html --artboard SayFill.dc.html --artboard SayShelf.dc.html \
  --artboard SayDesktop.dc.html \
  --image eggs.jpg --image melon.jpg --image citrus.jpg --image braids.jpg \
  --image sewing.jpg --image makeup.jpg --canvas canvas.json
```

## What these are matched to

- Tokens from `assets/css/app.css` `@theme`: emerald `#059669` / `#047857`,
  soft `#ECFDF5`, slate borders `#E2E8F0`, text `#0F172A`, muted `#64748B`,
  12px control radius, 16px card radius, Inter on the admin shell.
- The phone frames draw the live `admin_topbar` (72px, white/80, hamburger,
  search, bell, avatar) and the live `/admin/products/new` header (back arrow,
  24px bold title, 14px subtitle). Desktop frames draw the content area at 1440
  with the `admin_page_header` icon badge, as `design/polish-pass` does.
- Control sizes for the literacy-first parts (54px fields, 56px CTA, 13px
  radius, 17px field type) are the ones `design/onboarding` already uses.
- Copy stays under eight words. Prices are sample values in `GH₵ 45` form
  (`Currency.format_price`).

## What already exists in the codebase

- `/admin/products/snap` reads a photo into a title, description, category and
  tags with Claude vision, gated on `EmakolaWeb.AiGate.enabled?()`.
- `/admin/products/bulk` is a photo-cards page (up to 30, name + price each,
  publish all) — direction A is that page with the camera in front and the
  states made visible.
- The CSV slide-over on the Products index (`BulkUploadModal`) stays the path
  for a merchant with a spreadsheet; the artboards keep it as a quiet button.
- No voice input: Kojo dropped the mic from the chosen direction (2026-09-02).
