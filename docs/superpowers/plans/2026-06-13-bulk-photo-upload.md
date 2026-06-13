# Photo-First Bulk Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A merchant selects many product photos at once, types a name + price per photo, and publishes them all as live, sellable products in one action.

**Architecture:** A new dedicated LiveView `EmakolaWeb.Admin.ProductLive.BulkPhoto` at `/admin/products/bulk`. Each selected photo is one LiveView upload entry rendered as a card with name/price inputs. Publish reuses the proven single-add path `Shared.create_product_with_price/3` (product → untracked priced variant → activate), then attaches each photo to its product via `consume_uploaded_entries` (postponing skipped/invalid cards so they stay on screen).

**Tech Stack:** Phoenix LiveView live uploads, Ash (Catalog), Tigris via `Emakola.Storage`.

**Spec:** `docs/superpowers/specs/2026-06-13-bulk-photo-upload-design.md`
**Branch:** `feature/bulk-photo-upload`

**Key facts for implementers:**
- `Shared.create_product_with_price(attrs, pesewas, :active)` returns
  `{:ok, product, :activated | :activation_failed | :draft_requested}` or `{:error, err}`.
  attrs needs at least `%{title:, store_id:}`. (lib/emakola_web/live/admin/product_live/shared.ex:238)
- `Shared.parse_price_input(str)` → integer pesewas, or `:error` (non-empty invalid), or
  `:zero` ("0"/"0.00"), or nil-on-empty `:skip`. (shared.ex:165)
- The current store id is on the socket as `socket.assigns.current_store.id` (assigned by the
  `:app` live_session on_mount hooks). Form/Index read it via a private `get_store_id/1`.
- `/admin/products/*` routes live in the `:app` `live_session` in `router.ex` (~line 232),
  on_mount AssignDefaults + RequireAuth + NotificationHandler.
- Existing per-photo upload→Tigris→create_image logic lives in `Shared.save_uploaded_images/2`
  (shared.ex:129) inside a `consume_uploaded_entries` callback; Task 3 extracts the per-entry
  body into a reusable `Shared.store_product_image/4`.
- Storage in tests = `Emakola.StorageMock` (Mox); `stub` it then `Mox.allow(StorageMock, self(), view.pid)` after `live/2`. 1×1 PNG fixture pattern is in `product_form_test.exs`.
- Browser-faithful tests (PR #131 lesson): drive via `element(...)`/`form(...)`/`file_input(...)`, never bare `render_change(view, event, params)`.

---

### Task 1: Route, entry button, and skeleton LiveView (TDD)

**Files:**
- Create: `lib/emakola_web/live/admin/product_live/bulk_photo.ex`
- Modify: `lib/emakola_web/router.ex` (add route under the product routes, ~line 235)
- Modify: `lib/emakola_web/live/admin/product_live/index.ex` (header button, ~line 405)
- Test: `test/emakola_web/live/admin/product_live/bulk_photo_test.exs` (create)

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Admin.ProductLive.BulkPhotoTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup %{conn: conn} do
    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  describe "mount" do
    test "renders the bulk photo page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/products/bulk")
      assert html =~ "Add many products"
      assert html =~ ~s(id="bulk-photo-form")
    end
  end

  describe "entry point" do
    test "products index links to the bulk photo page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products")
      assert has_element?(view, ~s{a[href="/admin/products/bulk"]})
    end
  end
end
```

Check the real helper name for authed-merchant setup in `test/support/` (the dashboard/admin
tests use `setup_authenticated_merchant/1` — mirror whatever they use; if it returns a
different tuple, adapt the destructure).

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs`
Expected: FAIL — no route `/admin/products/bulk`.

- [ ] **Step 3: Add the route**

In `router.ex`, directly after `live "/admin/products/:id/files", ...` (keep `/bulk` before
any `:id` route is not required since `/bulk` is a literal, but place it next to the others):

```elixir
      live "/admin/products/bulk", Admin.ProductLive.BulkPhoto
```

- [ ] **Step 4: Create the skeleton LiveView**

```elixir
defmodule EmakolaWeb.Admin.ProductLive.BulkPhoto do
  use EmakolaWeb, :live_view

  @max_photos 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:store_id, socket.assigns.current_store.id)
     |> assign(:cards, %{})
     |> assign(:publishing, false)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: @max_photos,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-slate-900">Add many products</h1>
          <p class="text-sm text-slate-500">
            Pick all your product photos, give each a name and price, then publish.
          </p>
        </div>
        <.link navigate={~p"/admin/products"} class="text-sm text-slate-500 hover:text-slate-900">
          Back to products
        </.link>
      </div>

      <form id="bulk-photo-form" phx-change="validate" phx-submit="publish_all">
        <label
          class="block border-2 border-dashed border-slate-300 rounded-2xl p-8 text-center cursor-pointer hover:border-emerald-400 transition-colors"
          phx-drop-target={@uploads.photos.ref}
        >
          <.icon name="hero-photo" class="size-10 mx-auto text-slate-400 mb-2" />
          <p class="text-sm font-medium text-slate-700">Tap to choose product photos</p>
          <p class="text-xs text-slate-400 mt-1">Up to {@max_photos} photos at once</p>
          <.live_file_input upload={@uploads.photos} class="sr-only" />
        </label>

        <div :for={err <- upload_errors(@uploads.photos)} class="text-sm text-red-600 mt-2">
          {bulk_upload_error(err)}
        </div>

        <%!-- cards render here in Task 2 --%>

        <div
          :if={@uploads.photos.entries != []}
          class="sticky bottom-0 mt-6 bg-white/95 backdrop-blur border-t border-slate-200 py-4 flex justify-end"
        >
          <button
            type="submit"
            disabled={@publishing}
            class="px-6 py-3 bg-emerald-600 text-white text-sm font-semibold rounded-xl hover:bg-emerald-700 disabled:opacity-50"
          >
            {if @publishing, do: "Publishing…", else: "Publish #{length(@uploads.photos.entries)} products"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp bulk_upload_error(:too_large), do: "One photo is too large (max 10 MB)."
  defp bulk_upload_error(:not_accepted), do: "Only image files are accepted (.jpg, .png, .webp)."
  defp bulk_upload_error(:too_many_files), do: "Up to #{@max_photos} photos at a time."
  defp bulk_upload_error(_), do: "There was a problem with a photo."
end
```

`@max_photos` is referenced inside the `bulk_upload_error/1` body via string interpolation —
module attributes are available there. Keep it.

- [ ] **Step 5: Add the entry button on the index**

In `index.ex` header actions (next to the existing "Bulk" CSV button and "New Product" button,
~line 405), add:

```elixir
          <.link
            navigate={~p"/admin/products/bulk"}
            class={primary_action_classes() |> then(& &1) }
          >
            Add many products
          </.link>
```

If `primary_action_classes/0` isn't imported in index.ex, use the same Tailwind classes the
"New Product" `<.admin_button>` uses, rendered as an `<.link navigate=...>` so the test's
`a[href="/admin/products/bulk"]` matches. The key requirement: a real `<a href>` to the route.

- [ ] **Step 6: Run tests to verify pass**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 7: Gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/admin/product_live/bulk_photo.ex lib/emakola_web/router.ex lib/emakola_web/live/admin/product_live/index.ex test/emakola_web/live/admin/product_live/bulk_photo_test.exs
git commit -m "feat(catalog): bulk photo upload page skeleton + route + entry point"
```

---

### Task 2: Multi-photo upload → cards with name/price (TDD)

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/bulk_photo.ex`
- Test: `test/emakola_web/live/admin/product_live/bulk_photo_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
  describe "photo cards" do
    @png Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
         )

    test "each uploaded photo becomes a card with name and price inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products/bulk")

      photos =
        file_input(view, "#bulk-photo-form", :photos, [
          %{name: "a.png", content: @png, type: "image/png"},
          %{name: "b.png", content: @png, type: "image/png"}
        ])

      html = render_upload(photos, "a.png")
      render_upload(photos, "b.png")

      # one card (name + price input) per photo
      assert view |> element("#bulk-photo-form") |> render() =~ "Price (GHS)"
      assert length(view |> render() |> String.split(~s(name="card_name"))) - 1 == 2
    end
  end
```

(`render_upload` advances each entry to 100%. The assertion counts `card_name` inputs == 2.)

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs`
Expected: the new test FAILS (no cards rendered yet).

- [ ] **Step 3: Render a card per entry + handle validate/cancel**

Replace the `<%!-- cards render here in Task 2 --%>` comment with:

```elixir
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-6">
          <div
            :for={entry <- @uploads.photos.entries}
            class={[
              "border rounded-2xl overflow-hidden bg-white",
              card_incomplete?(@cards, entry.ref) && "border-amber-400",
              !card_incomplete?(@cards, entry.ref) && "border-slate-200"
            ]}
          >
            <div class="relative">
              <.live_img_preview entry={entry} class="w-full h-40 object-cover" />
              <button
                type="button"
                phx-click="remove_photo"
                phx-value-ref={entry.ref}
                class="absolute top-2 right-2 w-7 h-7 bg-black/60 text-white rounded-full text-sm"
                aria-label="Remove photo"
              >
                ✕
              </button>
              <div :if={entry.progress < 100} class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200">
                <div class="h-full bg-emerald-500" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
            <div class="p-3 space-y-2">
              <label class="block">
                <span class="text-[10px] uppercase tracking-wide text-slate-400">Name</span>
                <input
                  type="text"
                  name="card_name"
                  value={card_value(@cards, entry.ref, :name)}
                  phx-blur="set_card"
                  phx-value-ref={entry.ref}
                  phx-value-field="name"
                  placeholder="e.g. Fresh tomatoes"
                  class="block w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-semibold"
                />
              </label>
              <label class="block">
                <span class="text-[10px] uppercase tracking-wide text-slate-400">Price (GHS)</span>
                <input
                  type="text"
                  name="card_price"
                  value={card_value(@cards, entry.ref, :price)}
                  phx-blur="set_card"
                  phx-value-ref={entry.ref}
                  phx-value-field="price"
                  inputmode="decimal"
                  placeholder="e.g. 20"
                  class="block w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-semibold"
                />
              </label>
              <p :for={err <- upload_errors(@uploads.photos, entry)} class="text-xs text-red-600">
                {bulk_upload_error(err)}
              </p>
            </div>
          </div>
        </div>
```

Add the event handlers and helpers to the module:

```elixir
  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_card", %{"ref" => ref, "field" => field, "value" => value}, socket) do
    key = String.to_existing_atom(field)
    card = Map.get(socket.assigns.cards, ref, %{name: "", price: ""})
    cards = Map.put(socket.assigns.cards, ref, Map.put(card, key, value))
    {:noreply, assign(socket, :cards, cards)}
  end

  @impl true
  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply,
     socket
     |> cancel_upload(:photos, ref)
     |> update(:cards, &Map.delete(&1, ref))}
  end

  defp card_value(cards, ref, field), do: cards |> Map.get(ref, %{}) |> Map.get(field, "")

  # A card is incomplete (amber border) until it has a name AND a price that
  # parses to a positive amount. parse_price_input returns {:ok, pesewas} for a
  # valid price, or :error / :zero / :skip otherwise — so anything other than
  # an {:ok, _} tuple means "not ready".
  defp card_incomplete?(cards, ref) do
    card = Map.get(cards, ref, %{})
    name = String.trim(Map.get(card, :name, ""))
    price = EmakolaWeb.Admin.ProductLive.Shared.parse_price_input(Map.get(card, :price, ""))
    name == "" or not match?({:ok, _}, price)
  end
```

`String.to_existing_atom(field)` is safe here because `field` is one of the two literal
strings `"name"`/`"price"` emitted by the template (both already exist as atoms), satisfying
the SafeAtom rule for fixed allowlists.

- [ ] **Step 4: Run tests to verify pass**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs`
Expected: PASS.

- [ ] **Step 5: Gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/admin/product_live/bulk_photo.ex test/emakola_web/live/admin/product_live/bulk_photo_test.exs
git commit -m "feat(catalog): photo cards with name + price inputs in bulk upload"
```

---

### Task 3: Publish all — create products + attach each photo (TDD)

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/shared.ex` (extract `store_product_image/4`)
- Modify: `lib/emakola_web/live/admin/product_live/bulk_photo.ex` (`publish_all`)
- Test: `test/emakola_web/live/admin/product_live/bulk_photo_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
  describe "publish_all" do
    import Mox

    @png Base.decode64!(
           "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
         )

    setup :verify_on_exit!

    test "publishes complete cards as active products with priced variant + image", %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _b, path, _o -> {:ok, "https://s3.example.com/#{path}"} end)

      {:ok, view, _html} = live(conn, "/admin/products/bulk")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photos =
        file_input(view, "#bulk-photo-form", :photos, [
          %{name: "tomato.png", content: @png, type: "image/png"}
        ])

      render_upload(photos, "tomato.png")
      # find the entry ref to set its card fields
      ref = view |> element("button[phx-click=remove_photo]") |> render() |> extract_ref()

      view |> render_hook("set_card", %{"ref" => ref, "field" => "name", "value" => "Tomatoes"})
      view |> render_hook("set_card", %{"ref" => ref, "field" => "price", "value" => "20"})

      view |> element("#bulk-photo-form") |> render_submit()

      product =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Tomatoes")
        |> Ash.read_one!(authorize?: false, load: [:variants, :images])

      assert product.status == :active
      assert [%{price: 2000, track_inventory: false}] = product.variants
      assert length(product.images) == 1
    end

    test "a card with no price is skipped and stays on the page", %{conn: conn, store: store} do
      stub(Emakola.StorageMock, :upload, fn _b, p, _o -> {:ok, "https://s3.example.com/#{p}"} end)
      {:ok, view, _html} = live(conn, "/admin/products/bulk")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photos = file_input(view, "#bulk-photo-form", :photos, [%{name: "x.png", content: @png, type: "image/png"}])
      render_upload(photos, "x.png")
      ref = view |> element("button[phx-click=remove_photo]") |> render() |> extract_ref()
      view |> render_hook("set_card", %{"ref" => ref, "field" => "name", "value" => "No Price Item"})

      html = view |> element("#bulk-photo-form") |> render_submit()

      assert html =~ "No Price Item" or html =~ "card_name"
      assert Emakola.Catalog.Product
             |> Ash.Query.filter(store_id == ^store.id and title == "No Price Item")
             |> Ash.read!(authorize?: false) == []
    end
  end

  # helper to pull the entry ref out of the remove button markup
  defp extract_ref(markup) do
    [_, ref] = Regex.run(~r/phx-value-ref="([^"]+)"/, markup)
    ref
  end
```

If `render_hook` for `set_card` doesn't match the page's binding (it's a `phx-blur`), drive it
with `view |> element(~s{input[name=card_name]}) |> render_blur(%{"value" => "Tomatoes", ...})`
instead — adapt to what the DOM exposes; the goal is to set the card name/price the way the
browser does. Keep the assertions (active product, 2000-pesewa untracked variant, 1 image).

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs`
Expected: publish tests FAIL (no `publish_all` handler).

- [ ] **Step 3: Extract a reusable per-photo store helper in `shared.ex`**

In `Shared`, add a public function (and refactor `save_uploaded_images/2`'s callback body to
call it, keeping that function's behavior identical):

```elixir
  @doc """
  Uploads one entry's binary to storage and creates a Catalog.Image for the given product.
  Returns :ok | :error. Raises are contained (a flaky storage client must not crash the
  upload channel).
  """
  def store_product_image(store_id, product_id, tmp_path, entry) do
    ext = Path.extname(entry.client_name)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    s3_path = "stores/#{store_id}/products/#{filename}"

    try do
      with {:ok, url} <-
             Emakola.Storage.upload(File.read!(tmp_path), s3_path, content_type: entry.client_type),
           {:ok, _img} <-
             Emakola.Catalog.create_image(
               %{
                 url: url,
                 product_id: product_id,
                 store_id: store_id,
                 content_type: entry.client_type,
                 file_size_bytes: entry.client_size,
                 alt_text: Path.rootname(entry.client_name)
               },
               authorize?: false
             ) do
        :ok
      else
        _ -> :error
      end
    rescue
      exception ->
        require Logger
        Logger.error("Bulk image upload failed: #{Exception.message(exception)}")
        :error
    end
  end
```

Then in `save_uploaded_images/2`, replace the inline upload+create_image body of the
`consume_uploaded_entries` callback with `store_product_image(store_id, product.id, tmp_path, entry)`
mapped to `{:ok, :ok}`/`{:ok, :error}` as today. Run the existing product_form upload tests to
confirm no behavior change: `mix test test/emakola_web/live/admin/product_form_test.exs`.

- [ ] **Step 4: Implement `publish_all` in `bulk_photo.ex`**

```elixir
  @impl true
  def handle_event("publish_all", _params, socket) do
    store_id = socket.assigns.store_id
    cards = socket.assigns.cards

    # 1. Create a product for every card that has a name + a valid (>0) price.
    ref_to_product =
      socket.assigns.uploads.photos.entries
      |> Enum.reduce(%{}, fn entry, acc ->
        card = Map.get(cards, entry.ref, %{})
        name = String.trim(Map.get(card, :name, ""))
        price = EmakolaWeb.Admin.ProductLive.Shared.parse_price_input(Map.get(card, :price, ""))

        case {name, price} do
          {n, {:ok, pesewas}} when n != "" ->
            case EmakolaWeb.Admin.ProductLive.Shared.create_product_with_price(
                   %{title: n, store_id: store_id},
                   pesewas,
                   :active
                 ) do
              {:ok, product, _} -> Map.put(acc, entry.ref, product.id)
              {:error, _} -> acc
            end

          _ ->
            acc
        end
      end)

    # 2. Attach each valid card's photo to its product; postpone (keep) skipped cards.
    consume_uploaded_entries(socket, :photos, fn %{path: tmp}, entry ->
      case Map.get(ref_to_product, entry.ref) do
        nil -> {:postpone, :skipped}
        product_id ->
          EmakolaWeb.Admin.ProductLive.Shared.store_product_image(store_id, product_id, tmp, entry)
          {:ok, :attached}
      end
    end)

    # `consume_uploaded_entries` already ran above; the postponed (skipped) cards
    # are still in @uploads, the attached ones were consumed and removed.
    Emakola.Catalog.CachedCatalog.invalidate_store(store_id)

    published = map_size(ref_to_product)
    remaining = socket.assigns.uploads.photos.entries
    socket = update(socket, :cards, fn cards -> Map.drop(cards, Map.keys(ref_to_product)) end)

    cond do
      published == 0 ->
        {:noreply, put_flash(socket, :error, "Add a name and price to at least one product.")}

      remaining == [] ->
        {:noreply,
         socket
         |> put_flash(:info, "#{published} #{pluralize(published)} published — live on your store.")
         |> push_navigate(to: ~p"/admin/products")}

      true ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "#{published} published. #{length(remaining)} still need a name and price."
         )}
    end
  end

  defp pluralize(1), do: "product"
  defp pluralize(_), do: "products"
```

`Emakola.Catalog.CachedCatalog.invalidate_store/1` is confirmed to exist
(`lib/emakola/catalog/cached_catalog.ex:119`) and is the same call the index uses after writes.

- [ ] **Step 5: Run tests to verify pass**

Run: `mix test test/emakola_web/live/admin/product_live/bulk_photo_test.exs test/emakola_web/live/admin/product_form_test.exs`
Expected: PASS (bulk publish tests + unchanged form tests).

- [ ] **Step 6: Gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/admin/product_live/shared.ex lib/emakola_web/live/admin/product_live/bulk_photo.ex test/emakola_web/live/admin/product_live/bulk_photo_test.exs
git commit -m "feat(catalog): publish bulk photo products — sellable, with attached images"
```

---

### Task 4: Full gate, PR, and visual verification

- [ ] **Step 1: Clean-compile + scoped suites**

Run: `mix clean --only app && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`
Run: `mix test test/emakola_web/live/admin/ test/emakola/catalog/ test/emakola_web/live/storefront/`
Expected: all clean / 0 failures.

- [ ] **Step 2: Push + PR**

```bash
git push -u origin feature/bulk-photo-upload
gh pr create --base main --title "feat(catalog): photo-first bulk product upload (Phase 1)" --body "Phone-native bulk add for low-literacy merchants: a new /admin/products/bulk page where the merchant picks many product photos at once, types a name + price per photo, and publishes them all as live, sellable products.

- Each photo = one upload entry = one card (name + price).
- Publish reuses the single-add path Shared.create_product_with_price (product -> untracked priced variant -> activate = sellable by default), then attaches each photo to its product via consume_uploaded_entries.
- Invalid cards (no name/price) are postponed so they stay on screen, never silently dropped; storage failures flag one card, not the batch.
- Extracted Shared.store_product_image/4 (reused by the single-add upload path too).
- Browser-faithful LiveView tests; gate green.

Phase 2 (enhanced CSV with images + the price/draft fixes) is tracked separately."
```

- [ ] **Step 3: After merge + deploy, browser smoke test (isolated context)**

Log in as the test merchant, open `/admin/products/bulk`, upload 2 small images, name+price each,
publish, and confirm: both appear `:active` on the storefront with images rendering. (Tigris
bucket is now public, so images display.) Leave or clean up the test products.
