# Launch Steps Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give "Launch before lunch" the photo-card treatment with numbered color badges and animated arrow connectors, and rename the shared stagger CSS class to `stagger-grid`.

**Architecture:** Only `launch_steps/1` (+ a new `steps/0` data list) changes in `landing_live.ex`, plus the class rename in `features_grid/1`, one CSS rename + one new arrow keyframe in `app.css`, 3 new images, and test updates. The arrow connectors are `<span>` siblings between the card `<div>`s — the stagger CSS targets `> div` only, so arrows are unaffected (cards land on nth-child 1/3/5 → delays 0/140/280ms, fine).

**Tech Stack:** Phoenix LiveView, TailwindCSS v4 (note: v4's `rotate-90` uses the standalone `rotate` property, so it composes with the `translateX` keyframe), ScrollReveal hook.

**Spec:** `docs/superpowers/specs/2026-06-12-launch-steps-redesign-design.md`
**Branch:** `feature/landing-redesign` (open PR #126)

---

### Task 1: Download the 3 step photos

**Files:**
- Create: `priv/static/images/landing/step-{add-product,share-link,get-paid}.jpg`

- [ ] **Step 1: Download (600×360 crops)**

```bash
cd /Users/kojo/Projects/emakola/priv/static/images/landing
curl -sL -o step-add-product.jpg "https://images.unsplash.com/photo-1778079247396-9c0e01c83c8b?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o step-share-link.jpg  "https://images.unsplash.com/photo-1644043350898-2f4ff1e17912?q=70&w=600&h=360&fit=crop&fm=jpg"
curl -sL -o step-get-paid.jpg    "https://images.unsplash.com/photo-1697383904932-94304530a3dd?q=70&w=600&h=360&fit=crop&fm=jpg"
```

Briefs (verify each downloaded image matches before committing — open them with `open .` or `qlmanage -p`):
- `step-add-product.jpg`: woman selling spices, arranging her market stall
- `step-share-link.jpg`: a man and a woman looking at a phone together
- `step-get-paid.jpg`: a woman smiling while holding her phone

- [ ] **Step 2: Verify format/size**

Run: `file step-*.jpg | grep -v JPEG; sips -g pixelWidth -g pixelHeight step-add-product.jpg; du -h step-*.jpg`
Expected: all JPEG 600×360, each ≤ ~100 KB (q=60 re-download if over).

- [ ] **Step 3: Commit**

```bash
git add priv/static/images/landing/step-add-product.jpg priv/static/images/landing/step-share-link.jpg priv/static/images/landing/step-get-paid.jpg
git commit -m "feat(web): photography for launch steps redesign"
```

---

### Task 2: Arrow-nudge keyframe CSS

**Files:**
- Modify: `assets/css/app.css` (append at end)

- [ ] **Step 1: Append**

```css
/* Launch-steps arrow connectors (landing page): gentle forward nudge.
   Tailwind v4 rotate-* uses the standalone `rotate` property, so the
   mobile rotate-90 composes with this transform animation. */
@layer components {
  .step-arrow {
    animation: step-arrow-nudge 1.6s ease-in-out infinite;
  }
  @keyframes step-arrow-nudge {
    0%, 100% { transform: translateX(0); }
    50% { transform: translateX(5px); }
  }
  @media (prefers-reduced-motion: reduce) {
    .step-arrow { animation: none; }
  }
}
```

- [ ] **Step 2: Verify + commit**

Run: `mix assets.build && mix test test/emakola_web/live/landing_live_test.exs`
Expected: clean build; 17 tests, 0 failures.

```bash
git add assets/css/app.css
git commit -m "feat(web): arrow nudge animation for launch steps"
```

---

### Task 3: TDD — launch steps rewrite + `stagger-grid` rename

**Files:**
- Test: `test/emakola_web/live/landing_live_test.exs`
- Modify: `lib/emakola_web/live/landing_live.ex` (`launch_steps/1`, new `steps/0`, one class in `features_grid/1`)
- Modify: `assets/css/app.css` (rename selectors in the existing stagger block)

- [ ] **Step 1: Update tests first**

Replace the entire `describe "launch steps" do ... end` block with:

```elixir
  describe "launch steps" do
    test "renders the three photo step cards with number badges", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Launch before lunch"
      assert html =~ "Most merchants go live in under an hour."
      assert html =~ "Add your first product"
      assert html =~ "Share your store link"
      assert html =~ "Get paid with MoMo"
      assert html =~ "Snap it, price it, done"
      assert html =~ "WhatsApp it to your customers"
      assert html =~ "Money straight to your wallet"
      assert html =~ "step-add-product.jpg"
      assert html =~ "step-share-link.jpg"
      assert html =~ "step-get-paid.jpg"
      assert html =~ "bg-sky-500"
    end
  end
```

In the `"features carry photos and color badges"` test, change
`assert html =~ "features-grid"` to `assert html =~ "stagger-grid"`.

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/landing_live_test.exs`
Expected: the launch-steps test and the features badge test FAIL; others PASS.

- [ ] **Step 3: Rename the stagger class in CSS**

In the `app.css` stagger block (added 6e8fd01): replace every `.features-grid` with
`.stagger-grid` (11 occurrences incl. reduced-motion rules) and update its comment's
first line to `/* Shared section entrance stagger (landing page): features grid +
launch steps.`

- [ ] **Step 4: Rename the class in `features_grid/1`**

In `landing_live.ex`: `class="features-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"`
→ `class="stagger-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"`.

- [ ] **Step 5: Replace `launch_steps/1` and add `steps/0`**

```elixir
  defp launch_steps(assigns) do
    ~H"""
    <section class="bg-[#f7f8fa] py-20 px-4 sm:px-6" data-reveal>
      <div class="max-w-5xl mx-auto text-center">
        <h2 class="text-2xl lg:text-3xl font-headline font-bold text-[#0c1526] mb-2">
          Launch before lunch
        </h2>
        <p class="text-base text-[#5f6b7a] mb-12">Most merchants go live in under an hour.</p>
        <div class="stagger-grid flex flex-col md:flex-row items-stretch gap-4 text-left" data-reveal>
          <%= for {step, i} <- Enum.with_index(steps()) do %>
            <span
              :if={i > 0}
              class="step-arrow self-center shrink-0 rotate-90 md:rotate-0 text-[#d4a843]"
              aria-hidden="true"
            >
              <span class="material-symbols-outlined text-3xl">arrow_forward</span>
            </span>
            <div class="group flex-1 bg-white rounded-2xl overflow-hidden shadow-sm transition duration-300 hover:-translate-y-1.5 hover:shadow-xl">
              <div class="h-36 overflow-hidden">
                <img
                  src={step.img}
                  alt={step.alt}
                  loading="lazy"
                  width="600"
                  height="360"
                  class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
              </div>
              <div class="px-4 pb-5">
                <span class={[
                  "relative -mt-6 inline-flex w-12 h-12 items-center justify-center rounded-xl text-white shadow-lg font-headline font-extrabold",
                  step.badge
                ]}>
                  {step.number}
                </span>
                <h3 class="text-base font-bold text-[#0c1526] mt-2 mb-1">{step.title}</h3>
                <p class="text-sm text-[#5f6b7a]">{step.blurb}</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </section>
    """
  end
```

And next to `features/0`:

```elixir
  defp steps do
    [
      %{
        number: "01",
        title: "Add your first product",
        blurb: "Snap it, price it, done",
        badge: "bg-sky-500 shadow-sky-500/40",
        img: "/images/landing/step-add-product.jpg",
        alt: "Market woman arranging the goods on her stall"
      },
      %{
        number: "02",
        title: "Share your store link",
        blurb: "WhatsApp it to your customers",
        badge: "bg-violet-500 shadow-violet-500/40",
        img: "/images/landing/step-share-link.jpg",
        alt: "Man and woman smiling at a phone screen together"
      },
      %{
        number: "03",
        title: "Get paid with MoMo",
        blurb: "Money straight to your wallet",
        badge: "bg-emerald-500 shadow-emerald-500/40",
        img: "/images/landing/step-get-paid.jpg",
        alt: "Woman smiling at the mobile money payment on her phone"
      }
    ]
  end
```

- [ ] **Step 6: Run to green**

Run: `mix assets.build && mix test test/emakola_web/live/landing_live_test.exs test/emakola_web/live/pricing_live_test.exs`
Expected: 23 tests, 0 failures.

- [ ] **Step 7: Gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/landing_live.ex test/emakola_web/live/landing_live_test.exs assets/css/app.css
git commit -m "feat(web): photo step cards with numbered badges and animated arrows"
```

---

### Task 4: Full verification, push, PR correction

- [ ] **Step 1: Fresh-compile CI-equivalent test run**

The CI gate is full-green with warnings-as-errors (the earlier "58 local failures" was a
local-env artifact — see memory). Run:

```bash
mix clean --only app && mix test --warnings-as-errors 2>&1 | tail -3
```
Expected: 0 failures. If MASS failures appear in unrelated areas (auth/admin/etc.),
suspect the local test DB (e.g. pending migrations: `MIX_ENV=test mix ecto.migrate`)
before treating anything as a regression; scoped landing/pricing/sitemap tests are the
feature gate either way.

- [ ] **Step 2: Browser smoke check (both redesigned sections)**

Dev server + browser with the PWA service worker unregistered (it serves stale CSS
cache-first). Verify: features grid staggers in, hover lifts + photo zoom works AFTER
the entrance animation settles (this was a fixed bug — confirm), 9 distinct badge
colors; launch steps show photos, numbered badges, arrows nudging forward (right on
desktop, downward on a 375px window), no horizontal overflow.

- [ ] **Step 3: Push and correct the PR body**

```bash
git push origin feature/landing-redesign
```
Then update PR #126's description: replace the "58 failures — identical to the
pre-existing baseline" sentence in the Test plan with the corrected fact (CI full suite
green; earlier local failures were an environment artifact), and add the two new
sections (features grid + launch steps redesign) to the Summary.
