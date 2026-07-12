# Akwaaba — the photo-led commercial theme

**Status:** spec
**Reference:** Dribbble "Fashion eCommerce Website" (Frolax) by Bilash Roy —
https://dribbble.com/shots/26410257-Fashion-eCommerce-Website

Kojo rejected the existing seven themes as "nowhere near" this reference. They
are type-led editorial minimalism; the reference is a **warm, photo-led,
commercial storefront**. Akwaaba is that storefront. It is a NEW theme —
Chale (streetwear, Anton, crimson) stays exactly as it is.

"Akwaaba" is Ghanaian for *welcome*. That is the brief: a shop that greets you.

---

## What the reference actually does

Observed directly from the shot, not from memory:

**Hero** — the whole top of the page is one big rounded orange panel with a
generous white margin around it. Inside it:
- a **floating white pill nav bar**, centred, with the active link as an orange
  pill, plus circular white icon buttons (search, cart with a count badge)
- headline **left**: light, wide-tracked **serif**, white, two lines, huge
- the product/model photo **centre**, cut out, standing directly on the panel —
  no frame, no card
- **right**: a social-proof stack (avatars, rating, one short paragraph) and an
  amber pill CTA
- a small rounded photo card floating bottom-left
- below the panel: a row of **four outlined USP cards** (icon + serif title +
  one line), e.g. free shipping, secure payment, returns, support

**Then**: photo category tiles with overlay labels and pill CTAs → product cards
with sale badges and a wishlist heart → a **full-bleed amber band carrying a
giant wordmark** with a floating product card over it → an editorial photo
mosaic → a wide image with a huge overlay headline → testimonials → a promo /
email-capture banner → a black footer with the **wordmark oversized and bleeding
off the bottom edge**.

**Vocabulary:** rounded everything (16–32px), pill buttons, floating cards that
overlap their panels, white chips on photos, saturated warm ground, serif
display + sans body.

---

## Palette

| Token | Value | Use |
|---|---|---|
| primary | `#F0531F` | hero panel, CTAs, active pill, price |
| amber | `#F5A524` | wordmark band, promo banner, secondary CTA |
| ink | `#101010` | footer, text, dark buttons |
| ground | `#FFFFFF` | page |
| mist | `#F6F4F1` | card grounds, USP card borders |

Warm neutrals only — no cool greys. The ground is white, not cream: the
reference's warmth comes from the orange, not from a beige page.

## Type

- Display: **Playfair Display** — light/regular weights, wide tracking, used
  large. Headline, section headings, USP titles, wordmark.
- Body: **Archivo** — nav, copy, buttons, prices.

---

## Hard gates (each one is a real production bug we have already shipped once)

1. **The theme renders its own nav, and the cart is reachable on desktop.**
   The mobile bottom bar is `sm:hidden`; a nav that only puts the cart there
   leaves desktop shoppers unable to check out. (This broke Market and Vibrant.)
2. **No `phx-click` / `phx-submit` without a real handler.** `add_to_cart` and
   `subscribe_newsletter` are handled; anything else you invent is a crash.
   (An unhandled `subscribe_newsletter` took down live storefronts.)
3. **Every `settings_schema` entry MUST declare `default:`.** The section editor
   coerces against it; a missing default destroys a merchant's unpublished draft.
4. **Sections tolerate empty data.** No products, no categories, no images, no
   description — every section either renders an intentional empty state or does
   not render. A brand-new store must never look broken.
5. **Photo-led means photo-*fallback*, not photo-*required*.** The hero pulls,
   in order: the merchant's hero upload → the first product's photograph → type
   alone. The old Chale hero was photo-*optional* and so every real store opened
   on an empty grey band. Do not repeat that.
6. **Do not modify `StorefrontComponents` or any other theme.** Akwaaba owns its
   own components.

## Honesty gate — read this twice

The reference shows **"4.8 (15K rating)"** and a **"+27K" avatar cluster**.
**Do not fabricate these.** On a real merchant's storefront invented social
proof is a lie told to their customers, and it is the merchant who wears it.

- Wire the rating slot to the store's **real** review data (`avg_rating`,
  `review_count`) and render it **only** when there is real data.
- With no reviews, fall back to what is true: the payment rails the store
  actually accepts (MTN MoMo, Telecel Cash, card) and secure-checkout.

Same rule everywhere: no invented testimonials, no fake "27K customers", no
placeholder discount that is not a real `compare_at_price`. The testimonials
section renders **only** from real reviews, and does not render without them.

---

## Sections (in default order)

| key | what |
|---|---|
| `akwaaba/hero` | the orange panel: floating pill nav is chrome, so the panel holds headline + photo + real-proof stack + amber CTA. Carries the page's single `<h1>`. |
| `akwaaba/usp` | four outlined rounded cards: icon, serif title, one line. Real rails only. |
| `akwaaba/categories` | photo tiles, overlay label, pill "View collection". Falls back to a tinted tile + initial with no image. |
| `akwaaba/collection` | product cards: rounded, photo, sale badge from a real `compare_at_price`, quick add. |
| `akwaaba/wordmark` | full-bleed amber band, the store's name at display scale, a floating product card over it. |
| `akwaaba/editorial` | wide photo with a huge serif overlay headline. Does not render without a photo. |
| `akwaaba/testimonials` | real reviews only. No reviews → no section. |
| `akwaaba/newsletter` | promo banner: amber, email capture via `subscribe_newsletter`. |

Footer: ink, link columns, payment rails, and the store name oversized along the
bottom edge, clipped by `overflow-hidden`.

## Deliverables

`lib/emakola/themes/akwaaba.ex`, `akwaaba/{shared,home,product_list,product_detail}.ex`,
`akwaaba/sections/*.ex`, and `test/emakola/themes/akwaaba_test.exs`.

Registration (`Sections`, `ThemeResolver`, and the pickers) is handled by the
orchestrator — do not edit those four files.
