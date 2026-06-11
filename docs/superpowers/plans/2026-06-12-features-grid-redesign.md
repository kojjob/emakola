# Features Grid Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat icon features grid on the landing page with photo-led, color-badged, stagger-animated cards readable by low-literacy merchants.

**Architecture:** Only `features_grid/1` + `features/0` in `landing_live.ex` change, plus one `@layer components` CSS block for the entrance stagger and 5 new images. The stagger is a keyframe animation triggered by the existing ScrollReveal hook adding `.revealed` to the grid container — animation-delay staggers children without interfering with hover transitions (the reveal system's `transition-delay` would lag hovers, hence animation).

**Tech Stack:** Phoenix LiveView, TailwindCSS v4, existing ScrollReveal IntersectionObserver hook.

**Spec:** `docs/superpowers/specs/2026-06-12-features-grid-redesign-design.md`
**Branch:** `feature/landing-redesign` (open PR #126 — commits extend it)

---

### Task 1: Download the 5 new feature photos

**Files:**
- Create: `priv/static/images/landing/feature-{dropship,digital,stock,delivery,reports}.jpg`

- [ ] **Step 1: Download at final crop (600×360)**

```bash
cd /Users/kojo/Projects/emakola/priv/static/images/landing
curl -sL -o feature-dropship.jpg "https://images.unsplash.com/photo-1642756457381-930fdc1e2e2e?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o feature-digital.jpg  "https://images.unsplash.com/photo-1739300293504-234817eead52?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o feature-stock.jpg    "https://images.unsplash.com/photo-1737219239970-4f2bea75b3d1?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o feature-delivery.jpg "https://images.unsplash.com/photo-1762530179279-b9fbd4180b51?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o feature-reports.jpg  "https://images.unsplash.com/photo-1615891081220-9116de3e1afd?q=70&w=600&h=360&fit=crop&fm=jpg"
```

- [ ] **Step 2: Verify**

Run: `file feature-*.jpg | grep -v "JPEG image data"; sips -g pixelWidth -g pixelHeight feature-dropship.jpg; du -h feature-*.jpg`
Expected: no non-JPEG output; 600×360; each ≤ ~100 KB (re-download with `q=60` if over).

- [ ] **Step 3: Commit**

```bash
git add priv/static/images/landing/feature-dropship.jpg priv/static/images/landing/feature-digital.jpg priv/static/images/landing/feature-stock.jpg priv/static/images/landing/feature-delivery.jpg priv/static/images/landing/feature-reports.jpg
git commit -m "feat(web): photography for features grid redesign"
```

---

### Task 2: Entrance-stagger CSS

**Files:**
- Modify: `assets/css/app.css` (append at end)

- [ ] **Step 1: Append the stagger block**

```css
/* Features grid entrance stagger (landing page).
   ScrollReveal adds .reveal-hidden then .revealed to the grid container;
   children animate in with per-card delays. Keyframe animation (not
   transition-delay) so card hover transitions are never delayed.
   Without JS, .reveal-hidden is never added and cards stay visible. */
@layer components {
  .features-grid.reveal-hidden > div {
    opacity: 0;
  }
  .features-grid.reveal-hidden.revealed > div {
    animation: feature-rise 0.55s ease-out both;
  }
  .features-grid.reveal-hidden.revealed > div:nth-child(2) { animation-delay: 70ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(3) { animation-delay: 140ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(4) { animation-delay: 210ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(5) { animation-delay: 280ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(6) { animation-delay: 350ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(7) { animation-delay: 420ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(8) { animation-delay: 490ms; }
  .features-grid.reveal-hidden.revealed > div:nth-child(9) { animation-delay: 560ms; }
  @keyframes feature-rise {
    from { opacity: 0; transform: translateY(18px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @media (prefers-reduced-motion: reduce) {
    .features-grid.reveal-hidden > div { opacity: 1; }
    .features-grid.reveal-hidden.revealed > div { animation: none; }
  }
}
```

- [ ] **Step 2: Verify build + existing tests untouched**

Run: `mix assets.build && mix test test/emakola_web/live/landing_live_test.exs`
Expected: build clean; 16 tests, 0 failures (no markup uses `.features-grid` yet).

- [ ] **Step 3: Commit**

```bash
git add assets/css/app.css
git commit -m "feat(web): scroll-triggered stagger animation for features grid"
```

---

### Task 3: Rewrite the features grid (TDD)

**Files:**
- Test: `test/emakola_web/live/landing_live_test.exs` (replace the `describe "features grid"` block)
- Modify: `lib/emakola_web/live/landing_live.ex` (`features_grid/1` and `features/0` only)

- [ ] **Step 1: Replace the features grid test block**

Replace the entire existing `describe "features grid" do ... end` with:

```elixir
  describe "features grid" do
    test "renders nine photo-led features with short titles", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Everything you need to sell"

      for title <- [
            "Dropshipping",
            "Themes",
            "Digital goods",
            "Stock",
            "Delivery",
            "Discounts",
            "Reports",
            "Blog &amp; recipes",
            "Many stores"
          ] do
        assert html =~ title
      end
    end

    test "features carry photos and color badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      for img <- [
            "feature-dropship.jpg",
            "feature-digital.jpg",
            "feature-stock.jpg",
            "feature-delivery.jpg",
            "feature-reports.jpg"
          ] do
        assert html =~ img
      end

      assert html =~ "bg-violet-500"
      assert html =~ "features-grid"
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/landing_live_test.exs`
Expected: the two new tests FAIL (old grid has long titles, no feature-*.jpg images); all other tests PASS.

- [ ] **Step 3: Replace `features_grid/1`**

```elixir
  defp features_grid(assigns) do
    ~H"""
    <section id="features" class="bg-white py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] text-center mb-2">
          Everything you need to sell
        </h2>
        <p class="text-base text-[#5f6b7a] text-center mb-12">
          The full toolkit, built for Ghana
        </p>
        <div
          class="features-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"
          data-reveal
        >
          <div
            :for={feature <- features()}
            class="group bg-[#f7f8fa] rounded-2xl overflow-hidden transition duration-300 hover:-translate-y-1.5 hover:shadow-xl"
          >
            <div class="h-36 overflow-hidden">
              <img
                src={feature.img}
                alt={feature.alt}
                loading="lazy"
                width="600"
                height="360"
                class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
              />
            </div>
            <div class="px-4 pb-5">
              <span class={[
                "relative -mt-6 inline-flex w-12 h-12 items-center justify-center rounded-xl text-white shadow-lg",
                feature.badge
              ]}>
                <span class="material-symbols-outlined text-2xl" aria-hidden="true">
                  {feature.icon}
                </span>
              </span>
              <h3 class="text-base font-bold text-[#0c1526] mt-2 mb-1">{feature.title}</h3>
              <p class="text-sm text-[#5f6b7a]">{feature.blurb}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
```

Note: individual cards no longer carry `data-reveal` — the grid container does, and the
CSS from Task 2 staggers the children. Badge classes are full literal strings (Tailwind
scanner requirement).

- [ ] **Step 4: Replace `features/0`**

```elixir
  defp features do
    [
      %{
        title: "Dropshipping",
        blurb: "Suppliers hold it, you sell it",
        icon: "warehouse",
        badge: "bg-violet-500 shadow-violet-500/40",
        img: "/images/landing/feature-dropship.jpg",
        alt: "Man pushing a cart stacked with boxes through the street"
      },
      %{
        title: "Themes",
        blurb: "14 beautiful looks for your store",
        icon: "palette",
        badge: "bg-rose-500 shadow-rose-500/40",
        img: "/images/landing/store-tailor.jpg",
        alt: "Tailor smiling as he works at his sewing machine"
      },
      %{
        title: "Digital goods",
        blurb: "Files delivered after payment",
        icon: "download",
        badge: "bg-sky-500 shadow-sky-500/40",
        img: "/images/landing/feature-digital.jpg",
        alt: "Woman working at a laptop"
      },
      %{
        title: "Stock",
        blurb: "Always know what is left",
        icon: "inventory_2",
        badge: "bg-amber-500 shadow-amber-500/40",
        img: "/images/landing/feature-stock.jpg",
        alt: "Stacked yellow crates ready for sale"
      },
      %{
        title: "Delivery",
        blurb: "Across all of Ghana",
        icon: "local_shipping",
        badge: "bg-orange-500 shadow-orange-500/40",
        img: "/images/landing/feature-delivery.jpg",
        alt: "Cargo motorcycle loaded with goods on the road"
      },
      %{
        title: "Discounts",
        blurb: "Bring customers back",
        icon: "percent",
        badge: "bg-emerald-500 shadow-emerald-500/40",
        img: "/images/landing/store-fruit.jpg",
        alt: "Market woman in an orange dress arranging fruit at her stall"
      },
      %{
        title: "Reports",
        blurb: "See your sales clearly",
        icon: "monitoring",
        badge: "bg-indigo-500 shadow-indigo-500/40",
        img: "/images/landing/feature-reports.jpg",
        alt: "Smiling woman checking her sales on a laptop"
      },
      %{
        title: "Blog & recipes",
        blurb: "Share posts and recipes",
        icon: "article",
        badge: "bg-teal-500 shadow-teal-500/40",
        img: "/images/landing/store-eggs.jpg",
        alt: "Woman selling a pyramid of fresh eggs at the market"
      },
      %{
        title: "Many stores",
        blurb: "One account, one dashboard",
        icon: "storefront",
        badge: "bg-pink-500 shadow-pink-500/40",
        img: "/images/landing/cta-market.jpg",
        alt: "Bustling market street with many stalls"
      }
    ]
  end
```

- [ ] **Step 5: Run tests to verify green**

Run: `mix test test/emakola_web/live/landing_live_test.exs test/emakola_web/live/pricing_live_test.exs`
Expected: 23 tests, 0 failures (16 landing incl. the replaced block + 1 extra test, 6 pricing).
If a title substring collides with copy elsewhere on the page, read the failure and tighten
the assertion (e.g. assert the `<h3>` form: `assert html =~ ">Stock</h3>"`), never weaken it.

- [ ] **Step 6: Full gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/landing_live.ex test/emakola_web/live/landing_live_test.exs
git commit -m "feat(web): photo-led color-badged features grid for low-literacy merchants"
```

---

### Task 4: Visual verification + push

- [ ] **Step 1: Browser smoke check**

With the dev server running, load `http://localhost:4000/` in a browser, **first
unregistering the PWA service worker** (it serves stale CSS cache-first — see memory note;
DevTools → Application → Service Workers → Unregister, then hard reload). Scroll to the
features section and confirm: photos render, cards stagger in one after another, hover
lifts the card and zooms the photo, badges show 9 distinct colors. Resize to 375px —
single column, no horizontal overflow.

- [ ] **Step 2: Push (updates PR #126)**

```bash
git push origin feature/landing-redesign
```
