# Announcement banner — three directions

The platform announcement banner as merchants see it on their Dashboard.
Before (`app.html.heex`) it was a flat tinted strip above the top bar with
a text "Dismiss" link, blue for info. Three ways to make it beautiful, each
at phone width and in the desktop content area, plus the composer at
`/platform/announcements` with a live preview. **A · Card was chosen and
built 2026-09-04** (`EmakolaWeb.AnnouncementComponents.announcement_banner`,
rendered by `DashboardLive` under the greeting; the composer previews it).
Not built: the action button on a critical card (the resource has no link
field yet) and the severity chips on the composer.

- `Main.dc.html`, `CardSeverities.dc.html`, `CardDesktop.dc.html` — A · Card: in the page under the greeting, gradient icon disc, one big Got it
- `Ribbon*.dc.html` — B · Ribbon: today's place above the top bar, made handsome
- `Sheet*.dc.html` — C · Sheet: critical announcements interrupt once, phone sheet or desktop card
- `Composer.dc.html` — the platform page with a live preview and severity chips
- `build.mjs` — generates every artboard and `canvas.json`; edit this, not the `.dc.html`

Rebuild and re-seed after an edit (see the /design skill for the seeder path):

```bash
node build.mjs
node "<design skill dir>/seed-canvas.mjs" \
  --template "<design skill dir>/payload.template.html" \
  --out announcement-banner.html --title "Announcement Banner" \
  --artboard Main.dc.html --artboard CardSeverities.dc.html --artboard CardDesktop.dc.html \
  --artboard RibbonPhone.dc.html --artboard RibbonSeverities.dc.html --artboard RibbonDesktop.dc.html \
  --artboard SheetPhone.dc.html --artboard SheetDesktop.dc.html --artboard Composer.dc.html \
  --canvas canvas.json
```

## What these are matched to

- Tokens from `assets/css/app.css` `@theme` and the admin shell: emerald
  `#059669` / `#047857`, soft `#ECFDF5`, slate borders `#E2E8F0`, Inter.
- The phone frames draw the live `admin_topbar` (72px) and the live
  Dashboard header (`dashboard_components.ex`: greeting, period pills,
  refresh); the desktop frames draw the content area at 1440.
- Severity keeps the resource's three values (`:info`, `:warning`,
  `:critical`) with one icon each: megaphone, warning triangle, bell alert.
  Info is emerald, not the blue the strip uses today.
- Controls: 48px Got it (56px on the sheet), 13px radius, 36px round X.
- Copy stays under eight words. Sample announcements only.
