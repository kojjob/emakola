# Supplier Product Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Registered merchants browse ALL published supplier offers (photos, suggested retail, per-area dispatch fees, supplier terms), see wholesale price/margin once connected, and import an offer into their store.

**Architecture:** New `dispatch_fees` map on `SupplierOffer` + validation; two new read functions on the existing `Emakola.Suppliers.Offers` service (`list_discoverable/2`, `get_discoverable/3`); two new LiveViews (`Admin.SupplyCatalogLive.Index` and `.Show`) reusing `ListingImporter.import/3` and `Network.request/2` for the CTAs. Spec: `docs/superpowers/specs/2026-07-23-supplier-catalog-design.md`.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x, TailwindCSS, ExUnit.

## Global Constraints

- All money is integer **pesewas**; display via `EmakolaWeb.Helpers.Currency.format_price/1`.
- Branch: `feature/supplier-catalog` (already created, spec committed).
- Every commit: `mix test <touched files>` green first; conventional commit message.
- `mix format` before each commit (a PostToolUse hook also flags this).
- Never add `authorize?: false` in the web layer — LiveViews call the `Offers`/`Network`/`ListingImporter` services only.
- LiveViews must have an explicit `handle_event` clause per button (unmatched events crash in this repo).
- Admin mounts gate data loads behind `connected?/1` (no SEO surface).
- `mix ash.codegen` is broken (stale snapshots) — the migration is hand-written.

---

### Task 1: `dispatch_fees` on SupplierOffer (attribute + validation + migration)

**Files:**
- Create: `priv/repo/migrations/20260723090000_add_dispatch_fees_to_supplier_offers.exs`
- Create: `lib/emakola/suppliers/validations/dispatch_fees.ex`
- Modify: `lib/emakola/suppliers/resources/supplier_offer.ex` (attributes block ~line 20-67; `create_draft` accept ~line 101; `update_terms` accept ~line 118; new `validations` block)
- Test: `test/emakola/suppliers/offers_test.exs` (append a describe block)

**Interfaces:**
- Consumes: existing `Offers.create_draft/2`, `Offers.update_terms/3`, test helpers `draft_offer!/2` in the same test file.
- Produces: `SupplierOffer.dispatch_fees :: map` (`%{"Area" => non_neg_integer_pesewas}`), validated on create/update. Later tasks read `offer.dispatch_fees`.

- [ ] **Step 1: Write the failing tests** — append to `test/emakola/suppliers/offers_test.exs` (before the private helpers):

```elixir
  describe "dispatch_fees" do
    test "accepts per-area non-negative integer fees within delivery_areas", context do
      offer = draft_offer!(context, :markup)

      assert {:ok, updated} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => 1_500}
               })

      assert updated.dispatch_fees == %{"Greater Accra" => 1_500}
    end

    test "defaults to an empty map", context do
      offer = draft_offer!(context, :markup)
      assert offer.dispatch_fees == %{}
    end

    test "rejects a fee for an area not in delivery_areas", context do
      offer = draft_offer!(context, :markup)

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Volta" => 1_000}
               })
    end

    test "rejects negative and non-integer fees", context do
      offer = draft_offer!(context, :markup)

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => -5}
               })

      assert {:error, _} =
               Offers.update_terms(context.wholesaler_actor, offer, %{
                 dispatch_fees: %{"Greater Accra" => "15"}
               })
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: FAIL — `NoSuchInput` / unknown attribute `dispatch_fees`.

- [ ] **Step 3: Migration** — create `priv/repo/migrations/20260723090000_add_dispatch_fees_to_supplier_offers.exs`:

```elixir
defmodule Emakola.Repo.Migrations.AddDispatchFeesToSupplierOffers do
  use Ecto.Migration

  def change do
    # Supplier-quoted dispatch fee per delivery area, integer pesewas.
    # %{"Greater Accra" => 1500}. Empty map = no fees quoted yet.
    alter table(:supplier_offers) do
      add :dispatch_fees, :map, null: false, default: %{}
    end
  end
end
```

- [ ] **Step 4: Validation module** — create `lib/emakola/suppliers/validations/dispatch_fees.ex`:

```elixir
defmodule Emakola.Suppliers.Validations.DispatchFees do
  @moduledoc """
  dispatch_fees is a map of delivery-area => fee in integer pesewas.
  Every fee must be a non-negative integer and every area key must be
  one of the offer's delivery_areas.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    fees = Ash.Changeset.get_attribute(changeset, :dispatch_fees) || %{}
    areas = Ash.Changeset.get_attribute(changeset, :delivery_areas) || []

    cond do
      Enum.any?(Map.values(fees), fn v -> not (is_integer(v) and v >= 0) end) ->
        {:error,
         field: :dispatch_fees, message: "fees must be non-negative integers in pesewas"}

      Enum.any?(Map.keys(fees), &(&1 not in areas)) ->
        {:error, field: :dispatch_fees, message: "fee areas must be listed in delivery_areas"}

      true ->
        :ok
    end
  end
end
```

- [ ] **Step 5: Resource changes** in `lib/emakola/suppliers/resources/supplier_offer.ex`:

Add to the `attributes do` block (after `delivery_areas`):

```elixir
    # Supplier-quoted dispatch fee per delivery area, integer pesewas.
    attribute(:dispatch_fees, :map, allow_nil?: false, default: %{}, public?: true)
```

Add `:dispatch_fees` to BOTH accept lists (`create_draft` and `update_terms`). Add after the `actions` block (top level in the resource):

```elixir
  validations do
    validate(Emakola.Suppliers.Validations.DispatchFees)
  end
```

- [ ] **Step 6: Migrate + run tests**

Run: `mix ecto.migrate && mix test test/emakola/suppliers/offers_test.exs`
Expected: all pass (existing + 4 new).

- [ ] **Step 7: Commit**

```bash
mix format
git add -A && git commit -m "feat(catalog): supplier offers carry per-area dispatch fees"
```

---

### Task 2: `Offers.list_discoverable/2`

**Files:**
- Modify: `lib/emakola/suppliers/offers.ex`
- Test: `test/emakola/suppliers/offers_test.exs` (append describe)

**Interfaces:**
- Consumes: existing privates `ensure_access/2`, `connected_wholesaler_ids/1`, `discoverable?/1` in the same module; `Network.request/2` + `Network.approve/2` in tests.
- Produces: `list_discoverable(actor, reseller_store_id) :: {:ok, [%{offer: %SupplierOffer{}, connected?: boolean}]} | {:error, term}`. Offers are loaded with `:wholesaler_store`, `source_product: :images`, `offer_variants: :source_variant`.

- [ ] **Step 1: Write the failing tests** — append to `test/emakola/suppliers/offers_test.exs`:

```elixir
  describe "list_discoverable/2" do
    test "includes published offers from UNconnected wholesalers, flagged connected?: false",
         context do
      published = publish_offer!(context)

      assert {:ok, [entry]} = Offers.list_discoverable(context.reseller_actor, context.reseller.id)
      assert entry.offer.id == published.id
      assert entry.connected? == false
    end

    test "flags offers from connected wholesalers with connected?: true", context do
      publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      {:ok, _} = Network.approve(context.wholesaler_actor, conn)

      assert {:ok, [entry]} = Offers.list_discoverable(context.reseller_actor, context.reseller.id)
      assert entry.connected? == true
    end

    test "excludes the store's own offers and drafts", context do
      _draft_only = draft_offer!(context, :markup)

      assert {:ok, []} = Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      published = publish_offer!(context)

      assert {:ok, []} =
               Offers.list_discoverable(context.wholesaler_actor, context.wholesaler.id)

      assert {:ok, [%{offer: %{id: id}}]} =
               Offers.list_discoverable(context.reseller_actor, context.reseller.id)

      assert id == published.id
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: FAIL — `Offers.list_discoverable/2 is undefined`.

- [ ] **Step 3: Implement** — in `lib/emakola/suppliers/offers.ex`, after `list_available/2`:

```elixir
  @doc """
  Every published, discoverable offer on the network EXCEPT the store's own —
  the browse-all supplier catalog. Each entry carries `connected?` so callers
  can gate wholesale pricing. Query-capped at 200 (scaling boundary; see spec).
  """
  def list_discoverable(actor, reseller_store_id) do
    with :ok <- ensure_access(actor, reseller_store_id),
         {:ok, connected_ids} <- connected_wholesaler_ids(reseller_store_id),
         {:ok, offers} <- discoverable_offers(reseller_store_id) do
      connected = MapSet.new(connected_ids)

      {:ok,
       Enum.map(offers, fn offer ->
         %{offer: offer, connected?: MapSet.member?(connected, offer.wholesaler_store_id)}
       end)}
    end
  end

  defp discoverable_offers(excluding_store_id) do
    case SupplierOffer
         |> Ash.Query.filter(status == :published and wholesaler_store_id != ^excluding_store_id)
         |> Ash.Query.sort(published_at: :desc)
         |> Ash.Query.limit(200)
         |> Ash.Query.load([
           :wholesaler_store,
           source_product: :images,
           offer_variants: :source_variant
         ])
         |> Ash.read(authorize?: false) do
      {:ok, offers} -> {:ok, Enum.filter(offers, &discoverable?/1)}
      {:error, reason} -> {:error, reason}
    end
  end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format
git add -A && git commit -m "feat(catalog): Offers.list_discoverable browses the whole network"
```

---

### Task 3: `Offers.get_discoverable/3` with connection status

**Files:**
- Modify: `lib/emakola/suppliers/offers.ex`
- Test: `test/emakola/suppliers/offers_test.exs` (append describe)

**Interfaces:**
- Consumes: Task 2's `discoverable_offers` load list; `SupplyConnection` (statuses `:pending | :active | :rejected | :suspended | :terminated`).
- Produces: `get_discoverable(actor, reseller_store_id, offer_id) :: {:ok, %{offer: %SupplierOffer{}, connection_status: :connected | :pending | :none}} | {:error, :not_found | term}`.

- [ ] **Step 1: Write the failing tests** — append:

```elixir
  describe "get_discoverable/3" do
    test "returns the offer with :none when no connection exists", context do
      published = publish_offer!(context)

      assert {:ok, %{offer: offer, connection_status: :none}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      assert offer.id == published.id
    end

    test "reports :pending and :connected connection states", context do
      published = publish_offer!(context)

      {:ok, conn} =
        Network.request(context.reseller_actor, %{
          wholesaler_store_id: context.wholesaler.id,
          reseller_store_id: context.reseller.id,
          requested_by_store_id: context.reseller.id
        })

      assert {:ok, %{connection_status: :pending}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      {:ok, _} = Network.approve(context.wholesaler_actor, conn)

      assert {:ok, %{connection_status: :connected}} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)
    end

    test "is :not_found for paused offers and the store's own offers", context do
      published = publish_offer!(context)
      {:ok, _} = Offers.pause(context.wholesaler_actor, published)

      assert {:error, :not_found} =
               Offers.get_discoverable(context.reseller_actor, context.reseller.id, published.id)

      republished = publish_offer!(%{context | product: create_product!(context.wholesaler, status: :active)} |> put_new_variant())

      assert {:error, :not_found} =
               Offers.get_discoverable(
                 context.wholesaler_actor,
                 context.wholesaler.id,
                 republished.id
               )
    end
  end

  # Builds a fresh variant for a replaced product so publish_offer! can be
  # reused with a second product in the same test.
  defp put_new_variant(context) do
    %{context | variant: create_variant!(context.product, context.wholesaler, price: 5_000, stock_quantity: 10)}
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: FAIL — `Offers.get_discoverable/3 is undefined`.

- [ ] **Step 3: Implement** — in `lib/emakola/suppliers/offers.ex` after `list_discoverable/2`:

```elixir
  @doc """
  One discoverable offer for the catalog detail page, with the reseller's
  connection status toward its wholesaler. `{:error, :not_found}` for drafts,
  paused/archived offers, undiscoverable products, and the store's own offers.
  """
  def get_discoverable(actor, reseller_store_id, offer_id) do
    with :ok <- ensure_access(actor, reseller_store_id) do
      query =
        SupplierOffer
        |> Ash.Query.filter(
          id == ^offer_id and status == :published and
            wholesaler_store_id != ^reseller_store_id
        )
        |> Ash.Query.load([
          :wholesaler_store,
          source_product: :images,
          offer_variants: :source_variant
        ])

      case Ash.read_one(query, authorize?: false) do
        {:ok, nil} ->
          {:error, :not_found}

        {:ok, offer} ->
          if discoverable?(offer) do
            {:ok,
             %{
               offer: offer,
               connection_status: connection_status(reseller_store_id, offer.wholesaler_store_id)
             }}
          else
            {:error, :not_found}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp connection_status(reseller_store_id, wholesaler_store_id) do
    case SupplyConnection
         |> Ash.Query.filter(
           reseller_store_id == ^reseller_store_id and
             wholesaler_store_id == ^wholesaler_store_id
         )
         |> Ash.Query.sort(inserted_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [%{status: :active} | _]} -> :connected
      {:ok, [%{status: :pending} | _]} -> :pending
      _ -> :none
    end
  end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format
git add -A && git commit -m "feat(catalog): Offers.get_discoverable with connection status"
```

---

### Task 4: Catalog Index LiveView + routes + sidebar entry

**Files:**
- Create: `lib/emakola_web/live/admin/supply_catalog_live/index.ex`
- Modify: `lib/emakola_web/router.ex` (in the merchant-admin live block near `live "/admin/settings/supply-network"`, ~line 456)
- Modify: `lib/emakola_web/components/sidebar_components.ex` (~line 256, after the "Earn Network" link)
- Test: `test/emakola_web/live/admin/supply_catalog_live_test.exs` (create)

**Interfaces:**
- Consumes: `Offers.list_discoverable/2` (Task 2 shape); assigns `:current_merchant` / `:current_store` provided by the admin live_session; `EmakolaWeb.Helpers.Currency.format_price/1`.
- Produces: route `/admin/supply/catalog`; `active_nav: :supply_catalog`; card links to `/admin/supply/catalog/#{offer.id}` (Task 5's route).

- [ ] **Step 1: Write the failing tests** — create `test/emakola_web/live/admin/supply_catalog_live_test.exs`:

```elixir
defmodule EmakolaWeb.Admin.SupplyCatalogLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Suppliers.{Network, Offers}

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/supply/catalog")
    end
  end

  describe "catalog index" do
    setup %{conn: conn} do
      {reseller_actor, reseller} = Factory.create_merchant_with_store!(%{name: "Reseller Shop"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(reseller_actor))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, reseller_actor: reseller_actor, reseller: reseller}
    end

    test "lists an unconnected supplier's offer WITHOUT wholesale pricing", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog")

      assert html =~ "Shea Butter 500g"
      assert html =~ "Accra Wholesale"
      # suggested retail (4_500 pesewas) is public
      assert html =~ "45.00"
      # wholesale price (3_000 pesewas) must NOT leak on the index
      refute html =~ "30.00"
      assert fixture.offer.dispatch_fees == %{"Greater Accra" => 1_500}
      # dispatch fee shown
      assert html =~ "15.00"
    end

    test "search filters by product title", %{conn: conn} do
      create_published_offer!(title: "Shea Butter 500g")
      create_published_offer!(title: "Kente Stole", supplier_name: "Bonwire Weavers")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog")

      html =
        view
        |> element("form[phx-change=search]")
        |> render_change(%{"search" => "kente"})

      assert html =~ "Kente Stole"
      refute html =~ "Shea Butter 500g"
    end
  end

  # -- fixtures --------------------------------------------------------------

  def create_published_offer!(opts \\ []) do
    {wholesaler_actor, wholesaler} =
      Factory.create_merchant_with_store!(%{name: opts[:supplier_name] || "Accra Wholesale"})

    product =
      Factory.create_product!(wholesaler,
        status: :active,
        title: opts[:title] || "Shea Butter 500g"
      )

    variant =
      Factory.create_variant!(product, wholesaler,
        price: 5_000,
        stock_quantity: 10
      )

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Greater Accra", "Ashanti"],
        return_terms: "Returns accepted within seven days",
        returns_window_days: 7,
        warranty_months: 6
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_500,
        max_retail_price: 6_000
      })

    {:ok, offer} =
      Offers.update_terms(wholesaler_actor, offer, %{
        dispatch_fees: %{"Greater Accra" => 1_500}
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      product: product,
      variant: variant,
      offer: published
    }
  end

  def connect!(reseller_actor, reseller, fixture) do
    {:ok, conn} =
      Network.request(reseller_actor, %{
        wholesaler_store_id: fixture.wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: reseller.id
      })

    {:ok, active} = Network.approve(fixture.wholesaler_actor, conn)
    active
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: FAIL — no route matches `/admin/supply/catalog`.

- [ ] **Step 3: Routes** — in `lib/emakola_web/router.ex`, directly under `live "/admin/settings/supply-network", Admin.SupplyNetworkLive`:

```elixir
      live "/admin/supply/catalog", Admin.SupplyCatalogLive.Index
      live "/admin/supply/catalog/:offer_id", Admin.SupplyCatalogLive.Show
```

(The Show module arrives in Task 5; define both routes now so links compile once, and Task 5's tests exercise the second.)
NOTE: if `mix compile` fails because `Admin.SupplyCatalogLive.Show` does not exist yet, add only the Index route in this task and move the Show route line to Task 5 Step 3.

- [ ] **Step 4: Sidebar** — in `lib/emakola_web/components/sidebar_components.ex`, after the "Earn Network" `<.sidebar_link ... />`:

```heex
        <.sidebar_link
          href="/admin/supply/catalog"
          title="Supplier Catalog"
          icon="truck"
          active={@active_nav == :supply_catalog}
        />
```

- [ ] **Step 5: Index LiveView** — create `lib/emakola_web/live/admin/supply_catalog_live/index.ex`:

```elixir
defmodule EmakolaWeb.Admin.SupplyCatalogLive.Index do
  @moduledoc """
  Browse-all supplier catalog. Every published offer on the network is
  visible; wholesale pricing stays hidden until the merchant's connection
  to that wholesaler is approved (gating happens in Show — the index never
  renders wholesale numbers at all).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Supplier catalog",
        active_nav: :supply_catalog,
        search: ""
      )

    socket =
      if connected?(socket) do
        assign(socket, loading: false, entries: load_entries(socket))
      else
        # Dead render is a shell — no SEO surface behind admin auth.
        assign(socket, loading: true, entries: [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply, assign(socket, search: query)}
  end

  defp load_entries(socket) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, entries} <- Offers.list_discoverable(socket.assigns.current_merchant, store_id) do
      entries
    else
      _ -> []
    end
  end

  defp filtered(entries, search) do
    case String.trim(String.downcase(search)) do
      "" ->
        entries

      needle ->
        Enum.filter(entries, fn %{offer: offer} ->
          String.contains?(String.downcase(offer.source_product.title), needle) or
            String.contains?(String.downcase(offer.wholesaler_store.name), needle)
        end)
    end
  end

  defp first_image_url(offer) do
    case offer.source_product.images do
      [_ | _] = images ->
        img = images |> Enum.sort_by(&Map.get(&1, :position, 0)) |> List.first()
        Map.get(img, :thumbnail_url) || Map.get(img, :url)

      _ ->
        nil
    end
  end

  defp retail_range(offer) do
    prices = Enum.map(offer.offer_variants, & &1.suggested_retail_price)
    {Enum.min(prices), Enum.max(prices)}
  end

  defp dispatch_label(offer) do
    case Map.values(offer.dispatch_fees) do
      [] ->
        "Dispatch —"

      fees ->
        {min, max} = {Enum.min(fees), Enum.max(fees)}

        if min == max,
          do: "#{format_price(min)} dispatch",
          else: "#{format_price(min)}–#{format_price(max)} dispatch"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 pb-12">
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-6 pt-2">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Supplier catalog</h1>
          <p class="text-sm text-slate-500 mt-1">
            Products you can stock from suppliers across the network
          </p>
        </div>
        <form phx-change="search" class="w-full sm:w-72">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search products or suppliers…"
            phx-debounce="200"
            class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm focus:ring-2 focus:ring-emerald-500"
          />
        </form>
      </div>

      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">
        Loading catalog…
      </div>

      <div
        :if={!@loading and filtered(@entries, @search) == []}
        class="py-16 text-center text-sm text-slate-500"
      >
        No supplier products match. Suppliers publish offers from their Earn Network page.
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <.link
          :for={%{offer: offer, connected?: connected?} <- filtered(@entries, @search)}
          navigate={~p"/admin/supply/catalog/#{offer.id}"}
          class="group rounded-2xl border border-slate-200 bg-white overflow-hidden hover:shadow-md transition-shadow"
        >
          <div class="aspect-[4/3] bg-slate-100 overflow-hidden">
            <img
              :if={first_image_url(offer)}
              src={first_image_url(offer)}
              alt={offer.source_product.title}
              class="w-full h-full object-cover group-hover:scale-[1.02] transition-transform"
            />
          </div>
          <div class="p-4 space-y-1.5">
            <div class="flex items-start justify-between gap-2">
              <p class="font-semibold text-sm text-slate-900 truncate">
                {offer.source_product.title}
              </p>
              <span
                :if={connected?}
                class="shrink-0 text-[10px] font-semibold uppercase tracking-wide text-emerald-700 bg-emerald-50 rounded-full px-2 py-0.5"
              >
                Connected
              </span>
            </div>
            <p class="text-xs text-slate-500 truncate">{offer.wholesaler_store.name}</p>
            <p class="text-sm font-medium text-slate-800">
              {retail_range(offer) |> then(fn {min, max} ->
                if min == max,
                  do: format_price(min),
                  else: "#{format_price(min)} – #{format_price(max)}"
              end)} <span class="text-xs text-slate-400">suggested retail</span>
            </p>
            <p class="text-xs text-slate-500">{dispatch_label(offer)}</p>
            <div class="flex flex-wrap gap-1 pt-1">
              <span
                :for={area <- offer.delivery_areas}
                class="text-[10px] text-slate-600 bg-slate-100 rounded-full px-2 py-0.5"
              >
                {area}
              </span>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 6: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: PASS (if the Show route breaks compilation, see Step 3 NOTE).

- [ ] **Step 7: Commit**

```bash
mix format
git add -A && git commit -m "feat(web): supplier catalog browse page"
```

---

### Task 5: Catalog Show LiveView — gated detail

**Files:**
- Create: `lib/emakola_web/live/admin/supply_catalog_live/show.ex`
- Test: `test/emakola_web/live/admin/supply_catalog_live_test.exs` (append describe)

**Interfaces:**
- Consumes: `Offers.get_discoverable/3` (Task 3 shape); `create_published_offer!/1` + `connect!/3` fixtures from Task 4's test file; `format_price/1`.
- Produces: the Show page with per-state CTA buttons rendered `disabled` and WITHOUT `phx-click` (no handler may be missing for a rendered event in this repo). Task 6 activates "Request connection", Task 7 activates "Add to my store" — each adds `phx-click` together with its `handle_event` clause.

- [ ] **Step 1: Write the failing tests** — append to the LV test file:

```elixir
  describe "catalog show" do
    setup %{conn: conn} do
      {reseller_actor, reseller} = Factory.create_merchant_with_store!(%{name: "Reseller Shop"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(reseller_actor))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, reseller_actor: reseller_actor, reseller: reseller}
    end

    test "unconnected: shows retail, dispatch fees, terms — locks wholesale + margin", %{
      conn: conn
    } do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert html =~ "Shea Butter 500g"
      assert html =~ "45.00"
      assert html =~ "Greater Accra"
      assert html =~ "15.00"
      assert html =~ "Returns accepted within seven days"
      refute html =~ "30.00"
      assert html =~ "Request connection"
      assert html =~ "Connect to see wholesale pricing"
    end

    test "connected: shows wholesale price and margin", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      assert html =~ "30.00"
      # margin = 4500 - 3000 = 1500 pesewas at 50.0% — assert the percentage,
      # because "15.00" already appears as the dispatch fee
      assert html =~ "50.0%"
      # max retail cap (6_000) is connection-gated info
      assert html =~ "60.00"
      assert html =~ "Add to my store"
      refute html =~ "Request connection"
    end

    test "a paused offer redirects back to the catalog", %{conn: conn} do
      fixture = create_published_offer!()
      {:ok, _} = Offers.pause(fixture.wholesaler_actor, fixture.offer)

      assert {:error, {:live_redirect, %{to: "/admin/supply/catalog"}}} =
               live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")
    end

    test "an area without a quoted fee shows the placeholder", %{conn: conn} do
      fixture = create_published_offer!()

      {:ok, _view, html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # "Ashanti" is a delivery area with no fee quoted
      assert html =~ "ask supplier"
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: FAIL — `EmakolaWeb.Admin.SupplyCatalogLive.Show` undefined (or route error if the Show route was deferred in Task 4 — add it now).

- [ ] **Step 3: Implement** — create `lib/emakola_web/live/admin/supply_catalog_live/show.ex`:

```elixir
defmodule EmakolaWeb.Admin.SupplyCatalogLive.Show do
  @moduledoc """
  Supplier offer detail. Product info, suggested retail, per-area dispatch
  fees, and supplier terms are always visible; wholesale price, margin, and
  the import action are gated behind an approved supply connection. The gate
  is enforced server-side in the import handler, not just hidden in markup.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(%{"offer_id" => offer_id}, _session, socket) do
    socket = assign(socket, page_title: "Supplier offer", active_nav: :supply_catalog)

    if connected?(socket) do
      case load_offer(socket, offer_id) do
        {:ok, assigns} ->
          {:ok, assign(socket, Map.put(assigns, :loading, false))}

        {:error, _} ->
          {:ok,
           socket
           |> put_flash(:error, "This offer is no longer available.")
           |> push_navigate(to: ~p"/admin/supply/catalog")}
      end
    else
      {:ok, assign(socket, loading: true, offer: nil, connection_status: :none)}
    end
  end

  defp load_offer(socket, offer_id) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, %{offer: offer, connection_status: status}} <-
           Offers.get_discoverable(socket.assigns.current_merchant, store_id, offer_id) do
      {:ok, %{offer: offer, connection_status: status, offer_id: offer_id}}
    else
      _ -> {:error, :not_found}
    end
  end

  defp margin(variant), do: variant.suggested_retail_price - variant.supplier_price

  defp margin_pct(variant) do
    Float.round(margin(variant) * 100 / variant.supplier_price, 1)
  end

  defp sorted_images(product) do
    Enum.sort_by(product.images || [], &Map.get(&1, :position, 0))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading offer…</div>

      <div :if={!@loading and @offer} class="space-y-6">
        <.link
          navigate={~p"/admin/supply/catalog"}
          class="text-sm text-slate-500 hover:text-slate-700"
        >
          ← Supplier catalog
        </.link>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Gallery --%>
          <div class="space-y-2">
            <div class="aspect-square rounded-2xl bg-slate-100 overflow-hidden">
              <img
                :if={sorted_images(@offer.source_product) != []}
                src={List.first(sorted_images(@offer.source_product)).url}
                alt={@offer.source_product.title}
                class="w-full h-full object-cover"
              />
            </div>
            <div :if={length(sorted_images(@offer.source_product)) > 1} class="flex gap-2">
              <img
                :for={img <- Enum.drop(sorted_images(@offer.source_product), 1)}
                src={img.thumbnail_url || img.url}
                alt=""
                class="w-16 h-16 rounded-lg object-cover bg-slate-100"
              />
            </div>
          </div>

          <%!-- Summary + CTA --%>
          <div class="space-y-4">
            <div>
              <h1 class="text-2xl font-bold text-slate-900">{@offer.source_product.title}</h1>
              <p class="text-sm text-slate-500 mt-1">
                Supplied by <span class="font-medium">{@offer.wholesaler_store.name}</span>
                <span
                  :if={@connection_status == :connected}
                  class="ml-2 text-[10px] font-semibold uppercase tracking-wide text-emerald-700 bg-emerald-50 rounded-full px-2 py-0.5"
                >
                  Connected
                </span>
              </p>
            </div>

            <p :if={@offer.source_product.description} class="text-sm text-slate-600">
              {@offer.source_product.description}
            </p>

            <%!-- CTA block (activated in later tasks) --%>
            <div id="catalog-cta" class="rounded-2xl border border-slate-200 p-4 space-y-2">
              <p :if={@connection_status != :connected} class="text-sm text-slate-600">
                Connect to see wholesale pricing and add this product to your store.
              </p>
            </div>

            <%!-- Dispatch fees --%>
            <div class="rounded-2xl border border-slate-200 overflow-hidden">
              <p class="px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-slate-500 bg-slate-50">
                Dispatch cost by area
              </p>
              <div class="divide-y divide-slate-100">
                <div
                  :for={area <- @offer.delivery_areas}
                  class="flex items-center justify-between px-4 py-2.5 text-sm"
                >
                  <span class="text-slate-700">{area}</span>
                  <span :if={@offer.dispatch_fees[area]} class="font-medium text-slate-900">
                    {format_price(@offer.dispatch_fees[area])}
                  </span>
                  <span :if={is_nil(@offer.dispatch_fees[area])} class="text-slate-400">
                    — (ask supplier)
                  </span>
                </div>
              </div>
            </div>

            <%!-- Supplier terms --%>
            <div class="rounded-2xl border border-slate-200 p-4 space-y-2 text-sm">
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                Supplier terms
              </p>
              <p :if={@offer.returns_window_days} class="text-slate-700">
                Returns window: {@offer.returns_window_days} days
              </p>
              <p :if={@offer.return_terms} class="text-slate-600">{@offer.return_terms}</p>
              <p :if={@offer.warranty_months} class="text-slate-700">
                Warranty: {@offer.warranty_months} months
              </p>
              <p :if={@offer.warranty_terms} class="text-slate-600">{@offer.warranty_terms}</p>
            </div>
          </div>
        </div>

        <%!-- Variants table --%>
        <div class="rounded-2xl border border-slate-200 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-slate-500 bg-slate-50">
                <th class="px-4 py-2.5">Variant</th>
                <th class="px-4 py-2.5 text-right">Suggested retail</th>
                <th class="px-4 py-2.5 text-right">Wholesale</th>
                <th class="px-4 py-2.5 text-right">
                  {if @offer.earning_model == :fixed_commission, do: "Commission", else: "Your margin"}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={variant <- @offer.offer_variants}>
                <td class="px-4 py-3 text-slate-700">
                  {variant.source_variant.sku || "Default"}
                </td>
                <td class="px-4 py-3 text-right font-medium text-slate-900">
                  {format_price(variant.suggested_retail_price)}
                  <span
                    :if={@connection_status == :connected and variant.max_retail_price}
                    class="block text-[11px] font-normal text-slate-400"
                  >
                    cap {format_price(variant.max_retail_price)}
                  </span>
                </td>
                <%= if @connection_status == :connected do %>
                  <td class="px-4 py-3 text-right text-slate-900">
                    {format_price(variant.supplier_price)}
                  </td>
                  <td class="px-4 py-3 text-right text-emerald-700 font-medium">
                    <%= if @offer.earning_model == :fixed_commission do %>
                      {format_price(variant.fixed_commission_amount || 0)}
                    <% else %>
                      {format_price(margin(variant))} ({margin_pct(variant)}%)
                    <% end %>
                  </td>
                <% else %>
                  <td class="px-4 py-3 text-right text-slate-300">
                    <span class="inline-flex items-center gap-1">🔒</span>
                  </td>
                  <td class="px-4 py-3 text-right text-slate-300">🔒</td>
                <% end %>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
```

The CTA block intentionally has no buttons yet — Task 6 adds "Request connection" / "Request sent", Task 7 adds "Add to my store", each together with its `handle_event`. BUT the Task 5 tests assert the CTA strings — so Step 3 must ALSO include the button markup below inside `#catalog-cta`, while Steps in Tasks 6–7 add the `handle_event` clauses. To keep "every rendered button has a handler" true, render Task 5's buttons with `disabled` and NO `phx-click`; Tasks 6–7 replace them with live buttons:

```heex
              <button
                :if={@connection_status == :none}
                disabled
                class="w-full rounded-xl bg-emerald-600 text-white text-sm font-semibold px-4 py-2.5 opacity-90"
              >
                Request connection
              </button>
              <button
                :if={@connection_status == :pending}
                disabled
                class="w-full rounded-xl bg-slate-200 text-slate-500 text-sm font-semibold px-4 py-2.5"
              >
                Request sent
              </button>
              <button
                :if={@connection_status == :connected}
                disabled
                class="w-full rounded-xl bg-emerald-600 text-white text-sm font-semibold px-4 py-2.5 opacity-90"
              >
                Add to my store
              </button>
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format
git add -A && git commit -m "feat(web): supplier offer detail with connection-gated pricing"
```

---

### Task 6: "Request connection" action

**Files:**
- Modify: `lib/emakola_web/live/admin/supply_catalog_live/show.ex`
- Test: `test/emakola_web/live/admin/supply_catalog_live_test.exs` (append)

**Interfaces:**
- Consumes: `Emakola.Suppliers.Network.request/2` — attrs `%{wholesaler_store_id, reseller_store_id, requested_by_store_id}`, returns `{:ok, %SupplyConnection{status: :pending}}` or `{:error, reason}`.
- Produces: event `"request_connection"` on the Show LiveView.

- [ ] **Step 1: Write the failing test** — append inside `describe "catalog show"`:

```elixir
    test "request_connection creates a pending connection and flips the CTA", %{
      conn: conn,
      reseller: reseller
    } do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      html =
        view
        |> element("button[phx-click=request_connection]")
        |> render_click()

      assert html =~ "Request sent"

      require Ash.Query

      assert [%{status: :pending}] =
               Emakola.Suppliers.SupplyConnection
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and
                   wholesaler_store_id == ^fixture.wholesaler.id
               )
               |> Ash.read!(authorize?: false)
    end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: FAIL — no element matches `button[phx-click=request_connection]`.

- [ ] **Step 3: Implement** — in `show.ex`, replace the disabled `:none` button with:

```heex
              <button
                :if={@connection_status == :none}
                phx-click="request_connection"
                class="w-full rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
              >
                Request connection
              </button>
```

Add the handler after `handle_event` for search... (this module has none yet — place after `mount/3`):

```elixir
  @impl true
  def handle_event("request_connection", _params, socket) do
    store = socket.assigns.current_store

    result =
      Emakola.Suppliers.Network.request(socket.assigns.current_merchant, %{
        wholesaler_store_id: socket.assigns.offer.wholesaler_store_id,
        reseller_store_id: store.id,
        requested_by_store_id: store.id
      })

    case result do
      {:ok, _connection} ->
        {:noreply,
         socket
         |> assign(connection_status: :pending)
         |> put_flash(:info, "Connection requested. The supplier will review it.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not request this connection right now.")}
    end
  end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format
git add -A && git commit -m "feat(web): request supplier connection from the catalog detail page"
```

---

### Task 7: "Add to my store" action with server-side gate + PR

**Files:**
- Modify: `lib/emakola_web/live/admin/supply_catalog_live/show.ex`
- Test: `test/emakola_web/live/admin/supply_catalog_live_test.exs` (append)

**Interfaces:**
- Consumes: `Emakola.Suppliers.ListingImporter.import(actor, reseller_store_id, offer)` → `{:ok, listing}` / `{:error, :listing_exists}` / `{:error, _}`; `Offers.get_discoverable/3` for the server-side re-check; `Emakola.Suppliers.ResellerListing` for assertions.
- Produces: event `"import_offer"`; feature complete.

- [ ] **Step 1: Write the failing tests** — append inside `describe "catalog show"`:

```elixir
    test "import_offer creates a reseller listing when connected", %{
      conn: conn,
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      fixture = create_published_offer!()
      connect!(reseller_actor, reseller, fixture)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      html =
        view
        |> element("button[phx-click=import_offer]")
        |> render_click()

      assert html =~ "added to your store"

      require Ash.Query

      assert [_listing] =
               Emakola.Suppliers.ResellerListing
               |> Ash.Query.filter(
                 reseller_store_id == ^reseller.id and offer_id == ^fixture.offer.id
               )
               |> Ash.read!(authorize?: false)
    end

    test "import_offer is rejected server-side when not connected", %{
      conn: conn,
      reseller: reseller
    } do
      fixture = create_published_offer!()

      {:ok, view, _html} = live(conn, ~p"/admin/supply/catalog/#{fixture.offer.id}")

      # No import button is rendered, but a crafted event must ALSO be
      # rejected — the gate is server-side, not markup-deep.
      html = render_click(view, "import_offer", %{})

      refute html =~ "added to your store"

      require Ash.Query

      assert [] =
               Emakola.Suppliers.ResellerListing
               |> Ash.Query.filter(reseller_store_id == ^reseller.id)
               |> Ash.read!(authorize?: false)
    end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs`
Expected: FAIL — no element matches `button[phx-click=import_offer]` (first test); crafted event crashes the view (second test — no handler clause yet).

- [ ] **Step 3: Implement** — replace the disabled `:connected` button:

```heex
              <button
                :if={@connection_status == :connected}
                phx-click="import_offer"
                class="w-full rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
              >
                Add to my store
              </button>
```

Add the handler (after `request_connection`):

```elixir
  @impl true
  def handle_event("import_offer", _params, socket) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store

    # Server-side gate: re-check discoverability AND the connection before
    # importing — a crafted event must not bypass the markup gate.
    with {:ok, %{offer: offer, connection_status: :connected}} <-
           Offers.get_discoverable(actor, store.id, socket.assigns.offer_id),
         {:ok, _listing} <- Emakola.Suppliers.ListingImporter.import(actor, store.id, offer) do
      {:noreply,
       put_flash(socket, :info, "Product added to your store. Its images are being prepared.")}
    else
      {:error, :listing_exists} ->
        {:noreply, put_flash(socket, :info, "Already in your store.")}

      {:ok, %{connection_status: _not_connected}} ->
        {:noreply, put_flash(socket, :error, "Connect with this supplier first.")}

      _ ->
        {:noreply, put_flash(socket, :error, "This product could not be added right now.")}
    end
  end
```

- [ ] **Step 4: Run the feature tests, then the full suite**

Run: `mix test test/emakola_web/live/admin/supply_catalog_live_test.exs test/emakola/suppliers/`
Expected: PASS.

Run: `mix test`
Expected: `0 failures` on the "Result:" line (do not trust the exit code — parse the line).

- [ ] **Step 5: Quality gates + commit + PR**

```bash
mix format --check-formatted
mix credo --strict lib/emakola/suppliers/offers.ex lib/emakola/suppliers/validations/dispatch_fees.ex lib/emakola_web/live/admin/supply_catalog_live/index.ex lib/emakola_web/live/admin/supply_catalog_live/show.ex
git add -A && git commit -m "feat(web): import supplier offers from the catalog with a server-side gate"
git push -u origin feature/supplier-catalog
gh pr create --title "feat(catalog): merchant-facing supplier product catalog" --body "..."
```

PR body should cover: browse-all + gated pricing decision, per-area dispatch fees, the two new service functions, server-side import gate, and the out-of-scope follow-ups from the spec (supplier fee-entry UI, checkout integration, pagination).
