# Theme Customizer Admin UI — Design Spec

**Date:** 2026-03-25
**Status:** Approved

---

## Goal

Allow merchants to select a storefront theme and customize colors, hero content, and section visibility through an admin UI. Theme selection is part of onboarding (new merchants) and editable anytime via a dedicated admin page.

## Architecture

Full-screen preview with a floating settings drawer that slides in from the right. The preview renders the actual storefront in an iframe. Changes are reflected live before saving.

---

## Onboarding Theme Selection

Modify the existing onboarding flow to include a theme selection step.

**UI:** 3 theme cards in a row, each showing:
- Theme name (Market, Atelier, Vibrant)
- Color swatch strip (primary + accent + background)
- Brief description (1 line)
- "Select" button

Default: Market (pre-selected). Merchant can change or skip (Market is applied).

**Data:** On selection, write `%{"theme" => "atelier"}` (or chosen theme) to `store.theme_config` via `Ash.update(:update_settings)`.

---

## Admin Theme Page (`/admin/theme`)

### Layout

```
+--------------------------------------------------+--------+
|                                                  | Drawer |
|              Storefront Preview                  | (320px)|
|              (iframe: /s/:slug/)                 |        |
|                                                  |        |
|                                                  |        |
+--------------------------------------------------+--------+
```

### Floating Drawer (right side, 320px)

Slides in/out with a toggle button. Contains:

**1. Theme Selector**
- 3 small cards (current theme highlighted with ring)
- Click to switch theme

**2. Colors**
- Primary color: text input with color swatch preview (hex input, not a full color picker — simpler for low-literacy)
- Accent color: same
- Background color: same

**3. Hero Settings**
- Title: text input
- Subtitle: text input
- CTA text: text input
- Hero image: file upload (stored via existing image upload infrastructure)

**4. Section Toggles**
- Hero: on/off toggle
- Categories: on/off toggle
- Featured Products: on/off toggle
- Brand Story: on/off toggle
- Instagram: on/off toggle
- Newsletter: on/off toggle

**5. Actions**
- "Save Changes" button (primary, green)
- "Reset to Default" button (secondary, ghost)

### Preview (iframe)

- Renders `/s/:store_slug/` in an iframe
- On theme/color/section changes, the iframe reloads with updated config
- The storefront LiveView already reads `theme_config` from the store, so saving the config and reloading the iframe shows the changes

### Save Flow

1. Merchant changes settings in drawer
2. Changes stored in LiveView assigns (not yet persisted)
3. Preview iframe shows current store (not live-updating — merchant must click "Save" then iframe reloads)
4. "Save Changes" writes the full `theme_config` map to the store via `Ash.update(:update_settings, %{theme_config: new_config})`
5. iframe reloads to show saved changes
6. Flash: "Theme updated successfully"

---

## Router

```elixir
# In the :app live_session
live "/admin/theme", Admin.ThemeLive
```

## Sidebar Navigation

Add "Theme" nav item in the admin sidebar under Marketing section:
- Icon: `palette` (Material Symbols)
- Label: "Theme"
- Route: `/admin/theme`

---

## Files

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/emakola_web/live/admin/theme_live.ex` | Theme customizer page |
| Modify | `lib/emakola_web/live/onboarding_live.ex` | Add theme selection step |
| Modify | `lib/emakola_web/components/layouts/app.html.heex` | Add Theme nav item |
| Modify | `lib/emakola_web/router.ex` | Add `/admin/theme` route |
| Create | `test/emakola_web/live/admin/theme_live_test.exs` | Tests |

---

## Testing

- Theme page renders with drawer and preview iframe
- Theme selection updates assigns
- Save writes theme_config to store
- Onboarding shows theme cards
- Color inputs accept valid hex values
- Section toggles update config
