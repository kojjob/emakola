# Supplier Offer Management UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any merchant can create, price (markup or fixed-commission), publish, pause, and edit supplier offers — including per-area dispatch fees — from the admin, with no console involvement.

**Architecture:** Two small domain additions (`SupplierOfferVariant` update/destroy + `Offers.update_variant/remove_variant`, draft/paused-only), a canonical Ghana-regions constant, and two LiveViews mirroring the catalog pattern (`Admin.SupplyOffersLive.Index` + `.Form`). All writes via the `Offers` service. Spec: `docs/superpowers/specs/2026-07-23-supplier-offer-management-design.md`.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x, TailwindCSS, ExUnit.

## Global Constraints

- Branch: `feature/supplier-offer-management` (created; spec committed).
- All money integer **pesewas**; form input parsed via `Emakola.Money.parse_price/1` (returns `{:ok, pesewas} | :skip | :zero | :error`); display via `EmakolaWeb.Helpers.Currency.format_price/1` (drops decimals on round-hundred amounts — never assert "45.00"-style literals in tests).
- TDD: failing test first for every behavior; `mix format` before each commit; conventional commits.
- No `authorize?: false` in the web layer for WRITES — all writes via `Emakola.Suppliers.Offers`. Reads of the store's own products may use the established `Ash.Query.for_read(:list_admin, ...)` admin pattern.
- Every rendered event has an explicit `handle_event`; handlers guard payload shapes (binary checks, `Money.parse_price`, membership in known sets) — crafted payloads no-op or flash, never crash.
- `connected?/1`-gated mounts (loading shell on dead render).
- `mix compile --warnings-as-errors` per task (touch edited files first — incremental compile hides warnings).
- Variant economics editable ONLY while offer status ∈ {:draft, :paused}; `{:error, :offer_not_editable}` otherwise.
- Ghana regions canonical list (order fixed, strings exact):
  `["Greater Accra", "Ashanti", "Western", "Western North", "Central", "Eastern", "Volta", "Oti", "Northern", "Savannah", "North East", "Upper East", "Upper West", "Bono", "Bono East", "Ahafo"]`

---

### Task 1: Domain — variant editing + regions constant + richer owned preload

**Files:**
- Modify: `lib/emakola/suppliers/resources/supplier_offer_variant.ex` (actions block, ~line 71)
- Modify: `lib/emakola/suppliers/resources/supplier_offer.ex` (`read :owned_by_store` prepare, ~line 160)
- Modify: `lib/emakola/suppliers/offers.ex`
- Create: `lib/emakola/suppliers/ghana_regions.ex`
- Test: `test/emakola/suppliers/offers_test.exs` (append describe)

**Interfaces:**
- Consumes: existing `Offers.add_variant/3`, `ensure_access/2`, test helpers `draft_offer!/3`, `publish_offer!/2` (explicit `product:`/`variant:` opts), fixtures `product_2`/`variant_2`.
- Produces:
  - `Offers.update_variant(actor, offer, variant, attrs) :: {:ok, variant} | {:error, :offer_not_editable | :forbidden | term}`
  - `Offers.remove_variant(actor, offer, variant) :: :ok | {:error, :offer_not_editable | :forbidden | term}`
  - `Emakola.Suppliers.GhanaRegions.all/0 :: [String.t()]` (the canonical 16, in the Global Constraints order)
  - `owned_by_store` read now loads `[source_product: :images, offer_variants: :source_variant]`

- [ ] **Step 1: Write the failing tests** — append to `test/emakola/suppliers/offers_test.exs` before the private helpers:

```elixir
  describe "update_variant/4 and remove_variant/3" do
    test "reprices and removes variants while the offer is a draft", context do
      offer = draft_offer!(context, :markup)

      {:ok, terms} =
        Offers.add_variant(context.wholesaler_actor, offer, %{
          source_variant_id: context.variant.id,
          supplier_price: 3_000,
          suggested_retail_price: 4_000
        })

      assert {:ok, updated} =
               Offers.update_variant(context.wholesaler_actor, offer, terms, %{
                 supplier_price: 3_200,
                 suggested_retail_price: 4_800
               })

      assert updated.supplier_price == 3_200

      assert :ok = Offers.remove_variant(context.wholesaler_actor, offer, updated)

      assert {:error, :offer_requires_variants} =
               Offers.publish(context.wholesaler_actor, offer)
    end

    test "allows editing while paused, and republish re-validates economics", context do
      published = publish_offer!(context)
      {:ok, paused} = Offers.pause(context.wholesaler_actor, published)

      [terms] = paused |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)

      assert {:ok, _} =
               Offers.update_variant(context.wholesaler_actor, paused, terms, %{
                 supplier_price: 3_500,
                 suggested_retail_price: 3_400
               })

      assert {:error, :invalid_offer_economics} =
               Offers.publish(context.wholesaler_actor, paused)
    end

    test "rejects edits on published offers and for foreign actors", context do
      published = publish_offer!(context)

      [terms] =
        published |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)

      assert {:error, :offer_not_editable} =
               Offers.update_variant(context.wholesaler_actor, published, terms, %{
                 supplier_price: 1
               })

      assert {:error, :offer_not_editable} =
               Offers.remove_variant(context.wholesaler_actor, published, terms)

      {:ok, paused} = Offers.pause(context.wholesaler_actor, published)

      assert {:error, :forbidden} =
               Offers.update_variant(context.reseller_actor, paused, terms, %{supplier_price: 1})
    end
  end

  describe "GhanaRegions" do
    test "exposes the 16 canonical regions" do
      regions = Emakola.Suppliers.GhanaRegions.all()
      assert length(regions) == 16
      assert "Greater Accra" in regions
      assert "Bono East" in regions
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: FAIL — `Offers.update_variant/4 is undefined`, `GhanaRegions` module missing.

- [ ] **Step 3: Variant resource actions** — in `lib/emakola/suppliers/resources/supplier_offer_variant.ex`, extend the `actions do` block:

```elixir
    update :update_terms do
      require_atomic?(false)

      accept([
        :supplier_price,
        :suggested_retail_price,
        :max_retail_price,
        :fixed_commission_amount
      ])
    end

    destroy(:destroy)
```

- [ ] **Step 4: Richer owned preload** — in `lib/emakola/suppliers/resources/supplier_offer.ex`, change the `read :owned_by_store` prepare to:

```elixir
      prepare(
        build(
          sort: [inserted_at: :desc],
          load: [source_product: :images, offer_variants: :source_variant]
        )
      )
```

- [ ] **Step 5: Regions constant** — create `lib/emakola/suppliers/ghana_regions.ex`:

```elixir
defmodule Emakola.Suppliers.GhanaRegions do
  @moduledoc """
  Canonical delivery-area names for supplier offers. Using one fixed list
  keeps `dispatch_fees` keys consistent across suppliers (the DispatchFees
  validation requires fee keys ⊆ delivery_areas, and future filtering by
  area depends on exact string equality).
  """

  @regions [
    "Greater Accra",
    "Ashanti",
    "Western",
    "Western North",
    "Central",
    "Eastern",
    "Volta",
    "Oti",
    "Northern",
    "Savannah",
    "North East",
    "Upper East",
    "Upper West",
    "Bono",
    "Bono East",
    "Ahafo"
  ]

  @spec all() :: [String.t()]
  def all, do: @regions
end
```

- [ ] **Step 6: Service functions** — in `lib/emakola/suppliers/offers.ex`, after `add_variant/3`:

```elixir
  @doc """
  Reprices one variant's terms. Allowed only while the offer is editable
  (`:draft` or `:paused`) — published economics are locked because importers
  priced against them; republish re-validates economics.
  """
  def update_variant(actor, offer, variant, attrs) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         :ok <- ensure_editable(offer) do
      variant
      |> Ash.Changeset.for_update(:update_terms, attrs)
      |> Ash.update(authorize?: false)
    end
  end

  @doc "Removes one variant's terms from an editable (draft/paused) offer."
  def remove_variant(actor, offer, variant) do
    with :ok <- ensure_access(actor, offer.wholesaler_store_id),
         :ok <- ensure_editable(offer) do
      variant
      |> Ash.Changeset.for_destroy(:destroy)
      |> Ash.destroy(authorize?: false)
    end
  end

  defp ensure_editable(%{status: status}) when status in [:draft, :paused], do: :ok
  defp ensure_editable(_offer), do: {:error, :offer_not_editable}
```

- [ ] **Step 7: Run tests**

Run: `mix test test/emakola/suppliers/offers_test.exs`
Expected: PASS. (If the foreign-actor test returns a different error shape than `{:error, :forbidden}`, check what `ensure_access/2` actually returns in this module and match the test to it — the existing "rejects catalog records owned by another store" tests show the convention.)

- [ ] **Step 8: Commit**

```bash
mix format
mix compile --warnings-as-errors
git add -A && git commit -m "feat(catalog): draft/paused supplier offers support variant repricing"
```

---

### Task 2: Offers Index + routes + sidebar + Earn-catalog banner

**Files:**
- Create: `lib/emakola_web/live/admin/supply_offers_live/index.ex`
- Modify: `lib/emakola_web/router.ex` (add routes beside the supply catalog routes)
- Modify: `lib/emakola_web/components/sidebar_components.ex` ("My Offers" entry; re-icon Supplier Catalog)
- Modify: `lib/emakola_web/live/admin/supply_network_live.ex` (one banner line in the Earn-catalog section)
- Test: `test/emakola_web/live/admin/supply_offers_live_test.exs` (create)

**Interfaces:**
- Consumes: `Offers.list_owned(actor, store_id) :: {:ok, [offer]}` (now loading `source_product: :images, offer_variants: :source_variant`); `Offers.publish/2`, `Offers.pause/2`, `Offers.archive/2`; `EmakolaWeb.Helpers.Currency.format_price/1`; admin live_session assigns `:current_merchant`/`:current_store`.
- Produces: routes `/admin/supply/offers`, `/admin/supply/offers/new`, `/admin/supply/offers/:id/edit` (Form module arrives in Task 3 — if `mix compile` rejects the two Form routes before the module exists, add only the Index route now and move the Form routes to Task 3); `active_nav: :supply_offers`; events `publish_offer`, `pause_offer`, `archive_offer` (each takes `%{"id" => id}`).

- [ ] **Step 1: Write the failing tests** — create `test/emakola_web/live/admin/supply_offers_live_test.exs`:

```elixir
defmodule EmakolaWeb.Admin.SupplyOffersLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Suppliers.Offers

  describe "unauthenticated" do
    test "redirects to login", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/supply/offers")
    end
  end

  describe "offers index" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Supply Side"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders with an empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers")

      assert html =~ "My Offers"
      assert html =~ "New offer"
    end

    test "lists an owned draft with its status and actions", %{
      conn: conn,
      merchant: merchant,
      store: store
    } do
      _offer = create_draft_offer!(merchant, store, "Shea Butter 500g")

      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers")

      assert html =~ "Shea Butter 500g"
      assert html =~ "Draft"
      assert html =~ "Publish"
    end

    test "publishes a draft from the index", %{conn: conn, merchant: merchant, store: store} do
      offer = create_draft_offer!(merchant, store, "Kente Stole")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html =
        view
        |> element(~s{button[phx-click=publish_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Published"
      assert html =~ "Pause"
    end

    test "pauses and republishes", %{conn: conn, merchant: merchant, store: store} do
      offer = create_draft_offer!(merchant, store, "Bolga Basket")
      {:ok, _} = Offers.publish(merchant, offer)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html =
        view
        |> element(~s{button[phx-click=pause_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Paused"
      assert html =~ "Republish"

      html =
        view
        |> element(~s{button[phx-click=publish_offer][phx-value-id="#{offer.id}"]})
        |> render_click()

      assert html =~ "Published"
    end

    test "a crafted event with a foreign offer id flashes and changes nothing", %{
      conn: conn,
      merchant: merchant,
      store: store
    } do
      _own = create_draft_offer!(merchant, store, "Adinkra Tote")

      {other_merchant, other_store} = Factory.create_merchant_with_store!()
      foreign = create_draft_offer!(other_merchant, other_store, "Foreign Offer")

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers")

      html = render_click(view, "publish_offer", %{"id" => foreign.id})

      refute html =~ "Published"

      reloaded = Ash.get!(Emakola.Suppliers.SupplierOffer, foreign.id, authorize?: false)
      assert reloaded.status == :draft
    end
  end

  # -- fixtures ---------------------------------------------------------------

  def create_draft_offer!(merchant, store, title) do
    product = Factory.create_product!(store, status: :active, title: title)
    variant = Factory.create_variant!(product, store, price: 5_000, stock_quantity: 10)

    {:ok, offer} =
      Offers.create_draft(merchant, %{
        wholesaler_store_id: store.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: ["Greater Accra"]
      })

    {:ok, _} =
      Offers.add_variant(merchant, offer, %{
        source_variant_id: variant.id,
        supplier_price: 3_000,
        suggested_retail_price: 4_500
      })

    offer
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: FAIL — no route matches `/admin/supply/offers`.

- [ ] **Step 3: Routes** — in `lib/emakola_web/router.ex`, directly under the supply-catalog routes:

```elixir
      live "/admin/supply/offers", Admin.SupplyOffersLive.Index
      live "/admin/supply/offers/new", Admin.SupplyOffersLive.Form, :new
      live "/admin/supply/offers/:id/edit", Admin.SupplyOffersLive.Form, :edit
```

(Form module lands in Task 3; see Interfaces note if compile rejects the two Form routes — then use plain-string `href`s for form links in this task and restore `~p` in Task 3, marked with the same `<%!-- TEMP --%>` convention used in the catalog build.)

- [ ] **Step 4: Sidebar** — in `lib/emakola_web/components/sidebar_components.ex`: change the "Supplier Catalog" entry's icon from `"truck"` to `"package"`, and add below it:

```heex
        <.sidebar_link
          href="/admin/supply/offers"
          title="My Offers"
          icon="tag"
          active={@active_nav == :supply_offers}
        />
```

- [ ] **Step 5: Earn-catalog banner** — in `lib/emakola_web/live/admin/supply_network_live.ex`, find the Earn-catalog section heading in the template (search for "Earn catalog" or the section rendered from `load_earn_catalog`) and add directly under the section heading:

```heex
        <p class="text-xs text-slate-500 mb-3">
          Browsing has moved:
          <.link navigate="/admin/supply/catalog" class="text-emerald-700 font-medium">
            Supplier Catalog
          </.link>
          · manage your own offers in
          <.link navigate="/admin/supply/offers" class="text-emerald-700 font-medium">
            My Offers
          </.link>
        </p>
```

- [ ] **Step 6: Index LiveView** — create `lib/emakola_web/live/admin/supply_offers_live/index.ex`:

```elixir
defmodule EmakolaWeb.Admin.SupplyOffersLive.Index do
  @moduledoc """
  The store's own supplier offers: status, per-status lifecycle actions,
  and the entry point to the offer form. All writes go through
  Emakola.Suppliers.Offers.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Suppliers.Offers

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, page_title: "My Offers", active_nav: :supply_offers)

    socket =
      if connected?(socket) do
        assign(socket, loading: false, offers: load_offers(socket))
      else
        assign(socket, loading: true, offers: [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("publish_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.publish/2, "Offer published — it is now live in the catalog.")
  end

  def handle_event("pause_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.pause/2, "Offer paused — hidden from the catalog.")
  end

  def handle_event("archive_offer", %{"id" => id}, socket) when is_binary(id) do
    lifecycle(socket, id, &Offers.archive/2, "Offer archived.")
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp lifecycle(socket, id, fun, success_message) do
    actor = socket.assigns.current_merchant

    with %{} = offer <- Enum.find(socket.assigns.offers, &(&1.id == id)),
         {:ok, _} <- fun.(actor, offer) do
      {:noreply,
       socket
       |> assign(offers: load_offers(socket))
       |> put_flash(:info, success_message)}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "That offer is not in your store.")}

      {:error, :invalid_offer_economics} ->
        {:noreply,
         put_flash(socket, :error, "Fix the pricing first — every priced variant needs valid economics.")}

      {:error, :offer_requires_variants} ->
        {:noreply, put_flash(socket, :error, "Add at least one priced variant before publishing.")}

      {:error, :offer_requires_available_variant} ->
        {:noreply,
         put_flash(socket, :error, "The source product has no available stock to offer.")}

      {:error, :source_product_not_sellable} ->
        {:noreply,
         put_flash(socket, :error, "The source product must be active before publishing.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "That change could not be applied right now.")}
    end
  end

  defp load_offers(socket) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, offers} <- Offers.list_owned(socket.assigns.current_merchant, store_id) do
      offers
    else
      _ -> []
    end
  end

  defp status_label(:draft), do: "Draft"
  defp status_label(:published), do: "Published"
  defp status_label(:paused), do: "Paused"
  defp status_label(:archived), do: "Archived"

  defp status_class(:draft), do: "bg-slate-100 text-slate-600"
  defp status_class(:published), do: "bg-emerald-50 text-emerald-700"
  defp status_class(:paused), do: "bg-amber-50 text-amber-700"
  defp status_class(:archived), do: "bg-slate-100 text-slate-400"

  defp price_summary(offer) do
    case offer.offer_variants do
      [] ->
        "No priced variants"

      variants ->
        prices = Enum.map(variants, & &1.supplier_price)
        {min, max} = {Enum.min(prices), Enum.max(prices)}

        if min == max,
          do: "#{format_price(min)} wholesale",
          else: "#{format_price(min)} – #{format_price(max)} wholesale"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div class="flex items-end justify-between gap-3 mb-6 pt-2">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">My Offers</h1>
          <p class="text-sm text-slate-500 mt-1">
            Products you supply to other stores on the network
          </p>
        </div>
        <.link
          navigate={~p"/admin/supply/offers/new"}
          class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-4 py-2.5"
        >
          New offer
        </.link>
      </div>

      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading…</div>

      <div
        :if={!@loading and @offers == []}
        class="rounded-2xl border border-dashed border-slate-300 py-16 text-center"
      >
        <p class="text-sm font-medium text-slate-700">You have no supplier offers yet.</p>
        <p class="text-xs text-slate-500 mt-1 max-w-md mx-auto">
          Publish an offer and any merchant on the network can find it in the
          <.link navigate={~p"/admin/supply/catalog"} class="text-emerald-700">
            Supplier Catalog
          </.link>
          and stock your product in their store.
        </p>
      </div>

      <div :if={!@loading} class="space-y-3">
        <div
          :for={offer <- @offers}
          class="rounded-2xl border border-slate-200 bg-white p-4 flex flex-wrap items-center gap-4"
        >
          <div class="min-w-0 flex-1">
            <p class="font-semibold text-sm text-slate-900 truncate">
              {offer.source_product.title}
            </p>
            <p class="text-xs text-slate-500 mt-0.5">
              {length(offer.offer_variants)} variant(s) · {price_summary(offer)} ·
              {if offer.earning_model == :markup, do: "Markup", else: "Fixed commission"}
            </p>
          </div>
          <span class={[
            "text-[10px] font-semibold uppercase tracking-wide rounded-full px-2 py-0.5",
            status_class(offer.status)
          ]}>
            {status_label(offer.status)}
          </span>
          <div class="flex items-center gap-2">
            <.link
              :if={offer.status in [:draft, :paused]}
              navigate={~p"/admin/supply/offers/#{offer.id}/edit"}
              class="text-sm font-medium text-slate-600 hover:text-slate-900"
            >
              Edit
            </.link>
            <.link
              :if={offer.status == :published}
              navigate={~p"/admin/supply/offers/#{offer.id}/edit"}
              class="text-sm font-medium text-slate-600 hover:text-slate-900"
            >
              Edit terms
            </.link>
            <button
              :if={offer.status in [:draft, :paused]}
              phx-click="publish_offer"
              phx-value-id={offer.id}
              class="text-sm font-semibold text-emerald-700 hover:text-emerald-800"
            >
              {if offer.status == :paused, do: "Republish", else: "Publish"}
            </button>
            <button
              :if={offer.status == :published}
              phx-click="pause_offer"
              phx-value-id={offer.id}
              class="text-sm font-semibold text-amber-700 hover:text-amber-800"
            >
              Pause
            </button>
            <button
              :if={offer.status != :archived}
              phx-click="archive_offer"
              phx-value-id={offer.id}
              class="text-sm font-medium text-slate-400 hover:text-slate-600"
            >
              Archive
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 7: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
mix format
mix compile --warnings-as-errors
git add -A && git commit -m "feat(web): supplier offers index with lifecycle actions"
```

---

### Task 3: Form LiveView — new draft, markup pricing, regions/fees, save

**Files:**
- Create: `lib/emakola_web/live/admin/supply_offers_live/form.ex`
- Modify: `lib/emakola_web/router.ex` ONLY if the Form routes were deferred in Task 2.
- Test: `test/emakola_web/live/admin/supply_offers_live_test.exs` (append describe)

**Interfaces:**
- Consumes: `Offers.create_draft/2`, `add_variant/3`, `update_terms/3` (accepts `delivery_areas`, `dispatch_fees`, `return_terms`, `returns_window_days`, `warranty_months`, `warranty_terms`); `Emakola.Suppliers.GhanaRegions.all/0`; `Emakola.Money.parse_price/1`; product reads via `Ash.Query.for_read(:list_admin, %{store_id: store_id, search: nil, status: :active})` + `Ash.Query.load(:variants)`.
- Produces: the Form LiveView handling `:new` (product picker + model radio + full form → "Save draft" creates draft + priced variants + terms, then navigates to edit) and the `:edit` load path for draft offers. Events: `select_product`, `select_model`, `set_variant_price` (`%{"variant-id" => id, "field" => f, "value" => v}` via `phx-change` per input using `phx-value-*` + `name="value"`), `toggle_region` (`%{"region" => r}`), `set_region_fee` (`%{"region" => r, "value" => v}`), `set_term` (`%{"field" => f, "value" => v}`), `save_draft`, plus a final no-op catch-all. Publish/restricted-edit arrive in Task 4.

**Form state model (assigns):** `action`, `offer` (nil for new until saved), `products` (picker, :new only), `product` (chosen product struct with variants), `model` (`"markup"`/`"fixed_commission"`), `rows` (map of source_variant_id → `%{"supplier" => str, "suggested" => str, "max" => str, "commission" => str, terms_id: nil | variant_terms_id}`), `areas` (MapSet of region strings), `fees` (map region → string), `terms` (map of the 4 term fields → string), `errors` (map), `locked?` (false in this task).

- [ ] **Step 1: Write the failing tests** — append:

```elixir
  describe "offer form (new, markup)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Form Supply"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      product = Factory.create_product!(store, status: :active, title: "Baobab Oil 250ml")
      variant = Factory.create_variant!(product, store, price: 6_000, sku: "BAO-250", stock_quantity: 12)

      %{conn: conn, merchant: merchant, store: store, product: product, variant: variant}
    end

    test "renders the form shell", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/supply/offers/new")

      assert html =~ "New offer"
      assert html =~ "Baobab Oil 250ml"
      assert html =~ "Greater Accra"
    end

    test "save draft creates the offer with priced variant, regions, and fees", %{
      conn: conn,
      store: store,
      variant: variant,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "38.00"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "60"
      })

      render_click(view, "toggle_region", %{"region" => "Greater Accra"})
      render_change(view, "set_region_fee", %{"region" => "Greater Accra", "value" => "15"})
      render_change(view, "set_term", %{"field" => "return_terms", "value" => "7-day returns"})

      view |> element("button[phx-click=save_draft]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(wholesaler_store_id == ^store.id)
        |> Ash.Query.load(:offer_variants)
        |> Ash.read!(authorize?: false)

      assert offer.status == :draft
      assert offer.delivery_areas == ["Greater Accra"]
      assert offer.dispatch_fees == %{"Greater Accra" => 1_500}
      assert offer.return_terms == "7-day returns"
      assert [terms] = offer.offer_variants
      assert terms.supplier_price == 3_800
      assert terms.suggested_retail_price == 6_000
    end

    test "an unparseable price shows an error and does not save", %{
      conn: conn,
      store: store,
      variant: variant,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "abc"
      })

      html = view |> element("button[phx-click=save_draft]") |> render_click()

      assert html =~ "must be a valid amount"

      require Ash.Query

      assert [] =
               Emakola.Suppliers.SupplierOffer
               |> Ash.Query.filter(wholesaler_store_id == ^store.id)
               |> Ash.read!(authorize?: false)
    end

    test "unchecking a region clears its fee", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})
      render_click(view, "toggle_region", %{"region" => "Volta"})
      render_change(view, "set_region_fee", %{"region" => "Volta", "value" => "9"})
      render_click(view, "toggle_region", %{"region" => "Volta"})
      html = render_click(view, "toggle_region", %{"region" => "Volta"})

      # re-checked region shows an empty fee input, not the stale "9"
      refute html =~ ~s(value="9")
    end

    test "a second offer for the same product is rejected with a helpful error", %{
      conn: conn,
      merchant: merchant,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, _existing} =
        Offers.create_draft(merchant, %{
          wholesaler_store_id: store.id,
          source_product_id: product.id,
          earning_model: :markup,
          delivery_areas: ["Greater Accra"]
        })

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "10"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "20"
      })

      html = view |> element("button[phx-click=save_draft]") |> render_click()

      assert html =~ "already have an offer for this product"
    end

    test "crafted payloads no-op instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{})
      render_change(view, "set_variant_price", %{"variant-id" => %{"x" => 1}})
      render_click(view, "toggle_region", %{"region" => "Atlantis"})
      render_change(view, "set_term", %{"field" => "not_a_field", "value" => "x"})

      assert render(view) =~ "New offer"
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: FAIL — Form module missing (or route error if deferred).

- [ ] **Step 3: Implement the Form** — create `lib/emakola_web/live/admin/supply_offers_live/form.ex`. Complete module (Task 4 extends it — publish + restricted edit):

```elixir
defmodule EmakolaWeb.Admin.SupplyOffersLive.Form do
  @moduledoc """
  Create/edit a supplier offer: product picker (locked after creation),
  earning-model-dependent variant pricing, Ghana-region delivery areas with
  optional per-area dispatch fees, and supplier terms. All writes go through
  Emakola.Suppliers.Offers; prices parse via Emakola.Money.parse_price/1.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Money
  alias Emakola.Suppliers.{GhanaRegions, Offers}

  require Ash.Query

  @term_fields ~w(return_terms returns_window_days warranty_months warranty_terms)
  @price_fields ~w(supplier suggested max commission)

  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, page_title: "Supplier offer", active_nav: :supply_offers)

    if connected?(socket) do
      init(socket, socket.assigns.live_action, params)
    else
      {:ok, assign(socket, loading: true, action: :new, offer: nil)}
    end
  end

  defp init(socket, :new, _params) do
    {:ok,
     socket
     |> base_assigns(:new)
     |> assign(products: load_products(socket), product: nil)}
  end

  defp init(socket, :edit, %{"id" => id}) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, offers} <- Offers.list_owned(socket.assigns.current_merchant, store_id),
         %{} = offer <- Enum.find(offers, &(&1.id == id && &1.status != :archived)) do
      {:ok,
       socket
       |> base_assigns(:edit)
       |> assign(products: [], product: offer.source_product)
       |> hydrate(offer)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That offer is not in your store.")
         |> push_navigate(to: ~p"/admin/supply/offers")}
    end
  end

  defp base_assigns(socket, action) do
    assign(socket,
      loading: false,
      action: action,
      offer: nil,
      product: nil,
      model: "markup",
      rows: %{},
      areas: MapSet.new(),
      fees: %{},
      terms: %{},
      errors: %{},
      locked?: false
    )
  end

  defp hydrate(socket, offer) do
    rows =
      Map.new(offer.offer_variants, fn terms ->
        {terms.source_variant_id,
         %{
           "supplier" => pesewas_to_input(terms.supplier_price),
           "suggested" => pesewas_to_input(terms.suggested_retail_price),
           "max" => pesewas_to_input(terms.max_retail_price),
           "commission" => pesewas_to_input(terms.fixed_commission_amount),
           terms_id: terms.id
         }}
      end)

    assign(socket,
      offer: offer,
      model: to_string(offer.earning_model),
      rows: rows,
      areas: MapSet.new(offer.delivery_areas),
      fees: Map.new(offer.dispatch_fees, fn {k, v} -> {k, pesewas_to_input(v)} end),
      terms: %{
        "return_terms" => offer.return_terms || "",
        "returns_window_days" => to_string(offer.returns_window_days || ""),
        "warranty_months" => to_string(offer.warranty_months || ""),
        "warranty_terms" => offer.warranty_terms || ""
      },
      locked?: offer.status == :published
    )
  end

  defp pesewas_to_input(nil), do: ""
  defp pesewas_to_input(pesewas), do: :erlang.float_to_binary(pesewas / 100, decimals: 2)

  # ── Events ──

  @impl true
  def handle_event("select_product", %{"product_id" => id}, socket) when is_binary(id) do
    case Enum.find(socket.assigns.products, &(&1.id == id)) do
      nil -> {:noreply, socket}
      product -> {:noreply, assign(socket, product: product, rows: %{})}
    end
  end

  def handle_event("select_model", %{"model" => model}, socket)
      when model in ["markup", "fixed_commission"] do
    if socket.assigns.offer do
      {:noreply, socket}
    else
      {:noreply, assign(socket, model: model)}
    end
  end

  def handle_event("set_variant_price", %{"variant-id" => vid, "field" => f, "value" => v}, socket)
      when is_binary(vid) and f in @price_fields and is_binary(v) do
    rows =
      Map.update(
        socket.assigns.rows,
        vid,
        %{"supplier" => "", "suggested" => "", "max" => "", "commission" => "", terms_id: nil}
        |> Map.put(f, v),
        &Map.put(&1, f, v)
      )

    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("toggle_region", %{"region" => region}, socket) when is_binary(region) do
    if region in GhanaRegions.all() do
      {areas, fees} =
        if MapSet.member?(socket.assigns.areas, region) do
          {MapSet.delete(socket.assigns.areas, region),
           Map.delete(socket.assigns.fees, region)}
        else
          {MapSet.put(socket.assigns.areas, region), socket.assigns.fees}
        end

      {:noreply, assign(socket, areas: areas, fees: fees)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_region_fee", %{"region" => region, "value" => v}, socket)
      when is_binary(region) and is_binary(v) do
    if MapSet.member?(socket.assigns.areas, region) do
      {:noreply, assign(socket, fees: Map.put(socket.assigns.fees, region, v))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_term", %{"field" => f, "value" => v}, socket)
      when f in @term_fields and is_binary(v) do
    {:noreply, assign(socket, terms: Map.put(socket.assigns.terms, f, v))}
  end

  def handle_event("save_draft", _params, socket) do
    save(socket)
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # ── Save ──

  defp save(%{assigns: %{product: nil}} = socket) do
    {:noreply, assign(socket, errors: %{base: "Pick a product first."})}
  end

  defp save(socket) do
    with {:ok, priced} <- parse_rows(socket),
         {:ok, fees} <- parse_fees(socket),
         {:ok, offer} <- upsert_offer(socket, priced, fees) do
      {:noreply,
       socket
       |> put_flash(:info, "Draft saved.")
       |> push_navigate(to: ~p"/admin/supply/offers/#{offer.id}/edit")}
    else
      {:error, %{} = errors} ->
        {:noreply, assign(socket, errors: errors)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, save_error_message(reason))}
    end
  end

  defp save_error_message(:invalid_fixed_commission_terms),
    do: "Wholesale + commission must equal the customer price exactly."

  defp save_error_message(%Ash.Error.Invalid{} = error) do
    if duplicate_offer_error?(error) do
      "You already have an offer for this product — edit it from My Offers instead."
    else
      "The offer could not be saved right now."
    end
  end

  defp save_error_message(_), do: "The offer could not be saved right now."

  # The unique_product_offer identity on SupplierOffer surfaces as an
  # InvalidChanges/unique-constraint error inside Ash.Error.Invalid.
  defp duplicate_offer_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn e ->
      msg = Exception.message(e)
      String.contains?(msg, "already been taken") or String.contains?(msg, "unique")
    end)
  end

  # Rows with any input are parsed strictly; fully blank rows are skipped.
  defp parse_rows(socket) do
    model = socket.assigns.model

    {priced, errors} =
      Enum.reduce(socket.assigns.rows, {[], %{}}, fn {vid, row}, {acc, errs} ->
        if blank_row?(row) do
          {acc, errs}
        else
          case parse_row(model, vid, row) do
            {:ok, attrs} -> {[{vid, row[:terms_id], attrs} | acc], errs}
            {:error, field} -> {acc, Map.put(errs, {vid, field}, "must be a valid amount")}
          end
        end
      end)

    if errors == %{}, do: {:ok, priced}, else: {:error, errors}
  end

  defp blank_row?(row),
    do: Enum.all?(@price_fields, fn f -> String.trim(row[f] || "") == "" end)

  defp parse_row(model, _vid, row) do
    with {:ok, supplier} <- required_price(row["supplier"], "supplier"),
         {:ok, main} <- required_price(row["suggested"], "suggested"),
         {:ok, max} <- optional_price(row["max"], "max"),
         {:ok, commission} <- commission_for(model, row) do
      attrs =
        %{supplier_price: supplier, suggested_retail_price: main}
        |> maybe_put(:max_retail_price, max)
        |> maybe_put(:fixed_commission_amount, commission)

      {:ok, attrs}
    end
  end

  defp commission_for("markup", _row), do: {:ok, nil}
  defp commission_for("fixed_commission", row), do: required_price(row["commission"], "commission")

  defp required_price(value, field) do
    case Money.parse_price(value || "") do
      {:ok, pesewas} -> {:ok, pesewas}
      _ -> {:error, field}
    end
  end

  defp optional_price(value, field) do
    case Money.parse_price(value || "") do
      {:ok, pesewas} -> {:ok, pesewas}
      :skip -> {:ok, nil}
      _ -> {:error, field}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_fees(socket) do
    {fees, errors} =
      Enum.reduce(socket.assigns.fees, {%{}, %{}}, fn {region, value}, {acc, errs} ->
        case Money.parse_price(value || "") do
          {:ok, pesewas} -> {Map.put(acc, region, pesewas), errs}
          :skip -> {acc, errs}
          _ -> {acc, Map.put(errs, {:fee, region}, "must be a valid amount")}
        end
      end)

    if errors == %{}, do: {:ok, fees}, else: {:error, errors}
  end

  defp upsert_offer(socket, priced, fees) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store
    terms = socket.assigns.terms

    term_attrs = %{
      delivery_areas: MapSet.to_list(socket.assigns.areas),
      dispatch_fees: fees,
      return_terms: presence(terms["return_terms"]),
      returns_window_days: parse_int(terms["returns_window_days"]),
      warranty_months: parse_int(terms["warranty_months"]),
      warranty_terms: presence(terms["warranty_terms"])
    }

    with {:ok, offer} <- ensure_offer(socket, actor, store, term_attrs),
         :ok <- save_rows(actor, offer, priced),
         {:ok, offer} <- Offers.update_terms(actor, offer, term_attrs) do
      {:ok, offer}
    end
  end

  defp ensure_offer(%{assigns: %{offer: %{} = offer}}, _actor, _store, _terms), do: {:ok, offer}

  defp ensure_offer(socket, actor, store, term_attrs) do
    Offers.create_draft(
      actor,
      Map.merge(term_attrs, %{
        wholesaler_store_id: store.id,
        source_product_id: socket.assigns.product.id,
        earning_model: String.to_existing_atom(socket.assigns.model)
      })
    )
  end

  defp save_rows(actor, offer, priced) do
    Enum.reduce_while(priced, :ok, fn {vid, terms_id, attrs}, :ok ->
      result =
        if terms_id do
          variant = Enum.find(offer.offer_variants, &(&1.id == terms_id))
          Offers.update_variant(actor, offer, variant, attrs)
        else
          Offers.add_variant(actor, offer, Map.put(attrs, :source_variant_id, vid))
        end

      case result do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp presence(nil), do: nil
  defp presence(value), do: if(String.trim(value) == "", do: nil, else: value)

  defp parse_int(nil), do: nil

  defp parse_int(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp load_products(socket) do
    case socket.assigns[:current_store] do
      %{id: store_id} ->
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_admin, %{store_id: store_id, search: nil, status: :active})
        |> Ash.Query.load(:variants)
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.variants != []))

      _ ->
        []
    end
  end

  defp source_variants(%{assigns: %{offer: %{} = offer}}),
    do: Enum.map(offer.offer_variants, & &1.source_variant)

  defp source_variants(%{assigns: %{product: %{} = product}}), do: product.variants
  defp source_variants(_socket), do: []

  defp row_value(rows, vid, field), do: get_in(rows, [vid, field]) || ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 pb-16">
      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading…</div>

      <div :if={!@loading} class="space-y-6">
        <div class="pt-2">
          <.link navigate={~p"/admin/supply/offers"} class="text-sm text-slate-500 hover:text-slate-700">
            ← My Offers
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 mt-2">
            {if @action == :new, do: "New offer", else: "Edit offer"}
          </h1>
          <p :if={@errors[:base]} class="text-sm text-red-600 mt-1">{@errors[:base]}</p>
        </div>

        <%!-- Product picker (new only) --%>
        <div :if={@action == :new} class="rounded-2xl border border-slate-200 p-4">
          <label class="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Product
          </label>
          <form phx-change="select_product">
            <select
              name="product_id"
              class="mt-2 w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
            >
              <option value="">Pick a product to offer…</option>
              <option :for={p <- @products} value={p.id} selected={@product && @product.id == p.id}>
                {p.title}
              </option>
            </select>
          </form>
          <p :if={@products == []} class="text-xs text-slate-500 mt-2">
            You need an active product with at least one variant before creating an offer.
          </p>
        </div>

        <div :if={@product} class="space-y-6">
          <%!-- Earning model --%>
          <div class="rounded-2xl border border-slate-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-2">
              Earning model
            </p>
            <div class="flex gap-4">
              <button
                :for={{value, label} <- [{"markup", "Markup"}, {"fixed_commission", "Fixed commission"}]}
                phx-click="select_model"
                phx-value-model={value}
                disabled={@offer != nil}
                class={[
                  "rounded-xl border px-4 py-2 text-sm font-medium",
                  if(@model == value,
                    do: "border-emerald-600 bg-emerald-50 text-emerald-800",
                    else: "border-slate-300 text-slate-600"
                  ),
                  @offer != nil && "opacity-60"
                ]}
              >
                {label}
              </button>
            </div>
            <p class="text-xs text-slate-500 mt-2">
              <%= if @model == "markup" do %>
                Resellers keep the difference between their retail price and your wholesale price.
              <% else %>
                Wholesale + commission must equal the customer price exactly.
              <% end %>
            </p>
          </div>

          <%!-- Variant pricing --%>
          <div class="rounded-2xl border border-slate-200 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-xs uppercase tracking-wide text-slate-500 bg-slate-50">
                  <th class="px-4 py-2.5">Variant</th>
                  <th class="px-4 py-2.5">Wholesale (GH₵)</th>
                  <%= if @model == "markup" do %>
                    <th class="px-4 py-2.5">Suggested retail</th>
                    <th class="px-4 py-2.5">Max retail (optional)</th>
                  <% else %>
                    <th class="px-4 py-2.5">Customer price</th>
                    <th class="px-4 py-2.5">Commission</th>
                  <% end %>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr :for={variant <- source_variants(assigns)}>
                  <td class="px-4 py-3 text-slate-700">{variant.sku || "Default"}</td>
                  <td class="px-4 py-3">
                    <.price_input
                      variant_id={variant.id}
                      field="supplier"
                      value={row_value(@rows, variant.id, "supplier")}
                      error={@errors[{variant.id, "supplier"}]}
                      disabled={@locked?}
                    />
                  </td>
                  <%= if @model == "markup" do %>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="suggested"
                        value={row_value(@rows, variant.id, "suggested")}
                        error={@errors[{variant.id, "suggested"}]}
                        disabled={@locked?}
                      />
                    </td>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="max"
                        value={row_value(@rows, variant.id, "max")}
                        error={@errors[{variant.id, "max"}]}
                        disabled={@locked?}
                      />
                    </td>
                  <% else %>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="suggested"
                        value={row_value(@rows, variant.id, "suggested")}
                        error={@errors[{variant.id, "suggested"}]}
                        disabled={@locked?}
                      />
                    </td>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="commission"
                        value={row_value(@rows, variant.id, "commission")}
                        error={@errors[{variant.id, "commission"}]}
                        disabled={@locked?}
                      />
                    </td>
                  <% end %>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Delivery areas + dispatch fees --%>
          <div class="rounded-2xl border border-slate-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-3">
              Delivery areas &amp; dispatch fees
            </p>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <div :for={region <- Emakola.Suppliers.GhanaRegions.all()} class="flex items-center gap-3">
                <button
                  phx-click="toggle_region"
                  phx-value-region={region}
                  class={[
                    "flex-1 text-left rounded-xl border px-3 py-2 text-sm",
                    if(MapSet.member?(@areas, region),
                      do: "border-emerald-600 bg-emerald-50 text-emerald-800",
                      else: "border-slate-200 text-slate-600"
                    )
                  ]}
                >
                  {region}
                </button>
                <form
                  :if={MapSet.member?(@areas, region)}
                  phx-change="set_region_fee"
                  class="w-28"
                >
                  <input type="hidden" name="region" value={region} />
                  <input
                    type="text"
                    name="value"
                    value={@fees[region] || ""}
                    placeholder="Fee GH₵"
                    phx-debounce="300"
                    class="w-full rounded-xl border border-slate-300 px-2 py-1.5 text-sm"
                  />
                </form>
                <p :if={@errors[{:fee, region}]} class="text-xs text-red-600">
                  {@errors[{:fee, region}]}
                </p>
              </div>
            </div>
          </div>

          <%!-- Terms --%>
          <div class="rounded-2xl border border-slate-200 p-4 space-y-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
              Supplier terms
            </p>
            <form phx-change="set_term">
              <input type="hidden" name="field" value="return_terms" />
              <textarea
                name="value"
                rows="2"
                placeholder="Return terms you honour back to resellers…"
                phx-debounce="300"
                class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
              >{@terms["return_terms"]}</textarea>
            </form>
            <div class="grid grid-cols-2 gap-3">
              <form phx-change="set_term">
                <input type="hidden" name="field" value="returns_window_days" />
                <input
                  type="text"
                  name="value"
                  value={@terms["returns_window_days"]}
                  placeholder="Returns window (days)"
                  phx-debounce="300"
                  class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
              </form>
              <form phx-change="set_term">
                <input type="hidden" name="field" value="warranty_months" />
                <input
                  type="text"
                  name="value"
                  value={@terms["warranty_months"]}
                  placeholder="Warranty (months)"
                  phx-debounce="300"
                  class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
              </form>
            </div>
            <form phx-change="set_term">
              <input type="hidden" name="field" value="warranty_terms" />
              <textarea
                name="value"
                rows="2"
                placeholder="Warranty terms…"
                phx-debounce="300"
                class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
              >{@terms["warranty_terms"]}</textarea>
            </form>
          </div>

          <%!-- Actions --%>
          <div class="flex items-center gap-3">
            <button
              phx-click="save_draft"
              class="rounded-xl bg-slate-800 hover:bg-slate-900 text-white text-sm font-semibold px-5 py-2.5"
            >
              Save draft
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :variant_id, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, required: true
  attr :error, :string, default: nil
  attr :disabled, :boolean, default: false

  defp price_input(assigns) do
    ~H"""
    <form phx-change="set_variant_price">
      <input type="hidden" name="variant-id" value={@variant_id} />
      <input type="hidden" name="field" value={@field} />
      <input
        type="text"
        name="value"
        value={@value}
        disabled={@disabled}
        placeholder="0.00"
        phx-debounce="300"
        class={[
          "w-28 rounded-xl border px-2 py-1.5 text-sm",
          if(@error, do: "border-red-400", else: "border-slate-300"),
          @disabled && "bg-slate-50 text-slate-400"
        ]}
      />
      <p :if={@error} class="text-xs text-red-600 mt-1">{@error}</p>
    </form>
    """
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: PASS. (If the `save_draft` flow fails because `update_terms` requires an editable status or `create_draft` already set terms, read the failure — `create_draft` accepts the term attrs directly, and `update_terms` on a fresh draft is valid; adjust only if the domain rejects something, and say so in your report.)

- [ ] **Step 5: Commit**

```bash
mix format
mix compile --warnings-as-errors
git add -A && git commit -m "feat(web): supplier offer form — draft creation with pricing, regions, fees"
```

---

### Task 4: Publish flow, fixed-commission path, restricted edit

**Files:**
- Modify: `lib/emakola_web/live/admin/supply_offers_live/form.ex`
- Test: `test/emakola_web/live/admin/supply_offers_live_test.exs` (append describe)

**Interfaces:**
- Consumes: Task 3's Form internals (`save/1` returns via `push_navigate`; `@locked?`; `save_error_message/1`); `Offers.publish/2` and its error atoms; `Offers.update_terms/3`.
- Produces: `publish` event (save-then-publish), restricted edit behavior for published offers (pricing inputs disabled, save only updates terms), fixed-commission form path proven end-to-end.

- [ ] **Step 1: Write the failing tests** — append:

```elixir
  describe "offer form (publish + models + restricted edit)" do
    setup %{conn: conn} do
      {merchant, store} = Factory.create_merchant_with_store!(%{name: "Publish Supply"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      product = Factory.create_product!(store, status: :active, title: "Kente Sash")
      variant = Factory.create_variant!(product, store, price: 8_000, stock_quantity: 5)

      %{conn: conn, merchant: merchant, store: store, product: product, variant: variant}
    end

    test "publish from the form makes the offer live", %{
      conn: conn,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "50"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "80"
      })

      render_click(view, "toggle_region", %{"region" => "Ashanti"})

      view |> element("button[phx-click=publish]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(wholesaler_store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert offer.status == :published
    end

    test "fixed commission must reconcile exactly", %{
      conn: conn,
      product: product,
      variant: variant
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})
      render_click(view, "select_model", %{"model" => "fixed_commission"})

      for {field, value} <- [{"supplier", "50"}, {"suggested", "80"}, {"commission", "20"}] do
        render_change(view, "set_variant_price", %{
          "variant-id" => variant.id,
          "field" => field,
          "value" => value
        })
      end

      html = view |> element("button[phx-click=save_draft]") |> render_click()
      assert html =~ "must equal the customer price exactly"

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "commission",
        "value" => "30"
      })

      view |> element("button[phx-click=save_draft]") |> render_click()

      require Ash.Query

      [offer] =
        Emakola.Suppliers.SupplierOffer
        |> Ash.Query.filter(source_product_id == ^product.id)
        |> Ash.Query.load(:offer_variants)
        |> Ash.read!(authorize?: false)

      assert [%{fixed_commission_amount: 3_000}] = offer.offer_variants
    end

    test "published offers open in restricted edit", %{
      conn: conn,
      merchant: merchant,
      store: store,
      product: product,
      variant: variant
    } do
      {:ok, offer} =
        Offers.create_draft(merchant, %{
          wholesaler_store_id: store.id,
          source_product_id: product.id,
          earning_model: :markup,
          delivery_areas: ["Greater Accra"]
        })

      {:ok, _} =
        Offers.add_variant(merchant, offer, %{
          source_variant_id: variant.id,
          supplier_price: 5_000,
          suggested_retail_price: 8_000
        })

      {:ok, _} = Offers.publish(merchant, offer)

      {:ok, view, html} = live(conn, ~p"/admin/supply/offers/#{offer.id}/edit")

      assert html =~ "Pricing is locked while the offer is live"
      assert has_element?(view, "input[name=value][disabled]")

      render_change(view, "set_term", %{"field" => "return_terms", "value" => "14-day returns"})
      view |> element("button[phx-click=save_draft]") |> render_click()

      reloaded = Ash.get!(Emakola.Suppliers.SupplierOffer, offer.id, authorize?: false)
      assert reloaded.return_terms == "14-day returns"
      # pricing untouched
      [terms] = reloaded |> Ash.load!(:offer_variants, authorize?: false) |> Map.get(:offer_variants)
      assert terms.supplier_price == 5_000
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: FAIL — no `button[phx-click=publish]`; restricted-edit copy missing.

- [ ] **Step 3: Implement** — in `form.ex`:

(a) Add the publish handler after `save_draft`:

```elixir
  def handle_event("publish", _params, socket) do
    case do_save(socket) do
      {:ok, offer} ->
        case Offers.publish(socket.assigns.current_merchant, offer) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Offer published — it is now live in the catalog.")
             |> push_navigate(to: ~p"/admin/supply/offers")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, publish_error_message(reason))
             |> push_navigate(to: ~p"/admin/supply/offers/#{offer.id}/edit")}
        end

      {:error_socket, socket} ->
        {:noreply, socket}
    end
  end
```

(b) Refactor `save/1` so both buttons share one path — replace `save/1` with:

```elixir
  defp save(socket) do
    case do_save(socket) do
      {:ok, offer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft saved.")
         |> push_navigate(to: ~p"/admin/supply/offers/#{offer.id}/edit")}

      {:error_socket, socket} ->
        {:noreply, socket}
    end
  end

  defp do_save(%{assigns: %{product: nil}} = socket),
    do: {:error_socket, assign(socket, errors: %{base: "Pick a product first."})}

  # Published offers: terms-only save — pricing rows are locked in the UI and
  # deliberately not written here either.
  defp do_save(%{assigns: %{locked?: true, offer: offer}} = socket) do
    case parse_fees(socket) do
      {:ok, fees} ->
        case Offers.update_terms(socket.assigns.current_merchant, offer, term_attrs(socket, fees)) do
          {:ok, offer} -> {:ok, offer}
          {:error, _} -> {:error_socket, put_flash(socket, :error, "Terms could not be saved.")}
        end

      {:error, errors} ->
        {:error_socket, assign(socket, errors: errors)}
    end
  end

  defp do_save(socket) do
    with {:ok, priced} <- parse_rows(socket),
         {:ok, fees} <- parse_fees(socket),
         {:ok, offer} <- upsert_offer(socket, priced, fees) do
      {:ok, offer}
    else
      {:error, %{} = errors} -> {:error_socket, assign(socket, errors: errors)}
      {:error, reason} -> {:error_socket, put_flash(socket, :error, save_error_message(reason))}
    end
  end
```

Extract the term-attrs map construction out of `upsert_offer/3` into a shared private used by both `upsert_offer/3` and the locked branch:

```elixir
  defp term_attrs(socket, fees) do
    terms = socket.assigns.terms

    %{
      delivery_areas: MapSet.to_list(socket.assigns.areas),
      dispatch_fees: fees,
      return_terms: presence(terms["return_terms"]),
      returns_window_days: parse_int(terms["returns_window_days"]),
      warranty_months: parse_int(terms["warranty_months"]),
      warranty_terms: presence(terms["warranty_terms"])
    }
  end
```

`upsert_offer/3` becomes: `term_attrs = term_attrs(socket, fees)` followed by the existing `with` (its local map construction deleted).

(c) Publish error copy:

```elixir
  defp publish_error_message(:source_product_not_sellable),
    do: "The source product must be active before publishing."

  defp publish_error_message(:offer_requires_variants),
    do: "Add at least one priced variant before publishing."

  defp publish_error_message(:offer_requires_available_variant),
    do: "The source product has no available stock to offer."

  defp publish_error_message(:invalid_offer_economics),
    do: "Fix the pricing first — every priced variant needs valid economics."

  defp publish_error_message(_), do: "The offer could not be published right now."
```

(d) Template: in the Actions block add, after the Save-draft button:

```heex
            <button
              :if={!@locked?}
              phx-click="publish"
              class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-5 py-2.5"
            >
              {if @offer && @offer.status == :paused, do: "Republish", else: "Publish"}
            </button>
            <p :if={@locked?} class="text-xs text-slate-500">
              Pricing is locked while the offer is live — pause it from
              <.link navigate={~p"/admin/supply/offers"} class="text-emerald-700">My Offers</.link>
              to edit prices. Terms, areas, and fees save normally.
            </p>
```

Also change the Save-draft button's label when `@locked?` to "Save terms".

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format
mix compile --warnings-as-errors
git add -A && git commit -m "feat(web): offer form publishes, prices fixed-commission, locks live pricing"
```

---

### Task 5: End-to-end loop + full gates

**Files:**
- Test: `test/emakola_web/live/admin/supply_offers_live_test.exs` (append)

**Interfaces:**
- Consumes: everything above; `Offers.list_discoverable/2` from the catalog feature.
- Produces: the supplier→catalog loop proven end-to-end; branch gate-clean and committed. Push/PR happen AFTER the final whole-branch review (controller sequencing).

- [ ] **Step 1: Write the failing test** — append:

```elixir
  describe "supplier -> catalog loop" do
    test "an offer published through the form is discoverable by another store", %{conn: conn} do
      {supplier, supplier_store} = Factory.create_merchant_with_store!(%{name: "Loop Supply"})
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(supplier))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      product = Factory.create_product!(supplier_store, status: :active, title: "Loop Soap")
      variant = Factory.create_variant!(product, supplier_store, price: 2_000, stock_quantity: 9)

      {:ok, view, _html} = live(conn, ~p"/admin/supply/offers/new")

      render_change(view, "select_product", %{"product_id" => product.id})

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "supplier",
        "value" => "12"
      })

      render_change(view, "set_variant_price", %{
        "variant-id" => variant.id,
        "field" => "suggested",
        "value" => "20"
      })

      render_click(view, "toggle_region", %{"region" => "Volta"})
      render_change(view, "set_region_fee", %{"region" => "Volta", "value" => "8"})

      view |> element("button[phx-click=publish]") |> render_click()

      {reseller, reseller_store} = Factory.create_merchant_with_store!(%{name: "Loop Reseller"})

      assert {:ok, [entry]} = Emakola.Suppliers.Offers.list_discoverable(reseller, reseller_store.id)
      assert entry.offer.source_product.title == "Loop Soap"
      assert entry.offer.dispatch_fees == %{"Volta" => 800}
      assert entry.connected? == false
    end
  end
```

- [ ] **Step 2: Run to verify failure** — this test should PASS if Tasks 3–4 are correct; run it and confirm. If it fails, the failure is a real integration bug: diagnose and fix before proceeding (report what it was).

Run: `mix test test/emakola_web/live/admin/supply_offers_live_test.exs`

- [ ] **Step 3: Full gates**

```bash
mix format --check-formatted
mix credo --strict lib/emakola/suppliers/offers.ex lib/emakola/suppliers/ghana_regions.ex lib/emakola_web/live/admin/supply_offers_live/index.ex lib/emakola_web/live/admin/supply_offers_live/form.ex
mix test 2>&1 | tail -3   # parse the "Result:" line — exit code lies
```

Expected: 0 failures on the Result line.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "test(catalog): supplier form to reseller catalog loop proven end-to-end"
```

Do NOT push or open a PR — the controller runs the whole-branch review first.
