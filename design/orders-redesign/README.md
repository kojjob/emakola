# Orders — three directions

`/admin/orders` for merchants who do not read well: the product photo says
what was bought, an icon says where the order is, the wallet's own colour
says how it was paid, WhatsApp is one tap away, and the money is the largest
thing on the row. Three directions, each at phone width and in the desktop
content area.

- `Main.dc.html`, `WorkDesktop.dc.html` — A · Do these now: waiting orders as big cards, the rest a quiet picture list
- `RowsPhone.dc.html`, `RowsDesktop.dc.html` — B · Picture rows: today's list, every row learns to speak
- `BoardPhone.dc.html`, `BoardDesktop.dc.html` — C · The board: Waiting / Packing / On the way / Done as columns
- `build.mjs` — generates every artboard and `canvas.json`; edit this, not the `.dc.html`
- `*.jpg` — crops of `design/stores-variations` (real trader photography), shared with `design/add-products`

Rebuild and re-seed after an edit (see the /design skill for the seeder path):

```bash
node build.mjs
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out orders-redesign.html --title "Orders Redesign" \
  --artboard Main.dc.html --artboard WorkDesktop.dc.html \
  --artboard RowsPhone.dc.html --artboard RowsDesktop.dc.html \
  --artboard BoardPhone.dc.html --artboard BoardDesktop.dc.html \
  --image eggs.jpg --image melon.jpg --image citrus.jpg \
  --image braids.jpg --image sewing.jpg --image makeup.jpg --canvas canvas.json
```

## What these are matched to

- The live page (`OrderLive.Index` after the Sell redesign #437 and the
  polish pass): `admin_page_header` with the 56px emerald badge, Scan a
  parcel, four `stat_card` tiles (info / warning / success tones),
  `filter_tabs` (segmented, dark active pill with count), the search box,
  16px-radius list card, rows at 12px / 20px padding, the amber inset edge
  and Send it on a waiting order.
- Tokens from `assets/css/app.css` `@theme`; Inter; emerald `#059669`.
- Status vocabulary (one icon, one tint, the same on tabs, pills and
  columns): Waiting = amber clock, Packing = blue box, On the way = violet
  truck, Done = emerald check. Maps onto the resource's
  pending / confirmed+processing / shipped / delivered.
- Payment rails as brand-colour chips, the admin canvas's locked rule:
  MTN `#FFC107`, Telecel `#E60000`, AT `#004F9F`, cash on delivery slate.
- Controls: 48px Send it on a card, 32px on a row; 44px scan button;
  WhatsApp disc 44 / 40 / 32. Copy under eight words. Sample orders only.
