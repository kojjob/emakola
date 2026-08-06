# Snap-to-Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merchant photographs goods → vision AI builds the full listing from that exact photo → merchant types only the price → optional "Real photo" storefront badge that revokes itself if the image is ever swapped.

**Architecture:** One new LiveView (`EmakolaWeb.Admin.ProductLive.Snap`) reusing the existing S3 upload pipeline and the AI foundation (`Emakola.AI.generate/3` with a new `:snap_to_shop` prompt + closed JSON schema). One new Product boolean (`snap_verified`) awarded at creation and revoked at the domain layer by image-mutation changes. One shared badge component fanned into every theme's ProductDetail.

**Tech Stack:** Phoenix LiveView (`start_async`, `allow_upload auto_upload: true`), Ash 3.x, Emakola.AI foundation (Sonnet 5 vision + `json_schema`), Mox (`Emakola.AI.ProviderMock`), Content.RateLimiter.

**Spec:** `docs/superpowers/specs/2026-08-05-snap-to-shop-design.md` — read it first; it is the requirements source.

## Global Constraints

- Money is never guessed: the AI output contains NO price field; the merchant types the GHS price. Amounts stay integer pesewas.
- Longform model is `@longform_model` (`claude-sonnet-5`) and the request MUST carry `thinking: :disabled` (Sonnet 5 thinks by default; thinking tokens bill against max_tokens and would truncate the JSON).
- The system prompt MUST contain the no-invented-provenance sentence verbatim from `:product_description` (`lib/emakola/ai/prompts.ex:26-31`): "Never invent a material, ingredient, origin, size, feature, certification, performance claim, delivery promise, return term, or warranty."
- Merchant-facing copy ≤ 8 words per string (low-literacy audience; prefer icons + visuals).
- File inputs: full-size `opacity-0` overlay pattern — NO `sr-only` file inputs (iOS Safari never opens the picker; PR #141/#145).
- Uploads: `auto_upload: true` (a submit gated on progress==100 without it deadlocks).
- Tests mock the provider via `Emakola.AI.ProviderMock` (Mox) — never a real API call.
- Migrations: `mix ash_postgres.generate_migrations --domains Emakola.Catalog` (repo-wide `mix ash.codegen` is broken — PreorderDeposit identity); trim unrelated drift from the generated migration, and put `null: false` on its own line (Elixir 1.18 CI formatter rejects the one-liner).
- Storefront LiveViews have no catch-all `handle_event/3` — a wrong event name CRASHES the page. Admin Snap LiveView must handle every event its template can emit.
- Conventional commits, `mix test` green before every commit, `mix format` + `mix credo --strict` clean at the end of every task.

---

### Task 1: `snap_verified` attribute + migration

**Files:**
- Modify: `lib/emakola/catalog/resources/product.ex` (attributes block ~line 141, actions block)
- Create: migration via generator
- Test: `test/emakola/catalog/product_snap_verified_test.exs`

**Interfaces:**
- Produces: `Product.snap_verified :: boolean` (default `false`, `allow_nil?: false`); internal update action `:set_snap_verified` accepting `:snap_verified` (system-only, `authorize?: false` callers).

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.Catalog.ProductSnapVerifiedTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  test "defaults to false and is settable via :set_snap_verified" do
    store = insert(:store)
    product = insert(:product, store_id: store.id)
    assert product.snap_verified == false

    {:ok, updated} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id, authorize?: false)
      |> Ash.update()

    assert updated.snap_verified == true
  end
end
```

- [ ] **Step 2: Run it** — `mix test test/emakola/catalog/product_snap_verified_test.exs` — expect FAIL (unknown attribute).

- [ ] **Step 3: Implement.** In `product.ex` attributes block (after `:share_count`):

```elixir
attribute :snap_verified, :boolean do
  allow_nil?(false)
  default(false)
  public?(true)
end
```

In the actions block (near `:increment_share_count`):

```elixir
update :set_snap_verified do
  require_atomic?(false)
  accept([:snap_verified])
end
```

Do NOT add `:snap_verified` to `:create`/`:update` accept lists — merchants must not set it through forms.

- [ ] **Step 4: Generate the migration** — `mix ash_postgres.generate_migrations --domains Emakola.Catalog --name add_snap_verified_to_products`. Trim any unrelated drift. Verify the column line reads across two lines (`null: false` separate). `mix ecto.migrate`, then `mix ecto.rollback && mix ecto.migrate` to prove reversibility.

- [ ] **Step 5: Run test → PASS. Commit** — `feat(catalog): add snap_verified flag to products`

---

### Task 2: badge revocation on image mutations

**Files:**
- Create: `lib/emakola/catalog/changes/revoke_snap_verified.ex`
- Modify: `lib/emakola/catalog/resources/image.ex` (its `create`, `destroy`, and position-updating actions)
- Test: `test/emakola/catalog/snap_verified_revocation_test.exs`

**Interfaces:**
- Consumes: Task 1's `:set_snap_verified`.
- Produces: any mutation that changes which image leads (position 0) on a snap-verified product flips `snap_verified` to `false`. Text edits never touch it.

The change runs as an after-action hook on Image actions: load the product (`authorize?: false`, tenant from the image's `store_id`); if `product.snap_verified`, flip it via `:set_snap_verified`. Fire on: image `destroy`, image `create` (a new image can take position 0), and any action accepting `:position`. Simplicity rule: ANY image add/remove/reorder on a verified product revokes — no "was it really position 0?" hair-splitting; a merchant editing images on a verified product is exactly the moment the promise needs re-earning.

- [ ] **Step 1: Write the failing tests** — matrix, one test each:

```elixir
defmodule Emakola.Catalog.SnapVerifiedRevocationTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = insert(:store)
    product = insert(:product, store_id: store.id)
    {:ok, product} =
      product
      |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: true},
        tenant: store.id, authorize?: false)
      |> Ash.update()
    image = insert(:image, store_id: store.id, product_id: product.id, position: 0)
    %{store: store, product: product, image: image}
  end

  test "destroying an image revokes the badge", %{store: s, product: p, image: i} do
    :ok = i |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: s.id, authorize?: false) |> Ash.destroy()
    assert Ash.get!(Emakola.Catalog.Product, p.id, tenant: s.id, authorize?: false).snap_verified == false
  end

  test "adding an image revokes the badge", %{store: s, product: p} do
    insert_via_action(:image, store_id: s.id, product_id: p.id, position: 0)
    assert Ash.get!(Emakola.Catalog.Product, p.id, tenant: s.id, authorize?: false).snap_verified == false
  end

  test "title edit does NOT revoke", %{store: s, product: p} do
    {:ok, _} =
      p |> Ash.Changeset.for_update(:update, %{title: "New name"}, tenant: s.id, authorize?: false)
      |> Ash.update()
    assert Ash.get!(Emakola.Catalog.Product, p.id, tenant: s.id, authorize?: false).snap_verified == true
  end
end
```

(`insert_via_action` = go through the Image resource's create action, not raw Repo insert — the hook lives on the action. Check `image.ex` for its create action name and required attrs; factory `insert(:image)` bypasses actions, fine for the setup row but not for the mutation under test.)

- [ ] **Step 2: Run → FAIL** (no revocation yet; second test also guards that factory-vs-action distinction is right).

- [ ] **Step 3: Implement the change module**

```elixir
defmodule Emakola.Catalog.Changes.RevokeSnapVerified do
  @moduledoc """
  Any image add/remove/reorder on a snap-verified product revokes the badge.
  The photo is the promise (spec: docs/superpowers/specs/2026-08-05-snap-to-shop-design.md);
  enforcement lives here, in the domain layer, so no UI path can dodge it.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _ctx) do
    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      revoke(result.product_id, result.store_id)
      {:ok, result}
    end)
  end

  defp revoke(nil, _store_id), do: :ok
  defp revoke(product_id, store_id) do
    case Ash.get(Emakola.Catalog.Product, product_id, tenant: store_id, authorize?: false) do
      {:ok, %{snap_verified: true} = product} ->
        product
        |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: false},
          tenant: store_id, authorize?: false)
        |> Ash.update!()
        :ok
      _ -> :ok
    end
  end
end
```

For `destroy` the after_action result is the destroyed record — same fields available. Wire `change(Emakola.Catalog.Changes.RevokeSnapVerified)` into image `create`, `destroy`, and every action that accepts `:position` (read `image.ex` actions block; add to each; destroy may need `require_atomic?(false)`).

- [ ] **Step 4: Run → PASS. Full catalog suite** — `mix test test/emakola/catalog/` (the hook must not break existing image tests; the DeleteImageFiles destroy change already exists on destroy — keep both).

- [ ] **Step 5: Commit** — `feat(catalog): revoke snap_verified on any image mutation`

---

### Task 3: `:snap_to_shop` prompt + schema

**Files:**
- Modify: `lib/emakola/ai/prompts.ex`
- Test: `test/emakola/ai/prompts_test.exs` (extend existing)

**Interfaces:**
- Consumes: `Request` struct (`model/system/messages/max_tokens/response_format/json_schema/thinking`), `@longform_model`, existing `@seo_meta_schema` pattern (`prompts.ex:~100`).
- Produces: `Prompts.build(:snap_to_shop, %{image_url: url, store: store, category_names: [String.t()]})` → `%Request{}`. Parsed output keys (all strings at parse, atoms after caller mapping): `identified`, `title`, `description`, `category`, `tags`, `alt_text`, `photo_flags` (`stock_photo`/`watermark`/`screenshot`).

- [ ] **Step 1: Failing tests**

```elixir
describe "build(:snap_to_shop, ...)" do
  setup do
    store = %{name: "Kente Kingdom", currency: "GHS"}
    req = Emakola.AI.Prompts.build(:snap_to_shop, %{
      image_url: "https://example.com/p.png",
      store: store,
      category_names: ["Fabrics", "Accessories"]
    })
    %{req: req}
  end

  test "uses the longform model with thinking disabled", %{req: req} do
    assert req.model == "claude-sonnet-5"
    assert req.thinking == :disabled
  end

  test "sends the image and the category list", %{req: req} do
    [%{content: content}] = req.messages
    assert %{type: :image, url: "https://example.com/p.png"} in content
    assert Enum.any?(content, &match?(%{type: :text}, &1))
    text = Enum.find_value(content, fn %{type: :text, text: t} -> t; _ -> nil end)
    assert text =~ "Fabrics"
  end

  test "carries the provenance rule and a closed schema", %{req: req} do
    assert req.system =~ "Never invent a material, ingredient, origin"
    assert req.response_format == :json
    assert req.json_schema["additionalProperties"] == false
    assert "photo_flags" in req.json_schema["required"]
  end
end
```

- [ ] **Step 2: Run → FAIL** (`FunctionClauseError` on build/2).

- [ ] **Step 3: Implement.** Follow `@seo_meta_schema`'s shape for a module attribute `@snap_to_shop_schema`:

```elixir
@snap_to_shop_schema %{
  "type" => "object",
  "additionalProperties" => false,
  "required" => ["identified", "title", "description", "category", "tags", "alt_text", "photo_flags"],
  "properties" => %{
    "identified" => %{"type" => "boolean"},
    "title" => %{"type" => "string", "maxLength" => 60},
    "description" => %{"type" => "string"},
    "category" => %{"type" => ["string", "null"]},
    "tags" => %{"type" => "array", "items" => %{"type" => "string"}, "maxItems" => 8},
    "alt_text" => %{"type" => "string", "maxLength" => 125},
    "photo_flags" => %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["stock_photo", "watermark", "screenshot"],
      "properties" => %{
        "stock_photo" => %{"type" => "boolean"},
        "watermark" => %{"type" => "boolean"},
        "screenshot" => %{"type" => "boolean"}
      }
    }
  }
}
```

`build(:snap_to_shop, %{image_url: image_url, store: store, category_names: names})`: system prompt = West-African listing writer + the verbatim provenance sentence + "Describe only what is visible in the photo. If you cannot clearly identify a sellable product, set identified to false and leave other fields empty. Set photo_flags honestly: stock_photo when the image looks professionally staged/catalog-sourced rather than merchant-taken; watermark when any watermark or overlaid logo/text is present; screenshot when the image is a screenshot of another app or listing. category must be exactly one of the provided category names, or null." Message content: `[%{type: :image, url: image_url}, %{type: :text, text: user}]` where user lists store name/currency and the category names. Request: `%Request{model: @longform_model, thinking: :disabled, response_format: :json, json_schema: @snap_to_shop_schema, max_tokens: 1000, system: ..., messages: ...}` (mirror how `:blog_post` composes the longform request; the pricing tripwire already asserts `@longform_model` has a positive pricing entry, so no pricing change is needed).

- [ ] **Step 4: Run prompts + pricing tests → PASS.** `mix test test/emakola/ai/`

- [ ] **Step 5: Commit** — `feat(ai): snap_to_shop vision prompt with closed schema and photo flags`

---

### Task 4: Snap LiveView — route, entry, upload, reading state

**Files:**
- Create: `lib/emakola_web/live/admin/product_live/snap.ex`
- Modify: `lib/emakola_web/router.ex` (merchant scope, next to `live "/admin/products/new"`), `lib/emakola_web/live/admin/product_live/index.ex` (entry button)
- Test: `test/emakola_web/live/admin/product_snap_test.exs`

**Interfaces:**
- Consumes: `Emakola.AI.generate(:snap_to_shop, inputs, store: store, actor_id: merchant.id)`; upload pipeline conventions from `form.ex` (`@upload_opts`, S3 consume — copy its consume/store helper, single image, `max_entries: 1`); `Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)` in tests; `Emakola.AI.ProviderMock` via Mox.
- Produces: states `:capture → :reading → :review | :retry`; assigns `%{state, photo_url, source, ai: %{title, description, category_id, tags, alt_text}, flags_clean?: boolean}`. Task 5 consumes `:review`.

- [ ] **Step 1: Failing tests** (happy path to review; use `@small_png` fixture pattern and Mox `expect` from `product_form_test.exs:1-20`):

```elixir
defmodule EmakolaWeb.Admin.ProductSnapTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mox
  import Emakola.Factory

  @small_png Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
             )

  setup %{conn: conn} do
    {conn, merchant, store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
    %{conn: conn, merchant: merchant, store: store}
  end

  defp ok_payload do
    {:ok, %Emakola.AI.Response{
      parsed: %{
        "identified" => true, "title" => "Handwoven Stole",
        "description" => "A colourful woven stole.", "category" => nil,
        "tags" => ["stole"], "alt_text" => "Colourful woven stole",
        "photo_flags" => %{"stock_photo" => false, "watermark" => false, "screenshot" => false}
      },
      model: "claude-sonnet-5",
      usage: %{input_tokens: 1, output_tokens: 1, cache_read: 0, cache_creation: 0}
    }}
  end

  test "snap → reading → review card shows AI fields and empty price", %{conn: conn} do
    expect(Emakola.AI.ProviderMock, :complete, fn req ->
      assert req.feature == :snap_to_shop
      ok_payload()
    end)

    {:ok, view, _} = live(conn, ~p"/admin/products/snap")
    upload = file_input(view, "#snap-form", :photo, [%{name: "p.png", content: @small_png, type: "image/png"}])
    render_upload(upload, "p.png")
    render_async(view)

    html = render(view)
    assert html =~ "Handwoven Stole"
    assert html =~ "snap-price"          # empty GHS field present
    refute html =~ "Reading"             # left the reading state
  end
end
```

- [ ] **Step 2: Run → FAIL** (route not found).

- [ ] **Step 3: Implement route + entry.** Router (inside the same authenticated merchant `live_session` as `"/admin/products/new"`): `live "/admin/products/snap", Admin.ProductLive.Snap`. Entry button on the Products index header, icon-first, ≤8 words: `📸 Add by photo` — render only when `EmakolaWeb.Admin.SEODashboardLive`-style `ai_enabled?()` is true (extract that ai_enabled?/0 into a small shared helper `EmakolaWeb.AiGate.enabled?/0` rather than duplicating; update the SEO dashboard to call it too — one definition).

- [ ] **Step 4: Implement the LiveView.** Mount: `state: :capture`, `allow_upload(:photo, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 10_000_000, auto_upload: true, progress: &handle_progress/3)`. On upload completion (`handle_progress` with `entry.done?`): consume via the same S3 storage helper the product form uses (copy its consume function; single entry → public URL), record `source` from a hidden `phx-value` on the input wrapper (`:camera` when the capture input was used, `:gallery` otherwise — two overlay inputs: one with `capture="environment"`, one without, both full-size opacity-0 per the iOS pattern), set `state: :reading`, then `start_async(:snap_ai, fn -> Emakola.AI.generate(:snap_to_shop, %{image_url: url, store: store, category_names: names}, store: store, actor_id: merchant.id) end)`. Load `category_names` at mount from the tenant's categories (name list). `handle_async(:snap_ai, {:ok, {:ok, response}}, socket)` → map parsed payload into assigns; `identified: false` or `{:error, _}` or `{:exit, _}` → `state: :retry`. Category name → id mapping: match the AI's `category` string against the mount-loaded list (exact match; nil otherwise). Rate limit BEFORE the AI call: `Emakola.Content.RateLimiter.check_and_increment(store.id)`; on `{:error, :rate_limit_exceeded}` → `state: :retry` with the limit message ("Daily AI limit reached" — 4 words). Template: each state a distinct block; every button's event has a `handle_event/3` clause (no catch-all crashes). Reading state: photo thumbnail + pulsing icon + "Reading your photo…".

- [ ] **Step 5: Run → PASS. Commit** — `feat(web): snap-to-shop capture flow with async vision read`

---

### Task 5: review card → create product (badge award matrix)

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/snap.ex`
- Test: extend `test/emakola_web/live/admin/product_snap_test.exs`

**Interfaces:**
- Consumes: Task 1 `:set_snap_verified`, Product `:create` + `:activate` actions, Variant creation pattern and image-attach pattern from `form.ex` (copy its save path: create product → create default variant with price → attach image record with `url`/`alt_text`/`position: 0`), Task 4 assigns.
- Produces: draft or active product with photo as position-0 image; `snap_verified` set per matrix.

- [ ] **Step 1: Failing tests** — the matrix:

```elixir
test "publish with camera source + clean flags → active product with badge", ctx do
  # drive to :review as in Task 4 (camera input), then:
  view |> form("#snap-review-form", %{"price" => "180.00"}) |> render_submit(%{"action" => "publish"})
  product = last_product!(ctx.store)   # helper: newest product for store, authorize?: false
  assert product.snap_verified and product.status == :active
  assert hd(images_of(product)).position == 0
end

test "gallery source → no badge", ctx do ... assert product.snap_verified == false ... end
test "flagged photo → no badge even from camera", ctx do ... end
test "publish without price → error, no product", ctx do
  view |> form("#snap-review-form", %{"price" => ""}) |> render_submit(%{"action" => "publish"})
  assert render(view) =~ "Add your price"   # 3 words
  assert [] == products_of(ctx.store)
end
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.** Review card template: photo top (`<img src={@photo_url}>`), editable AI fields (title/description/tags/category select from tenant categories), one large `GHS` price input (`inputmode="decimal"`, id `snap-price`), buttons `Save draft` / `Publish`. Submit handler: parse price to pesewas (reuse the form's money parsing helper — find it in `form.ex`'s save path; same rounding), create product via `:create` (tenant + actor), create the default variant with the price, create the Image row (position 0, `alt_text` from AI), then `:activate` when action == "publish" (draft otherwise), then award: `snap_verified = source == :camera and flags_clean?` → `:set_snap_verified` (authorize?: false). Wrap the sequence in `Ash.transaction`/multi so a failed step leaves nothing behind. On success `push_navigate` to the product edit page with a flash ("Product created" — 2 words).

- [ ] **Step 4: Run matrix → PASS. Commit** — `feat(web): snap review card creates products with honest badge award`

---

### Task 6: fake-photo warning + retry states

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/snap.ex`
- Test: extend `test/emakola_web/live/admin/product_snap_test.exs`

- [ ] **Step 1: Failing tests** — flagged payload renders the amber warning on the review card ("Buyers trust real photos" + camera icon) while still allowing publish; `identified: false` payload renders retry state ("Try a clearer photo") with a `Try again` button that returns to `:capture`; provider `{:error, ...}` renders the same retry state.

- [ ] **Step 2: Run → FAIL. Step 3: Implement** — `flags_clean?` already computed in Task 4; warning block on review template when false; `handle_event("retry", ...)` resets to `:capture` (cancel any stale upload entries via `cancel_upload`).

- [ ] **Step 4: PASS. Commit** — `feat(web): snap warning and retry states`

---

### Task 7: "Real photo" storefront badge

**Files:**
- Create: `lib/emakola/themes/shared/real_photo_badge.ex`
- Modify: every theme's ProductDetail module (`lib/emakola/themes/*/product_detail.ex`) — render the badge component near the product title block
- Test: `test/emakola_web/live/storefront/real_photo_badge_test.exs` + structural guard `test/emakola/themes/real_photo_badge_coverage_test.exs`

**Interfaces:**
- Consumes: `@product.snap_verified` (already in PDP assigns — the product struct is loaded for every theme PDP).
- Produces: `Emakola.Themes.Shared.RealPhotoBadge.badge(assigns)` — renders nothing unless `assigns.product.snap_verified`.

- [ ] **Step 1: Failing structural test first** (the fan-out guard, modeled on `no_invented_provenance_test`):

```elixir
defmodule Emakola.Themes.RealPhotoBadgeCoverageTest do
  use ExUnit.Case, async: true

  test "every theme ProductDetail renders the shared RealPhotoBadge" do
    Path.wildcard("lib/emakola/themes/*/product_detail.ex")
    |> Enum.each(fn file ->
      assert File.read!(file) =~ "RealPhotoBadge",
             "#{file} does not render the Real photo badge"
    end)
  end
end
```

- [ ] **Step 2: Run → FAIL listing every theme file.**

- [ ] **Step 3: Implement the component**

```elixir
defmodule Emakola.Themes.Shared.RealPhotoBadge do
  @moduledoc "PDP trust badge for snap-verified products. The photo is the promise."
  use Phoenix.Component

  attr :product, :map, required: true

  def badge(assigns) do
    ~H"""
    <span
      :if={@product.snap_verified}
      class="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700"
      title="Photographed by seller"
    >
      📷 Real photo
    </span>
    """
  end
end
```

Then add `<Emakola.Themes.Shared.RealPhotoBadge.badge product={@product} />` beside the title in each theme's ProductDetail (mechanical; match each theme's markup style; do not restyle anything else — surgical edits only).

- [ ] **Step 4: LiveView render test** — storefront PDP for a verified product shows "Real photo"; after an image mutation (Task 2 revocation), re-render does not. Use one theme (the store factory's default theme) for the render test; the structural test carries the fan-out.

- [ ] **Step 5: Full test suite** — `mix test` (this touches ~20 theme files; the storefront suites must stay green). **Commit** — `feat(themes): Real photo PDP badge across all themes`

---

### Task 8: hardening + docs

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/snap.ex` (direct-route gating), `TODO.md`, `docs/API.md` (note: web-only v1)
- Test: extend `test/emakola_web/live/admin/product_snap_test.exs`

- [ ] **Step 1: Failing tests** — with AI disabled (no key in test env is the default): `/admin/products/snap` renders the same "not switched on" state as the SEO dashboard (no upload input); Products index does not render the entry button. With Mox + rate limit exhausted (`check_and_increment` stubbed via a small limit): retry state with the limit message.

- [ ] **Step 2: Implement** — mount checks `EmakolaWeb.AiGate.enabled?()`; gated template state mirrors `seo_dashboard_live.ex`'s banner.

- [ ] **Step 3: Sweep** — `mix format`, `mix credo --strict`, full `mix test`; `touch` edited files then `mix compile --warnings-as-errors` (incremental compile hides unused-require warnings that fail CI on 1.20).

- [ ] **Step 4: Update TODO.md** — tick Snap-to-Shop's PLANNED entry to "✅ specced → implemented (PR pending)". **Commit** — `feat(web): gate snap flow behind AI config + docs`

---

## Execution notes

- Tasks 1→2→3 are domain groundwork and can be reviewed independently; 4→5→6 build one LiveView incrementally; 7 is wide but mechanical; 8 closes.
- The dev environment has no ANTHROPIC_API_KEY — every dev/test path runs gated or mocked; a prod smoke (one real snap on a demo store) is the final acceptance step after deploy.
- Do NOT run `mix phx.server` while implementing (hot-reload race corrupts _build).
