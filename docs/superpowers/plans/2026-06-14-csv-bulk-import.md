# Enhanced CSV Importer (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the CSV bulk import production-ready: images matched by filename, prices in cedis, imported products published (not invisible drafts), per-row inventory policy, and surfaced (never silent) warnings.

**Architecture:** Upgrade the domain module `Emakola.Catalog.CsvImporter` (robust NimbleCSV parse with an `images` column + semicolon multi-value cells; `import_rows/3` taking a pre-uploaded `image_urls` map; price→pesewas; activation; track-inventory policy; collected warnings). The web layer (`ProductLive.Index` + `BulkUploadModal`) gains a second image drop zone, consumes only referenced images, uploads them to Tigris, and passes the resulting url map to the importer. Price parsing is extracted to a small domain module so both the importer and the web `Shared` use one parser.

**Tech Stack:** Elixir, NimbleCSV, Ash (Catalog), Phoenix LiveView uploads, Tigris via `Emakola.Storage`.

**Spec:** `docs/superpowers/specs/2026-06-14-csv-bulk-import-design.md`
**Branch:** `feature/csv-bulk-import`

**Key facts for implementers:**
- `nimble_csv` is already in `mix.lock` (optional dep of `req`) but must be declared a direct dep to be usable.
- The importer is **domain** (`lib/emakola/catalog/`); it must NOT depend on `EmakolaWeb.Admin.ProductLive.Shared` (web). Price parsing is extracted to `Emakola.Money` (Task 1).
- `parse_price_input/1` (in `shared.ex:195`) returns `{:ok, pesewas}` | `:zero` | `:skip` | `:error`.
- Existing return contract `import_rows/2 → {success, error, errors}`; this becomes `import_rows/3 → {imported, skipped, warnings}` (same shape; +image_urls arg). The index handler (`index.ex` ~line 347) and DB test must be updated.
- Existing tests to update: `test/emakola/catalog/csv_importer_test.exs` (parse) and `csv_importer_db_test.exs` (import). The old "joins extra columns into tags" and "fewer than 6 columns" tests are replaced by the 8-column contract.
- `Emakola.Catalog.create_variant/2`, `Emakola.Catalog.create_image/2`, `Emakola.Catalog.activate_product/2` exist (code interface). Variant create accepts `price, product_id, store_id, sku, position, stock_quantity, track_inventory`.
- `Emakola.Storage.upload(binary, path, content_type: ct)` → `{:ok, url}` | `{:error, _}`.
- Browser-faithful LiveView tests (PR #131 lesson): drive via `element/file_input`, not bare `render_change`.

---

### Task 1: Add NimbleCSV; extract `Emakola.Money.parse_price/1`

**Files:**
- Modify: `mix.exs` (deps)
- Create: `lib/emakola/money.ex`
- Modify: `lib/emakola_web/live/admin/product_live/shared.ex` (delegate)
- Test: `test/emakola/money_test.exs` (create)

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.MoneyTest do
  use ExUnit.Case, async: true

  test "parses cedis strings to integer pesewas" do
    assert Emakola.Money.parse_price("150") == {:ok, 15_000}
    assert Emakola.Money.parse_price("25.50") == {:ok, 2550}
    assert Emakola.Money.parse_price("0") == :zero
    assert Emakola.Money.parse_price("0.00") == :zero
    assert Emakola.Money.parse_price("") == :skip
    assert Emakola.Money.parse_price("abc") == :error
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/money_test.exs`
Expected: FAIL — `Emakola.Money` undefined.

- [ ] **Step 3: Add the dep + create the module**

In `mix.exs` deps, add: `{:nimble_csv, "~> 1.0"},`

Create `lib/emakola/money.ex` — move the body of `Shared.parse_price_input/1` here verbatim (it's pure), renamed `parse_price/1`:

```elixir
defmodule Emakola.Money do
  @moduledoc "Pure money parsing/formatting at the presentation boundary (GHS ↔ pesewas)."

  @doc """
  Parses a GHS decimal string to integer pesewas.
  Returns `{:ok, pesewas}` (pesewas > 0), `:skip` (blank), `:zero` (parses to 0),
  or `:error` (non-empty unparseable).
  """
  def parse_price(value) do
    case Regex.run(~r/^\s*(\d+)(?:\.(\d{1,2}))?\s*$/, value || "") do
      [_, major] ->
        pesewas = String.to_integer(major) * 100
        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      [_, major, minor] ->
        pesewas = String.to_integer(major) * 100 + String.to_integer(String.pad_trailing(minor, 2, "0"))
        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      nil ->
        if String.trim(value || "") == "", do: :skip, else: :error
    end
  end
end
```

In `shared.ex`, replace the `parse_price_input/1` body with a delegate (keeps all web callers working unchanged):

```elixir
  def parse_price_input(value), do: Emakola.Money.parse_price(value)
```

- [ ] **Step 4: deps.get + run tests**

Run: `mix deps.get && mix test test/emakola/money_test.exs test/emakola_web/live/admin/product_form_test.exs`
Expected: money test PASS; the form tests (which use parse via Shared) still PASS (delegation is behavior-identical).

- [ ] **Step 5: Commit**

```bash
git add mix.exs mix.lock lib/emakola/money.ex lib/emakola_web/live/admin/product_live/shared.ex test/emakola/money_test.exs
git commit -m "refactor(catalog): extract Emakola.Money.parse_price; add nimble_csv dep"
```

---

### Task 2: Upgrade `parse/2` — NimbleCSV, 8 columns, images, semicolon cells (TDD)

**Files:**
- Modify: `lib/emakola/catalog/csv_importer.ex`
- Test: `test/emakola/catalog/csv_importer_test.exs` (replace the parse tests)

- [ ] **Step 1: Replace the parse tests**

Replace the body of `describe "parse/2" do ... end` in `csv_importer_test.exs` with:

```elixir
  describe "parse/2" do
    @cats %{}

    test "empty content → error" do
      assert {[], ["CSV file is empty"]} = CsvImporter.parse("", @cats)
    end

    test "header-only → error" do
      header = CsvImporter.template_header()
      assert {[], ["CSV file contains only a header row, no data"]} = CsvImporter.parse(header <> "\n", @cats)
    end

    test "parses a row with tags and images (semicolon-separated)" do
      csv = CsvImporter.template_header() <> "\nOkra,Fresh okra,,OKRA-1,15,10,fresh;local,okra-1.jpg;okra-2.jpg"
      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["title"] == "Okra"
      assert row["price"] == "15"
      assert row["stock_quantity"] == "10"
      assert row["tags"] == ["fresh", "local"]
      assert row["images"] == ["okra-1.jpg", "okra-2.jpg"]
    end

    test "blank tags/images → empty lists" do
      csv = CsvImporter.template_header() <> "\nYam,,,YAM,40,,,"
      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["tags"] == []
      assert row["images"] == []
    end

    test "quoted field containing a comma survives" do
      csv = CsvImporter.template_header() <> "\n\"Rice, 5kg\",Bag of rice,,RICE,80,5,grain,rice.jpg"
      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["title"] == "Rice, 5kg"
    end

    test "row with wrong column count → error, others still parse" do
      csv = CsvImporter.template_header() <> "\nBadRow,only,three\nGoodYam,desc,,YAM,40,3,tag,yam.jpg"
      {rows, errors} = CsvImporter.parse(csv, @cats)
      assert length(rows) == 1
      assert hd(rows)["title"] == "GoodYam"
      assert Enum.any?(errors, &String.contains?(&1, "Row 2"))
    end

    test "empty title → error" do
      csv = CsvImporter.template_header() <> "\n,desc,,SKU,10,1,,"
      {[], errors} = CsvImporter.parse(csv, @cats)
      assert Enum.any?(errors, &String.contains?(&1, "title is required"))
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/catalog/csv_importer_test.exs`
Expected: FAIL (template header lacks `images`; parse doesn't return tags/images lists).

- [ ] **Step 3: Rewrite the header + `parse/2`**

In `csv_importer.ex`, at the very top of the module body (after `@moduledoc`), define the parser and header:

```elixir
  NimbleCSV.define(Emakola.Catalog.CsvParser, separator: ",", escape: "\"")

  @columns 8
  @csv_template_header "title,description,category,sku,price,stock_quantity,tags,images"
```

Replace `parse/2` with:

```elixir
  def parse(content, categories_map) when is_binary(content) do
    case String.trim(content) do
      "" ->
        {[], ["CSV file is empty"]}

      trimmed ->
        case Emakola.Catalog.CsvParser.parse_string(trimmed, skip_headers: false) do
          [_header] ->
            {[], ["CSV file contains only a header row, no data"]}

          [_header | data_rows] ->
            data_rows
            |> Enum.with_index(2)
            |> Enum.reduce({[], []}, fn {fields, row_num}, acc ->
              reduce_row(fields, row_num, acc, categories_map)
            end)
            |> finalise_parse()

          [] ->
            {[], ["CSV file is empty"]}
        end
    end
  end

  defp reduce_row(fields, row_num, {rows_acc, errors_acc}, categories_map) do
    case fields do
      [title, description, category, sku, price, stock, tags, images] ->
        if String.trim(title) == "" do
          {rows_acc, ["Row #{row_num}: title is required" | errors_acc]}
        else
          row = %{
            "title" => String.trim(title),
            "description" => description,
            "category" => category,
            "category_id" => resolve_category_id(category, categories_map),
            "sku" => String.trim(sku),
            "price" => String.trim(price),
            "stock_quantity" => String.trim(stock),
            "tags" => split_multi(tags),
            "images" => split_multi(images)
          }

          {[row | rows_acc], errors_acc}
        end

      _ ->
        {rows_acc, ["Row #{row_num}: expected #{@columns} columns" | errors_acc]}
    end
  end

  defp split_multi(value) do
    (value || "")
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
```

Keep `finalise_parse/1`, `resolve_category_id/2`, `normalise/1` as-is. Update `template_header/0` to return the new `@csv_template_header`.

- [ ] **Step 4: Run tests to verify pass**

Run: `mix test test/emakola/catalog/csv_importer_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/catalog/csv_importer.ex test/emakola/catalog/csv_importer_test.exs
git commit -m "feat(catalog): CSV parse — NimbleCSV, 8-column contract, images + semicolon cells"
```

---

### Task 3: Upgrade `import_rows/3` — images, price, activate, inventory, warnings (TDD)

**Files:**
- Modify: `lib/emakola/catalog/csv_importer.ex`
- Test: `test/emakola/catalog/csv_importer_db_test.exs` (rewrite)

- [ ] **Step 1: Rewrite the DB tests**

Replace `csv_importer_db_test.exs` body (keep the module head + `use Emakola.DataCase` + `import Emakola.Factory` + `alias Emakola.Catalog.CsvImporter`) with:

```elixir
  require Ash.Query

  defp row(overrides) do
    Map.merge(
      %{
        "title" => "Okra",
        "description" => "Fresh",
        "category" => "",
        "category_id" => nil,
        "sku" => "OKRA-1",
        "price" => "15",
        "stock_quantity" => "",
        "tags" => [],
        "images" => []
      },
      overrides
    )
  end

  defp variant_of(product) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(product_id == ^product.id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp product_named(store, title) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store.id and title == ^title)
    |> Ash.read_one!(authorize?: false, load: [:images])
  end

  test "imports an active product with a priced untracked variant (no stock)" do
    store = create_store!()
    assert {1, 0, []} = CsvImporter.import_rows([row(%{})], store.id, %{})

    p = product_named(store, "Okra")
    assert p.status == :active
    v = variant_of(p)
    assert v.price == 1500
    assert v.track_inventory == false
  end

  test "price '150' becomes 15000 pesewas (cedis bug fix)" do
    store = create_store!()
    CsvImporter.import_rows([row(%{"title" => "Rice", "sku" => "RICE", "price" => "150"})], store.id, %{})
    assert variant_of(product_named(store, "Rice")).price == 15_000
  end

  test "positive stock_quantity → track_inventory true with that count" do
    store = create_store!()
    CsvImporter.import_rows([row(%{"title" => "Yam", "sku" => "YAM", "stock_quantity" => "10"})], store.id, %{})
    v = variant_of(product_named(store, "Yam"))
    assert v.track_inventory == true
    assert v.stock_quantity == 10
  end

  test "blank price → draft, no variant, warning" do
    store = create_store!()
    {imported, _skipped, warnings} =
      CsvImporter.import_rows([row(%{"title" => "NoPrice", "sku" => "NP", "price" => ""})], store.id, %{})

    assert imported == 1
    assert product_named(store, "NoPrice").status == :draft
    assert is_nil(variant_of(product_named(store, "NoPrice")))
    assert Enum.any?(warnings, &String.contains?(&1, "add a price"))
  end

  test "matched image filename attaches; unmatched warns but still imports" do
    store = create_store!()
    image_urls = %{"okra-1.jpg" => %{url: "https://s3.example.com/okra-1.jpg", content_type: "image/png"}}

    {1, 0, warnings} =
      CsvImporter.import_rows(
        [row(%{"images" => ["okra-1.jpg", "missing.jpg"]})],
        store.id,
        image_urls
      )

    p = product_named(store, "Okra")
    assert length(p.images) == 1
    assert hd(p.images).url == "https://s3.example.com/okra-1.jpg"
    assert Enum.any?(warnings, &String.contains?(&1, "missing.jpg"))
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/catalog/csv_importer_db_test.exs`
Expected: FAIL — `import_rows/3` undefined / old behavior.

- [ ] **Step 3: Rewrite `import_rows` and helpers**

Replace `import_rows/2` and its private helpers (`build_product_attrs`, `maybe_create_variant`, `parse_int`, `format_error`) in `csv_importer.ex` with:

```elixir
  @doc """
  Writes parsed rows to the database. `image_urls` is
  `%{"filename_downcased" => %{url: String.t(), content_type: String.t()}}` —
  images already uploaded to storage by the web layer.

  Per row: create product → (if a valid price) create a priced variant with the
  inventory policy and activate → attach matched images. Returns
  `{imported_count, skipped_count, warnings}`. `imported` counts rows whose product
  was created (a row with no valid price imports as a draft with a warning);
  `skipped` counts rows whose product create failed outright.
  """
  def import_rows(rows, store_id, image_urls \\ %{}) when is_list(rows) and is_binary(store_id) do
    Enum.reduce(rows, {0, 0, []}, fn row, {imported, skipped, warns} ->
      case Emakola.Catalog.create_product(build_product_attrs(row, store_id), authorize?: false) do
        {:ok, product} ->
          warns = warns ++ create_variant_and_activate(product, row, store_id)
          warns = warns ++ attach_images(product, row, store_id, image_urls)
          {imported + 1, skipped, warns}

        {:error, error} ->
          {imported, skipped + 1, warns ++ ["\"#{row["title"]}\": #{format_error(error)}"]}
      end
    end)
  end

  defp build_product_attrs(row, store_id) do
    %{
      title: row["title"],
      description: row["description"],
      category_id: row["category_id"],
      tags: row["tags"] || [],
      store_id: store_id
    }
  end

  # Creates a priced variant + activates, or warns if the price is missing/invalid.
  defp create_variant_and_activate(product, row, store_id) do
    case Emakola.Money.parse_price(row["price"]) do
      {:ok, pesewas} ->
        {track, stock} = inventory_policy(row["stock_quantity"])

        variant_attrs = %{
          product_id: product.id,
          store_id: store_id,
          price: pesewas,
          sku: blank_to_nil(row["sku"]),
          position: 0,
          track_inventory: track,
          stock_quantity: stock
        }

        case Emakola.Catalog.create_variant(variant_attrs, authorize?: false) do
          {:ok, _v} ->
            Emakola.Catalog.activate_product(product, authorize?: false)
            []

          {:error, error} ->
            ["\"#{row["title"]}\": variant not created — #{format_error(error)}"]
        end

      _ ->
        ["\"#{row["title"]}\": add a price to publish (imported as draft)"]
    end
  end

  # stock_quantity a positive integer → track with that count; blank/0/invalid → untracked.
  defp inventory_policy(stock_str) do
    case Integer.parse(stock_str || "") do
      {n, _} when n > 0 -> {true, n}
      _ -> {false, 0}
    end
  end

  defp attach_images(_product, %{"images" => []}, _store_id, _urls), do: []
  defp attach_images(_product, %{"images" => nil}, _store_id, _urls), do: []

  # Attaches matched images in listed order (first listed = primary, by insertion
  # order — the :create action does not accept a position attribute). Unmatched
  # filenames and create_image failures both warn; neither aborts the row.
  defp attach_images(product, %{"images" => filenames, "title" => title}, store_id, urls) do
    Enum.reduce(filenames, [], fn filename, warns ->
      case Map.get(urls, String.downcase(filename)) do
        %{url: url, content_type: ct} ->
          case Emakola.Catalog.create_image(
                 %{url: url, product_id: product.id, store_id: store_id, content_type: ct},
                 authorize?: false
               ) do
            {:ok, _} -> warns
            {:error, error} -> warns ++ ["\"#{title}\": image #{filename} not saved — #{format_error(error)}"]
          end

        nil ->
          warns ++ ["\"#{title}\": image #{filename} not found in your uploads"]
      end
    end)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors |> Enum.map(&Map.get(&1, :message, "invalid")) |> Enum.join(", ")
  end

  defp format_error(_), do: "could not be saved"
```

(Confirmed: `create_image`'s `:create` action accepts `url, alt_text, content_type, file_size_bytes, product_id, variant_id, store_id` — no `position`, so images attach in insertion order, and `content_type` is validated to jpeg/png/webp, which the `:bulk_images` accept list guarantees.)

- [ ] **Step 4: Run tests to verify pass**

Run: `mix test test/emakola/catalog/csv_importer_db_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/catalog/csv_importer.ex test/emakola/catalog/csv_importer_db_test.exs
git commit -m "feat(catalog): CSV import — cedis price, activate, inventory policy, images, warnings"
```

---

### Task 4: Wire the web — image drop zone + consume/upload + import_rows/3 (TDD)

**Files:**
- Modify: `lib/emakola_web/live/admin/product_live/bulk_upload_modal.ex`
- Modify: `lib/emakola_web/live/admin/product_live/index.ex`
- Test: `test/emakola_web/live/admin/product_live_test.exs` (or the existing index test file — find with `grep -rln "bulk" test/emakola_web/live/admin/`)

- [ ] **Step 1: Write the failing LiveView test**

Add to the index/admin product LiveView test (mirror its existing authed-merchant setup):

```elixir
  describe "bulk CSV import with images" do
    @png Base.decode64!("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")

    test "the bulk modal exposes an image drop zone and the new template header", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/products")
      html = render(view)
      assert html =~ "stock_quantity,tags,images"
      assert html =~ ~s(phx-drop-target)
    end

    test "importing a CSV with a matched image publishes a product with that image", %{conn: conn, store: store} do
      import Mox
      stub(Emakola.StorageMock, :upload, fn _b, path, _o -> {:ok, "https://s3.example.com/#{path}"} end)

      {:ok, view, _html} = live(conn, "/admin/products")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      csv =
        Emakola.Catalog.CsvImporter.template_header() <>
          "\nOkra,Fresh,,OKRA-1,15,5,fresh,okra.png"

      file_input(view, "#csv-upload-form", :csv_file, [%{name: "p.csv", content: csv, type: "text/csv"}])
      |> render_upload("p.csv")

      file_input(view, "#csv-upload-form", :bulk_images, [%{name: "okra.png", content: @png, type: "image/png"}])
      |> render_upload("okra.png")

      view |> element("button[phx-click=parse_csv]") |> render_click()
      view |> element("button[phx-click=import_products]") |> render_click()

      p =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id and title == "Okra")
        |> Ash.read_one!(authorize?: false, load: [:images, :variants])

      assert p.status == :active
      assert [%{price: 1500}] = p.variants
      assert length(p.images) == 1
    end
  end
```

Adjust the upload form id (`#csv-upload-form`) and the bulk_images drop-zone placement to whatever the modal actually renders; the test must drive the real elements (PR #131 lesson). Add `require Ash.Query` to the test module if absent.

- [ ] **Step 2: Run to verify failure**

Run: `mix test <the index test file>`
Expected: FAIL — no `:bulk_images` upload / header still old.

- [ ] **Step 3: Add the second drop zone + template header in `bulk_upload_modal.ex`**

Inside the existing `<form id="csv-upload-form" ...>`, after the CSV file area, add an image drop zone:

```elixir
        <div class="space-y-3">
          <label class="block text-sm font-medium text-slate-700">Product images (optional)</label>
          <div
            class="border-2 border-dashed border-slate-300 rounded-lg p-4 text-center hover:border-emerald-400 transition-colors"
            phx-drop-target={@uploads.bulk_images.ref}
          >
            <.icon name="hero-photo" class="size-7 mx-auto text-slate-400 mb-1" />
            <p class="text-xs text-slate-600">
              Upload the photos named in your <span class="font-mono">images</span> column
            </p>
            <.live_file_input upload={@uploads.bulk_images} class="mt-2" />
          </div>
          <div :for={entry <- @uploads.bulk_images.entries} class="text-xs text-slate-500">
            {entry.client_name}
            <button type="button" phx-click="cancel_bulk_image" phx-value-ref={entry.ref} class="text-red-500 ml-1">✕</button>
          </div>
          <div :for={err <- upload_errors(@uploads.bulk_images)} class="text-xs text-red-600">
            {upload_error_to_string(err)}
          </div>
        </div>
```

Add `attr :uploads` already includes the map; no new attr needed (the modal reads `@uploads.bulk_images`). The template-header text already comes from `CsvImporter.template_header()` (now updated) — confirm the modal renders it.

- [ ] **Step 4: Wire `index.ex`**

- Add to the existing `allow_upload` chain in mount:

```elixir
      |> allow_upload(:bulk_images,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 50,
        max_file_size: 10_000_000
      )
```

- Add a cancel handler:

```elixir
  def handle_event("cancel_bulk_image", %{"ref" => ref}, socket) do
    {:noreply, Phoenix.LiveView.cancel_upload(socket, :bulk_images, ref)}
  end
```

- Replace the `import_products` handler body's importer call. Build the referenced-filenames set from the parsed rows, consume only those image entries, upload each to Tigris, then call `import_rows/3`:

```elixir
  def handle_event("import_products", _params, socket) do
    rows = socket.assigns.csv_preview

    if rows == [] do
      {:noreply, assign(socket, csv_errors: ["No rows to import. Upload and parse a CSV first."])}
    else
      socket = assign(socket, bulk_importing: true)
      store_id = socket.assigns.store_id

      referenced =
        rows
        |> Enum.flat_map(&(&1["images"] || []))
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

      {image_urls, socket} = upload_referenced_images(socket, referenced, store_id)

      {imported, skipped, warnings} =
        Emakola.Catalog.CsvImporter.import_rows(rows, store_id, image_urls)

      if imported > 0, do: Emakola.Catalog.CachedCatalog.invalidate_store(store_id)

      socket =
        socket
        |> assign(bulk_importing: false, csv_errors: warnings)
        |> load_products()
        |> put_flash(:info, bulk_summary(imported, skipped))

      {:noreply, socket}
    end
  end

  defp upload_referenced_images(socket, referenced, store_id) do
    urls =
      Phoenix.LiveView.consume_uploaded_entries(socket, :bulk_images, fn %{path: tmp}, entry ->
        name = String.downcase(entry.client_name)

        if MapSet.member?(referenced, name) do
          s3_path = "stores/#{store_id}/products/#{Ecto.UUID.generate()}#{Path.extname(entry.client_name)}"

          case Emakola.Storage.upload(File.read!(tmp), s3_path, content_type: entry.client_type) do
            {:ok, url} -> {:ok, {name, %{url: url, content_type: entry.client_type}}}
            {:error, _} -> {:ok, nil}
          end
        else
          {:postpone, nil}
        end
      end)

    map = urls |> Enum.reject(&is_nil/1) |> Map.new()
    {map, socket}
  end

  defp bulk_summary(imported, 0), do: "Imported #{imported} product(s)."
  defp bulk_summary(imported, skipped), do: "Imported #{imported} product(s). #{skipped} skipped."
```

Note: `consume_uploaded_entries` returns the callback values for consumed entries; `{:postpone, nil}` keeps unreferenced images un-consumed (they're harmless and discarded when the modal closes). Filter `nil`s (failed uploads) before `Map.new`.

- [ ] **Step 5: Run tests to verify pass**

Run: `mix test <the index test file> test/emakola/catalog/`
Expected: PASS.

- [ ] **Step 6: Gate + commit**

```bash
mix format && mix credo --strict
git add lib/emakola_web/live/admin/product_live/bulk_upload_modal.ex lib/emakola_web/live/admin/product_live/index.ex <test file>
git commit -m "feat(catalog): bulk CSV modal image drop zone; consume+upload referenced images on import"
```

---

### Task 5: Gate, PR, deploy, smoke

- [ ] **Step 1: Full gate**

Run: `mix clean --only app && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict`
Run: `mix test test/emakola/catalog/ test/emakola/money_test.exs test/emakola_web/live/admin/`
Expected: all clean / 0 failures.

- [ ] **Step 2: Push + PR**

```bash
git push -u origin feature/csv-bulk-import
gh pr create --base main --title "feat(catalog): enhanced CSV importer with images (Phase 2)" --body "Phase 2 of bulk upload. Adds image support (filename-matched, second drop zone) to the CSV importer and fixes its gaps: price read as cedis (was raw pesewas — 150 → GH₵150 not GH₵1.50), imported products are activated (were invisible drafts), per-row inventory policy (stock_quantity>0 → track; blank → untracked sellable), and every row's outcome surfaced (no more silent rescue). NimbleCSV parse with an 8-column contract; tags/images are semicolon-separated within cells. Importer stays a domain module taking a pre-uploaded image-url map. Phase 1 (photo-first) shipped earlier."
```

- [ ] **Step 3: After merge + deploy, browser smoke test (isolated context)**

Log in as the test merchant, open Products → Bulk Upload, download the template, upload a 2-row CSV referencing 2 image filenames + the 2 images, parse, import; confirm both products are live on the storefront with images and correct prices. Leave or clean up the test data.
