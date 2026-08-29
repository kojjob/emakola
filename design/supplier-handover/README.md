# Supplier Handover — UX prototypes

Canvas: https://claude.ai/code/artifact/6dfcde5b-c5fe-4738-981c-b59c89d06fe8

Clickable prototypes for the supplier action link and the merchant fulfilment
card, matched to the app's real tokens (emerald #059669, danger #DC2626,
#0F172A on #F8FAFC, 16px card / 12px control radii, system font stack — the app
loads no webfont and a public page on Ghanaian mobile data should not add one).

- `Main.dc.html`     — the supplier's phone, all six states, clickable
- `Merchant.dc.html` — the fulfilment card and the orders-list row
- `canvas.json`      — layout and the notes shown beside each artboard
- `product.jpg`      — downsampled from priv/static/images/landing

The delivery code in the prototype is ENFORCED (demo code 429117), because the
real system enforces it: `CustomerDelivery.validate_code/2` bcrypt-checks and
counts failed attempts. An earlier version of this mock let "Done" through with
no code — a prototype that fakes a security control teaches the opposite of the
truth, so it either behaves like the protection or visibly isn't there.

To change anything: edit these files, then re-seed and republish to the SAME
url (see the /design skill). Do not edit `supplier-handover-ux.html` directly —
it is generated.
