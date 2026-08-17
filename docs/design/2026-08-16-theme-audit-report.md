# Theme Design Audit — All 22 Themes, Desktop + Mobile

**Date:** 2026-08-16 · **Branch:** `feature/theme-design-audit`
**Scope:** every registered theme × buyer funnel (home, PLP, PDP, about, cart; checkout on 3 representatives) × desktop 1280×800 + mobile 375×812.
**Method:** `mix emakola.seed_theme_demos` created a `<theme>-demo` store per theme with **pure-default** `theme_config` (`%{"theme" => id}` only) and an identical catalogue, so screenshots show each theme's designed look with no merchant overrides. Captured via `e2e/tests/theme-audit.spec.ts` (Playwright, `waitForLiveView`, overflow assertion per page) against `PORT=4004`. 230 full-page PNGs + machine findings (`findings-{desktop,mobile}.jsonl`) live in `.claude/qa-archives/theme-audit-2026-08-16/` (gitignored, local-only; fully reproducible via the commands at the end of this report). Visual review: 5 parallel reviewers against the craft bar in `docs/superpowers/specs/2026-07-12-seven-themes-contract.md`, low-literacy/visuals-first lens, retention lens.

## Executive summary

The catalogue-facing pages (home → PLP → PDP) are in good shape across most themes — 17 of 22 are POLISH-grade with real identities and complete funnels. The systemic problems live in the **shared surfaces**: the About fallback breaks brand on ~20 themes, the shared cart/reviews components leak generic chrome into every theme, and mobile bottom-nav chrome appears/disappears between pages of the same store. Three themes have funnel-breaking P0s (adwuma can't sell at all; spotlight shows a crash page; akwaaba/heirloom lose their cart footer). Fixing the 6 cross-cutting items would lift all 22 themes at once.

## Verdicts

| Theme | Verdict | Desktop | Mobile | Headline issue |
|---|---|---|---|---|
| adwuma | **OVERHAUL** | 4 | 4 | P0: PDP buy box unreachable (gallery image overlays page) |
| electronics | **OVERHAUL** | 5.5 | 5 | Hard-coded electronics vertical fights the real catalogue; no mobile nav |
| spotlight | **OVERHAUL** | 5 | 4.5 | P0: /about renders a Phoenix crash page; mobile overflow; duplicated buy module |
| akwaaba | POLISH | 7 | 7 | P0: cart footer white-on-white |
| heirloom | POLISH | 7 | 7 | P0: cart footer washes out; PLP cards show no prices |
| beauty | POLISH | 7 | 6 | Fabricated "TESTED/ECO-PACKED/BOTANICAL" badges (honesty violation) |
| pharmacy | POLISH | 7 | 6.5 | Fallback About chrome; empty hero panel |
| vibrant | POLISH | 7 | 7 | Empty category cards; double newsletter; ships shared footer everywhere |
| fresh | POLISH | 7.5 | 7.5 | Letter-circle category icons useless for low-literacy buyers |
| starter | POLISH | 7.5 | 7.5 | Imageless hero; clipped category pills |
| depot | POLISH | 8 | 6.5 | Order-sheet rows cram badly at 375px |
| fashion | POLISH | 8 | 7.5 | About chrome break; unthemed reviews |
| bold | POLISH | 8 | 8 | White caption text over pale photos, no scrim |
| atelier | POLISH | 8 | 7.5 | Visible "&AMP;" double-escape on PDP; empty Artisan's Signature block |
| chale | POLISH | 8 | 7.5 | About chrome break; nav-variant flip on cart |
| fie | POLISH (near-SHIP) | 8.5 | 8 | Minor truncation only |
| dede | POLISH (near-SHIP) | 8.5 | 8 | Best low-literacy fit (WhatsApp-first bottom nav); cart swaps its nav |
| sika | POLISH | 8.5 | 8 | Extremely long mobile scroll (~7,500px) |
| home_living | POLISH | 8 | 7 | No mobile nav on theme pages; empty hero half |
| market (default) | POLISH | 9 | 8 | P1: checkout-mobile header collision (platform-wide) |
| ntoma | POLISH | 9 | 8 | Triple wordmark on home; About loses identity |
| pace | POLISH | 9 | 8 | Lightest polish list of all 22 |

## P0 — broken funnel (fix first)

1. **Adwuma PDP cannot sell.** The gallery image renders full-bleed across the viewport; title, price, and Add to cart are visually gone, and the machine run proved the CTA is click-blocked on both viewports (4-minute Playwright retry, "img … subtree intercepts pointer events"). **Root cause found:** `Akwaaba.Shared.photo_or_initial/1` renders `absolute inset-0` children and relies on the caller for a `relative` container; adwuma's PDP wraps it in `aspect-[4/3] overflow-hidden …` with **no `relative`** (`lib/emakola/themes/adwuma/product_detail.ex:61`), so the image anchors to a distant ancestor and covers the page. One-class fix + a structural guard test (render tests can't catch this).
2. **Spotlight /about is a crash page.** HTTP 500 on both viewports; the visitor sees the full `UndefinedFunctionError: Emakola.Themes.Spotlight.render_about/1` stack trace. Spotlight is the only theme without `render_about/1`, but `about_live.ex:52-58` calls it on the `:default` path. Fix both sides: give Spotlight an about (or fall through to a real default) AND make `about_live` defensive. Extend `about_live_test` to loop all `theme_ids` — that gap is why this shipped.
3. **Akwaaba + Heirloom cart footer is white-on-white.** On `cart-empty` both themes lose the footer's dark background — wordmark, newsletter, and links render as ghost text (~500px unreadable dead zone at the end of the money path). Footer renders correctly on the themes' own pages, so the shared cart page (DefaultRenderers + Chrome) is dropping the theme's background context. Same mechanism suspected for both.

## P1 — systemic (one fix improves all 22)

4. **The shared About page is the platform's biggest brand break.** 21 themes delegate `render_about` to Atelier's About; on every non-Atelier theme it swaps in foreign chrome (search + "Journal" nav, generic black footer, different typography) and a gray letter-monogram placeholder where the story image should be. Every reviewer independently ranked this the #1 cohesion issue. Recommended shape: a theme-neutral About DefaultRenderer that uses each theme's own `storefront_nav`/`storefront_footer` via Chrome (like cart/checkout already do) + a designed empty-state instead of the letter placeholder.
5. **Mobile bottom-nav chrome is incoherent.** 12 themes ship no bottom nav on their own pages, yet the shared cart page injects the generic Home/Search/Saved/Cart bar — so nav appears/disappears between pages of one store. Themes that DO have a bottom nav get the wrong variant on cart (dede's Home/Menu/WhatsApp/Cart → generic; chale's uppercase → title-case; sika's "Collection" → "Search"; pace's dark pill → flat white). Fix: Chrome asks the theme for its bottom nav (as it does nav/footer), falling back consistently; then decide per-theme whether the 12 holdouts adopt one (product decision — dede's WhatsApp-first bar is the model for this audience).
6. **Checkout-mobile header collision (platform-wide).** "Back to Bag" collides with the two-line wrapped store wordmark on both captured themes (`market/checkout-mobile.png`, `atelier/checkout-mobile.png`). Checkout is shared — every store's first checkout screen looks broken on mobile. Also platform-wide at checkout: Telecel tile icon still reads "VODA"; AirtelTigo is advertised in "We accept" strips but absent as a payment option.
7. **Unthemed Customer Reviews block on every PDP.** Plain-sans white band with a ~200px dead gap and empty-star "(–)" rows; visually foreign on all 22 themes.
8. **Demo/seed images don't match their products.** `fugu-smock-1.jpg` is a hair salon, `kente-stole-1.jpg` an art gallery, `kente-adweneasa-1.jpg` a face portrait, `shito-1.jpg` a sundae; heirloom-demo's furniture uses skyscrapers/seascapes. These are the *existing* `priv/static/images/seed/` files, so the main seeded stores are affected too. For an image-first, low-literacy audience this makes every demo look broken. Data fix, not theme fix.
9. **Mobile product-title truncation is universal.** One-line ellipsis in 2-col grids chops nearly every title ("Royal Adweneasa Ke…"). Given the ≤8-word copy stance, a 2-line clamp is the likely fix in the shared card patterns.

## P1 — theme-specific

- **electronics:** hard-coded vertical copy/nav that lies about the store (dead category chips Wireless/Phones/Wearables, footer links to nonexistent categories, "Immersive Sound" banner over groundnuts); mobile spotlight card drops name/price/CTA; no mobile menu or bottom nav; footer omits payment badges and shows a "v1.0 · Ghana" dev artifact.
- **spotlight:** home-mobile has 12px horizontal overflow (newsletter Subscribe pill crosses the viewport; only overflow hit in 228 captures); PDP duplicates the entire buy module; header advertises Benefits/Ingredients/Reviews sections that don't exist.
- **beauty:** hardcoded "TESTED / ECO-PACKED / BOTANICAL" trust badges under every product — the invented-provenance class PRs #321-328 purged; extend `no_invented_provenance_test`. Footer links to Skincare/Hair/Body categories that don't exist.
- **bold:** white caption text directly over pale photos (rice, groundnuts) with no scrim — near-unreadable price/title on the featured mosaic.
- **vibrant:** "Shop the moments" renders three identical empty brown-gradient cards; two stacked newsletter signups on home; confirmed it ships the generic shared footer on every page (explorer: no `storefront_footer/1`) — passable but generic.
- **atelier:** "SHIPPING &AMP; RETURNS" double-escape, confirmed at `atelier/product_detail.ex:375` (`title="SHIPPING &amp; RETURNS"` re-escaped by HEEx); "The Artisan's Signature" is a full-viewport empty placeholder on mobile.
- **fresh:** category tiles are letter-circles (F/P/A) with truncated labels — neither picture nor readable word for low-literacy buyers (category-covers treatment exists in Market/Akwaaba to copy).
- **heirloom:** PLP collection cards omit prices (home cards show them); intro paragraph low-contrast.
- **market (default):** footer store name near-invisible dark-gray-on-black on PLP/PDP/cart.

## P2 — polish (selected; full lists in the reviewer transcripts)

Imageless gradient heroes with an empty half (fresh, starter, pharmacy, home_living, adwuma's text-only hero, beauty's icon-only panel); "Our story" home sections that render one thin line or an icon (fashion, fie, home_living); PDP image cards with dead white slabs under the photo (fresh, starter, vibrant, akwaaba's empty right column); ragged related-product row baselines (starter, vibrant); ntoma's triple wordmark; dede/chale duplicate hero product images; depot's text-only "Also stocked" list; akwaaba's "SHOP / SHOP - AKWAABA DEMO" breadcrumb; market/atelier checkout niceties (otherwise the checkout is excellently Ghana-localized: GhanaPost + landmark, MoMo-first tiles, "A prompt will appear on your phone").

## Recommended fix order

| # | PR | Contents | Effort |
|---|---|---|---|
| 1 | P0 funnel fixes | adwuma `relative` + structural guard; spotlight about (both sides) + all-theme about test; akwaaba/heirloom cart footer bg; atelier `&amp;` | S |
| 2 | About page | theme-chrome-inheriting About renderer + designed empty state (kills the #1 brand break on ~20 themes) | M |
| 3 | Mobile nav parity | Chrome delegates bottom nav to theme + consistent fallback; per-theme adoption decision for the 12 holdouts | M (needs product call) |
| 4 | Shared checkout/cart | mobile header collision, VODA→Telecel icon, AirtelTigo parity, reviews-block theming, cart typography leaks | M |
| 5 | Theme-specifics | electronics de-verticalization; spotlight overflow + dup module; beauty honesty badges; bold scrim; vibrant cards/newsletter; fresh category covers | M-L |
| 6 | Demo data | replace mismatched `priv/static/images/seed/` photos; heirloom-demo photo pass; 2-line title clamp | S-M |

Hard-gate reminder for the fix PRs: shared-component changes (`StorefrontComponents`, DefaultRenderers, Chrome) ship in their own scoped PRs, never smuggled into a theme PR (seven-themes-contract).

## Honest gaps — what this audit did not verify

- **Checkout captured on 3 themes only** (market, atelier, adwuma-blocked→0 shots); it's a shared renderer, so findings apply platform-wide, but the other 19 themes' checkout *chrome* is unverified. Adwuma's cart-filled/checkout shots are missing entirely — blocked by its P0.
- **Heirloom PDP was re-captured** with a real slug (`odum-slat-armchair`) after the first pass used the shared-catalogue slug that doesn't exist in that hand-built store; the initial "PDP unreachable" finding was a harness artifact and is retracted.
- Sticky bottom-nav presence was judged from full-page captures (sticky elements paint once, at their scroll position); per-page absence is corroborated by code (12 themes don't call `bottom_nav`) but individual-page rendering wasn't interactively verified.
- No interaction testing beyond the adwuma add-to-cart click; variant pickers, filters, and search were not exercised (single-variant demo products).
- Category pages (`/category/<slug>`) were not captured (PLP was); they share the DefaultRenderer.

## Reproduce

```bash
mix emakola.seed_theme_demos                 # idempotent; skips existing slugs
PORT=4004 mix phx.server
cd e2e && THEME_AUDIT=1 BASE_URL=http://localhost:4004 npx playwright test theme-audit --no-deps
```
