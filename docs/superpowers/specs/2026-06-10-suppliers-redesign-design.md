# Suppliers Pages Redesign

**Date:** 2026-06-10
**Pages:** `/admin/settings/suppliers` (SupplierLive.Index), `/admin/suppliers/:id` (SupplierLive.Show)
**Goal:** Replace dense, text-heavy tables with a visual, low-literacy-friendly layout.
Merchants should understand who they owe and reach suppliers without reading.

## Constraints (from user)

- Compact — no large cards that waste space
- 4-column tile grid on the index page
- Dashboard style with **big metric cards** on the detail page
- SVG icons only (Heroicons + WhatsApp brand SVG) — **no emoji**
- Add/Edit form becomes a slide-over panel (same `<.modal kind={:slide_over}>` as products)

## Page 1 — Suppliers index

- Responsive tile grid: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`.
- Each tile (centered): colored initial avatar (color derived from name hash),
  supplier name, owed badge (red `GH₵ X` when balance > 0, green check `Paid`
  when 0), round Call and WhatsApp icon buttons, small pencil edit button.
- Call button = `tel:{contact_phone}` link; WhatsApp = `https://wa.me/{digits}`
  link. Each renders only when the number exists.
- Tile body links to the detail page.
- Inactive suppliers render greyed out (reduced opacity) with an "Inactive" badge.
- Dashed "+ Add Supplier" tile at the end of the grid; header Add button stays.
- Add/Edit form moves into a slide-over (`<.modal kind={:slide_over}>`), same
  six fields, larger inputs. Active/inactive toggle moves into the edit
  slide-over as a labelled switch.
- Empty state unchanged in spirit (truck icon + hint) but centered above the
  Add tile.

## Page 2 — Supplier detail

- Header: avatar + name + phone subtitle on the left; big Call / WhatsApp
  buttons (SVG, `tel:`/`wa.me`) on the right.
- Three large metric cards (`grid-cols-1 sm:grid-cols-3`):
  - **You owe** — red tinted card, sum of unpaid entries (existing
    `outstanding_balance`)
  - **Paid so far** — green tinted card, sum of `amount_owed` over paid entries
    (computed in Elixir from loaded `ledger_entries`)
  - **Payments** — neutral card, `length(ledger_entries)`
- Ledger as simple rows (no table): amount + date left, big green
  **Mark Paid** button (owed) or green "Paid" pill (paid) right.
- Contact/payment details and notes collapse into a small card under the
  metrics (payment info + notes only; phone/WhatsApp/email live in the header
  buttons).

## Non-goals / unchanged

- No backend changes: events (`save_supplier`, `edit_supplier`,
  `toggle_active`, `mark_paid`), data loading, and resources stay as-is.
- No new queries — paid total and count derive from already-loaded entries.
- Suppliers are still never hard-deleted.

## Testing

- Existing supplier LiveView tests keep passing (selectors updated where they
  referenced table markup).
- New tests: tile grid renders supplier name + owed amount; `tel:` and `wa.me`
  links present when numbers exist and absent when not; slide-over opens on
  add/edit; detail page shows the three metric values; Mark Paid still works.
