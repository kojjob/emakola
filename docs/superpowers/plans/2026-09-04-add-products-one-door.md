# Add Products One Door Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/admin/products/new` becomes the only way to add a product: one photo tile, one card model (a photo card or a typed card), category and description opening inside the card, AI "Fill it in" on the photo, the spreadsheet one tap away. The typed create form, the snap page, and the "Add by photo" entries on Products and Dashboard go.

**Architecture:** Everything lands in the existing `EmakolaWeb.Admin.ProductLive.AddProducts` LiveView and its `AddProductsComponents`. Cards are keyed `"camera-<ref>"`, `"photos-<ref>"` or `"typed-<n>"`; a card's fields live in `@cards`, its AI result in `@ai`, its open/closed More row in `@open`. The snap page's AI plumbing (photo to S3, `Emakola.AI.generate(:snap_to_shop, ...)`, category resolution, photo-flag check, badge award) moves into `AddProducts` as a per-card async; the snap page and the typed create path are deleted. AI descriptions after publish are already handled by `BackfillDescription` on `:create` (PR #604/#605), so there is no "Write it for me" button.

**Tech Stack:** Phoenix LiveView 1.x (uploads, `start_async`), Ash 3.x (`Emakola.Catalog`), Mox (`Emakola.AI.ProviderMock`, `Emakola.StorageMock`), Playwright (`e2e/tests/add-products.spec.ts`).

**Spec:** `design/add-products-one-door/` (canvas https://claude.ai/code/artifact/e74a578b-9d29-47e9-9acf-a8da3d3d7a05, README lists what moves where).

## Global Constraints

- Copy under eight words per line; no emoji anywhere (Kojo, 2026-08-30).
- Prices are integers in pesewas; display through `EmakolaWeb.Helpers.Currency`.
- `store_id` always comes from `socket.assigns.current_store`, never from the client.
- Both upload configs stay (`:camera` carries `capture="environment"`, `:photos` does not); every file input stays a full-size `opacity-0` overlay inside its label (iOS Safari).
- `mix format`, `mix credo --strict`, `mix dialyzer`, `mix test` green before every commit; CI compiles tests with `--warnings-as-errors`.
- One deviation from the canvas, on purpose: "Upload a spreadsheet" still navigates to `/admin/products?upload=csv` (the sheet slides over the list, where the imported products appear). A typed card's photo slot is static ("No photo yet"); a photo is added on the edit page.

---

### Task 1: One tile, typed cards, one header

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/add_products_components.ex` (`add_products_header`, `entry_links`, `capture_tiles`, `photo_card`, `card_badge`)
- Modify: `lib/emakola_web/live/admin/product_live/add_products.ex` (mount assigns, `photo_items`, `card_key`, events)
- Test: `test/emakola_web/live/admin/product_live/add_products_test.exs`

**Interfaces:**
- Produces: item map gains `source: :camera | :photos | :typed` and `entry: entry | nil`; `card_key/2` accepts `"typed"`; new event `"add_typed_card"`; `"remove_photo"` also removes a typed card (`upload: "typed"`); header title `"N items"`.

- [ ] **Step 1: Write the failing tests** (replace the "start" describe and adjust "cards")

```elixir
describe "start" do
  test "one tile: the camera under the thumb, the gallery in a pill", %{conn: conn} do
    {:ok, view, html} = live(conn, "/admin/products/new")
    assert html =~ "Add products"
    assert html =~ "Add photos"
    assert has_element?(view, "#gallery-pill", "Gallery")
    refute html =~ "Take a photo"
    refute html =~ "Choose photos"
  end

  test "typing a product is a card on this page, not another form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/products/new")
    refute has_element?(view, ~s{a[href="/admin/products/new/form"]})
    view |> element("button", "Type it in") |> render_click()
    assert has_element?(view, ~s{#card-typed-1[data-state="untouched"]})
    assert render(view) =~ "No photo yet"
    assert render(view) =~ "1 item"
  end

  test "the spreadsheet stays one tap away", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/products/new")
    assert has_element?(view, ~s{a[href="/admin/products?upload=csv"]})
  end
  # keep: old bulk address; both inputs are overlays (camera has capture)
end
```
In "cards": `"2 photos"` becomes `"2 items"`, `"1 photo"` becomes `"1 item"`. Add:
```elixir
test "a typed card with a name and price is ready and publishes without a photo", ... do
  # add_typed_card, set_card(upload: "typed", ref: "1", ...), submit, assert product exists with no images
end
test "removing a typed card drops it", ... do
  view |> render_hook("remove_photo", %{"upload" => "typed", "ref" => "1"})
  refute has_element?(view, "#card-typed-1")
end
```

- [ ] **Step 2: Run** `mix test test/emakola_web/live/admin/product_live/add_products_test.exs` — expect the new tests to fail.

- [ ] **Step 3: Implement.** Components: `capture_tiles` renders ONE tile: a `<div id="photo-tile">` with the `.ShrinkPhotos` colocated hook script once, a `<label id="camera-tile" phx-hook=".ShrinkPhotos">` filling the tile (camera input, `capture="environment"`) and a `<label id="gallery-pill" phx-hook=".ShrinkPhotos">` absolutely positioned bottom-right (photos input). Compact variant: 72px strip "Add more" + the pill. Beside it a `<button type="button" phx-click="add_typed_card">Type it in</button>` (54px on phone under an "or" rule at capture stage; a dashed 110px tile on desktop; a quiet button in the compact strip row). `entry_links` shrinks to the spreadsheet link: desktop header button "Upload a spreadsheet", phone text "Have a spreadsheet? Upload it". `photo_card`: when `@item.entry` is nil render a dashed slot with a camera icon and "No photo yet" instead of `live_img_preview`; the remove button and badge stay. Header: `"#{n} item(s)"`.
  LiveView: assigns `typed: []`, `typed_seq: 0`; `@sources [:camera, :photos, :typed]`; `photo_items/3` becomes `photo_items(uploads, cards, consumed, typed)` appending typed items (`entry: nil`, `source: :typed`, `key: "typed-#{n}"`, `ref: "#{n}"`); `card_key/2` maps `"typed"`; `remove_photo` with `:typed` drops the key from `typed` and `cards`; publish: `attach_photos` skips typed items; after publish drop published typed keys from `typed`.

- [ ] **Step 4: Run the file** — green. **Step 5: Commit** `feat(web): adding a product is one tile and one card, typed or photographed`.

### Task 2: More, inside the card

**Files:**
- Modify: `add_products_components.ex` (new `more_row/1`, `photo_card` renders it), `add_products.ex` (`toggle_more`, `set_card` for `category_id`/`description`, publish attrs), `shared.ex` (`load_store_categories/1` moved from `form.ex`/`snap.ex`)
- Test: `add_products_test.exs`

**Interfaces:**
- Produces: events `"toggle_more"` (`upload`, `ref`), `"set_card"` accepting `field` in `[:name, :price, :category_id, :description]`; assigns `open :: MapSet`, `categories :: [Category]`; item gains `open?`, `description`, `category_id`, `category_name`.
- `Shared.load_store_categories(store_id) :: [Category.t()]` (rescues and logs, returns `[]`).

- [ ] **Step 1: Failing tests**

```elixir
describe "more" do
  test "More opens in place with the store's categories and a description field", %{conn: conn, store: store} do
    category = Emakola.Factory.create_category!(store, %{name: "Beauty"})   # check factory name
    {:ok, view, _html} = live(conn, "/admin/products/new")
    [ref] = upload_photos(view, ["gloss.png"])
    refute has_element?(view, "#card-photos-#{ref} textarea")
    view |> element("#more-photos-#{ref}") |> render_click()
    assert has_element?(view, "#card-photos-#{ref} textarea[name=card_description]")
    assert has_element?(view, ~s{#card-photos-#{ref} button[data-category="#{category.id}"]}, "Beauty")
  end

  test "a chosen category shows on the closed row and both fields are saved", ... do
    set_card(view, ref, "category_id", category.id); set_card(view, ref, "description", "Six shades.")
    view |> element("#more-photos-#{ref}") |> render_click()   # close
    assert has_element?(view, "#more-photos-#{ref}", "Beauty")
    # publish; product.category_id == category.id, description == "Six shades.", description_written_by_ai == false
  end
end
```

- [ ] **Step 2: Run, fail. Step 3: Implement.** `more_row`: 44px button `id={"more-#{key}"}` `phx-click="toggle_more"` with bars icon, "More", the category name pill when closed, chevron; open body: "Category" eyebrow + chips (`button type="button" phx-click="set_card" phx-value-field="category_id" phx-value-value={id} data-category={id}`; tapping the selected one sends `""`), "Description" eyebrow + `<textarea name="card_description" phx-blur="set_card" phx-value-field="description">` placeholder `"Leave it, Makola writes one"` when `@ai_enabled` else `"Say more about it"`. Publish attrs: `%{title:, store_id:, description: blank_to_nil(description), category_id: blank_to_nil(category_id)}`. Mount: `categories: Shared.load_store_categories(store.id)`, `ai_enabled: EmakolaWeb.AiGate.enabled?()`.

- [ ] **Step 4: green. Step 5: Commit** `feat(web): category and description open inside the card`.

### Task 3: Fill it in

**Files:**
- Modify: `add_products.ex` (`fill_card` event, `handle_async({:fill, key}, ...)`, publish: alt text, AI description via `:backfill_description`, badge), `add_products_components.ex` (pill on the photo, "Reading…" state, amber line), `shared.ex` (`upload_snap_photo/3` moved from snap; `store_product_image/5` gains `alt_text:` option)
- Test: `test/emakola_web/live/admin/product_live/add_products_fill_test.exs` (async: false, sets `:anthropic_api_key`)

**Interfaces:**
- Produces: assign `ai :: %{key => %{alt_text, flags_clean?: bool, wrote: MapSet}}`, `filling :: MapSet`; item gains `filling?`, `wrote_name?`, `ai_ready?`; `Shared.upload_snap_photo(store_id, tmp_path, entry) :: url | nil`; `Shared.store_product_image(store_id, product_id, tmp_path, entry, alt_text: text)`.

- [ ] **Step 1: Failing tests** (mirror `product_snap_test.exs` helpers: `ok_payload/0`, `flagged_payload/0`, `not_identified_payload/0`, `stub_storage/0`, `Mox.allow` both mocks to `view.pid`, `render_async(view, 2_000)`)

```elixir
test "Fill it in reads the photo into the card and says Makola wrote the name"
  # click #fill-photos-<ref>; expect ProviderMock :complete with req.feature == :snap_to_shop;
  # name field value "Handwoven Stole", textarea "A colourful woven stole.", html =~ "Makola wrote this"
test "a photo the AI cannot read leaves the card alone and says so"  # flash "Try a clearer photo"
test "past the daily AI limit the pill says so and no call is made"   # RateLimiter to the cap first
test "no key, no pill"                                                 # delete env; refute #fill-
test "a camera photo the AI found clean earns the badge on publish; a gallery one does not"
test "a description the AI wrote is saved as AI-written; one the merchant edits is theirs"
```

- [ ] **Step 2: Run, fail. Step 3: Implement.**
```elixir
def handle_event("fill_card", %{"upload" => upload, "ref" => ref}, socket) do
  with {:ok, name, key} when name != :typed <- card_key(upload, ref),
       false <- MapSet.member?(socket.assigns.filling, key),
       :ok <- Emakola.Content.RateLimiter.check_and_increment(socket.assigns.store_id),
       url when is_binary(url) <- snap_photo_url(socket, name, ref) do
    {:noreply, socket |> update(:filling, &MapSet.put(&1, key)) |> start_async({:fill, key}, fn -> Emakola.AI.generate(:snap_to_shop, %{image_url: url, store: store, category_names: names}, store: store, actor_id: merchant_id) end)}
  else
    {:error, :rate_limit_exceeded} -> {:noreply, put_flash(socket, :error, "Daily AI limit reached")}
    _ -> {:noreply, put_flash(socket, :error, "Try a clearer photo")}
  end
end
# snap_photo_url: consume_uploaded_entry with {:postpone, Shared.upload_snap_photo(store_id, path, entry)} on the matching entry
def handle_async({:fill, key}, {:ok, {:ok, %Emakola.AI.Response{parsed: %{"identified" => true} = p}}}, socket) — fill empty name/description/category_id, record ai[key]
def handle_async({:fill, key}, _other, socket) — clear filling, flash "Try a clearer photo"
```
Publish: name/description fields the merchant edits after the fill drop out of `wrote` (in `set_card`). `create_product/2`: if `:description in wrote`, create without description then `Ash.Changeset.for_update(product, :backfill_description, %{description: d}) |> Ash.update(authorize?: false)`. `attach_photos`: pass `alt_text: ai.alt_text` when present. After attach: `award_badge(product, store_id)` when `item.source == :camera and ai.flags_clean?` — `:set_snap_verified` with `authorize?: false` (policy forbids every actor), and it must run AFTER the image is attached (image create revokes the badge). Components: `fill_pill` on the photo `id={"fill-#{key}"}` `phx-click="fill_card"` shown when `@ai_enabled and not @item.ai_ready? and @item.entry`; label "Reading…" and `disabled` while `filling?`; amber line under the name when `wrote_name?`: "Makola wrote this. Change what is wrong."

- [ ] **Step 4: green. Step 5: Commit** `feat(web): the AI reads a photo into its card, badge and all`.

### Task 4: The snap page and the "Add by photo" doors go

**Files:**
- Delete: `lib/emakola_web/live/admin/product_live/snap.ex`, `test/emakola_web/live/admin/product_snap_test.exs`
- Modify: `lib/emakola_web/router.ex` (drop `/admin/products/snap`), `product_live/index.ex` (header: one button), `product_live/index_components.ex` (one empty state), `dashboard/dashboard_components.ex` (drop the quick action), tests `product_live_test.exs` (empty-state asserts), `dashboard_live_test.exs` (two snap tests)

- [ ] Tests first: `refute has_element?(view, ~s{a[href="/admin/products/snap"]})` on Products (AI on) and Dashboard; empty state always links `/admin/products/new`. Then delete/modify. Commit `refactor(web): the snap page folds into the cards; one door on Products and Dashboard`.

### Task 5: The typed create form goes

**Files:**
- Modify: `router.ex` (drop `/admin/products/new/form`), `product_live/form.ex` (edit-only: remove the `:new` mount clause, `empty_form_data/0`, the create branch of `save_product`, `is_edit` conditionals), tests `product_form_test.exs`, `product_live_test.exs` (Form describes), `title_example_test.exs`

- [ ] Convert create-only tests to their edit equivalents where the behaviour is shared (price field on a variant-less draft, product type persisted on edit, image upload on edit, storage failure on edit, title example on edit); delete the rest. Commit `refactor(web): the product form only edits; creating is the cards page`.

### Task 6: Browser check and quality gates

- [ ] `e2e/tests/add-products.spec.ts`: keep the overlay test (parents are now the tile label and the pill label), the shrink test, the counting test (title "items"); add "Type it in makes a card without a photo".
- [ ] `mix format && mix credo --strict && mix dialyzer && mix test` green; `npx playwright test e2e/tests/add-products.spec.ts` if the dev DB is up.
- [ ] Push and open the PR against `main`.
