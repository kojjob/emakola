# Checkout for non-readers — direction study

Canvas: https://claude.ai/code/artifact/8f5a8502-ea52-40ae-96f9-50de934b0811

Three directions for the storefront checkout, drawn for buyers who do not read
well. **"One Thing at a Time" was chosen** (2026-08-29); the other two are kept
on the canvas's second page for the record.

- `Main.dc.html`               — the chosen direction, desktop
- `Mobile.dc.html`             — the chosen direction, phone (390×844)
- `PictureFirst.dc.html`       — not chosen: words demoted to captions under pictures
- `PictureFirstMobile.dc.html` — not chosen, phone
- `AskLess.dc.html`            — not chosen: two fields, seller phones for the address
- `canvas.json`                — layout, pages and the notes beside each artboard
- `melon.jpg`, `citrus.jpg`    — cropped from `design/stores-variations/shop-fruit.jpg`

Re-seed after editing (see the /design skill for the seeder path):

```bash
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out checkout-for-non-readers.html --title "Checkout for Non-Readers" \
  --artboard Main.dc.html --artboard Mobile.dc.html --artboard PictureFirst.dc.html \
  --artboard PictureFirstMobile.dc.html --artboard AskLess.dc.html \
  --image melon.jpg --image citrus.jpg --canvas canvas.json
```

## What these are matched to

`/vibrant-demo/checkout` renders through `Emakola.Themes.DefaultRenderers.Checkout`,
not a Vibrant renderer — Vibrant only overrides `:home`, `:product_list` and
`:product_detail`. **Anything decided here lands on all 22 themes.**

Colour comes from the theme chip on each artboard, carrying the real primaries
from `lib/emakola/themes/*.ex`. `storefront.html.heex` publishes `--theme-primary`,
and `app.css` consumes it twice — as `--color-store-accent` and as
`--color-cta-dark` — so primary is the only theme colour this page can move.
Three shipping themes have primaries too light to use as a foreground (atelier
`#16A34A` 3.3:1, akwaaba `#F0531F` 3.5:1, starter `#6366F1` 4.5:1), so the
artboards derive a darkened shade rather than let bars and prices disappear.

Telco marks never follow the theme — MTN yellow, Telecel red, AirtelTigo blue
are the strongest recognition cue a non-reader has.

The delivery step uses the real fields from `AddressComponents.gh_address_fields`
(GhanaPost Digital Address and Landmark, both optional, with the live
placeholders and the "Helps the rider find you faster" hint).

## Constraints these mockups deliberately honour

- **Card entry must use the gateway's embedded fields.** The artboards show card
  details collected in the flow rather than today's external redirect
  (`CheckoutLive` line ~600 redirects to Paystack's `authorization_url`). Those
  inputs must be Paystack Inline / hosted fields — a raw PAN reaching a Makola
  input or assign moves the platform from PCI-DSS SAQ A to SAQ D.
- **Cash and card never borrow the mobile-money screen.** Each has its own
  picture, its own words and no USSD code, because no prompt is coming.
- **Buyer protection copy never promises more than the live string**, which is
  "payment held until you confirm delivery" and is gated on
  `Protection.applies?/2`. It sits behind a tweak here for the same reason.
- **No fake status bar or keyboard** on the phone artboards.

## Rejected on the merits — do not re-propose

- A USSD-styled confirmation screen imitating the MTN prompt. That is the screen
  where a buyer's PIN goes; teaching them a web page can look like it degrades
  the one signal protecting them.
- A "send this order to the seller on WhatsApp" escape hatch — a checkout that
  abandons payment into a DM, which is the behaviour the platform exists to move
  sellers off.

## Still open

- **Choosing a region without reading.** The chips carry a pin and the delivery
  price as digits, but "Ashanti" is still a word. Detecting from the phone
  number prefix is the obvious candidate.
- **The USSD codes need confirming** — MTN `*170#`, Telecel and AirtelTigo `*110#`.
- **Whether Landmark should outrank Address.** "Behind Achimota Melcom, blue
  gate" is how people here actually give directions; making it the required
  field instead would change `CheckoutService` validation.
- **"Save this card for later"** was left out: it needs card tokenisation and a
  stored-cards model, neither of which exists in the codebase.
