# Merchant Admin IA + Supply-Surface Polish — Design

**Date:** 2026-07-24
**Status:** Approved
**Owner ask:** Tier 1 (sidebar information architecture + announcement noise)
and Tier 2 (elevate the new supply pages to the Makola Admin design language)
before inviting founding sellers. Branch based on PR #342's tip (contains all
three marketplace features); its PR merges after #342.

Decision locked with Kojo: **"Marketplace group"** IA with renames.

## 1. Sidebar regroup + renames (`sidebar_components.ex`)

Sections (labels are the existing `nav-section-label` style, all entries keep
their current hrefs and `active_nav` atoms — this is markup order + titles
only):

- **Main**: Dashboard
- **Sell**: Products, Inventory, Categories, Orders, Returns
- **Marketplace**: Browse Suppliers (was "Supplier Catalog"), My Offers,
  Partners (was "Earn Network"), My Contacts (was "Suppliers")
- **Customers & Marketing**: Customers, Payments, Discounts, Campaigns
- **Content & Design**: Theme, Design, Blog & Pages, Media, Store Pages
- **Insights**: Reports, Revenue
- Bottom block unchanged: Settings, Verification, Payouts.

**Copy ripple (same task):** user-facing text that says "Earn Network" must
follow the rename to "Partners": `Templates.connection_sms/3` requested copy
("…on your Earn Network page" → "…on your Partners page"),
`connection_whatsapp_params` destination naming if any, the catalog Show
`:unavailable` notice + `:connection_exists` flash ("manage it from your Earn
Network page" → "Partners page"), and the offers-Index/Earn-catalog banner
line if it names pages. PROVIDER_SETUP §4c template body mentions a URL only
(no rename needed) — verify. Tests asserting the old copy update with it.

## 2. Announcements: dashboard-only

Platform announcements (the "Welcome to Makola Payouts 🎉" banner) currently
render on every admin page. Verify dismissal persists per-merchant (an
`AnnouncementDismissal` resource exists — confirm the Dismiss button writes
it); then scope the banner rendering to the Dashboard page only. No other
announcement behavior changes.

## 3. Supply-surface polish (Makola Admin design language; use the
frontend-design skill at implementation)

- **My Offers index**: product thumbnail (image already preloaded via
  `source_product: :images`; fall back to the icon block pattern used by the
  catalog cards when no image); keep row layout otherwise.
- **Offer form**: add a product context header on `:edit` (thumbnail + product
  title + status pill — currently the page says only "Edit offer"); align each
  region row's fee input right within the row; single column below `sm`.
- **Catalog Show**: margin economics as stat tiles above the variants table
  (three tiles: Suggested retail · Wholesale · Your margin GH₵ + %) for the
  connected state, matching the stat-tile pattern used in the merchant
  dashboard; table stays as the per-variant detail.
- **Mobile**: all three supply pages reviewed at 375px width; fix wrapping/
  padding regressions only (no redesign).

## 4. Testing

- Existing LV suites stay green with title renames (update assertions that
  pinned old names).
- Sidebar: one test asserting the section labels render and the four renamed
  entries point at their unchanged hrefs.
- Copy: template tests updated to the new "Partners page" copy.
- Announcements: test that the banner renders on Dashboard and NOT on another
  admin page; dismissal persistence covered (add if missing).
- Visual verification: controller-driven Playwright screenshots (desktop +
  375px) after the final task.

## Out of scope

Platform-admin redesign sub-projects; theme/design-token sweep; storefront
changes; any route or `active_nav` renames (titles only).
