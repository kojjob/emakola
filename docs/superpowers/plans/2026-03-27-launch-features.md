# Launch Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 7 launch features: storefront search, return/refund flow, wishlist, order tracking SMS, coupon display, inventory management, and PDF export.

**Architecture:** Each feature is independent and can be built in parallel. Features follow existing Ash resource + Phoenix LiveView patterns. All new resources are multi-tenant via `store_id`. Money in minor units (pesewas). TailwindCSS for styling with cream/amber/stone design system.

**Tech Stack:** Elixir/Phoenix 1.8, Ash 3.x, PostgreSQL, Oban, TailwindCSS, Chart.js (existing), ChromicPDF (new dep for PDF export)

**Parallelization:** Tasks 1-7 are independent and can be dispatched to separate agents simultaneously. Each task produces a working, testable feature with its own commit(s).

---

## Task 1: Storefront Search Overlay

**Files:**
- Create: `lib/emakola_web/components/search_components.ex`
- Create: `test/emakola_web/live/storefront/search_test.exs`
- Modify: `lib/emakola_web/components/storefront_components.ex` (nav search trigger)
- Modify: `lib/emakola_web/live/storefront/product_list_live.ex` (URL param support)

### Context for Agent

The search backend already exists:
- `Emakola.Catalog.search_products!(query, store_id)` — searches products by title (case-insensitive `contains`)
- `Emakola.Catalog.CachedCatalog.search_products(store_id, query)` — cached wrapper
- `ProductListLive` already has `handle_event("search", ...)` that filters products

The storefront nav is in `lib/emakola_web/components/storefront_components.ex` — the `store_nav/1` component. The search icon currently links to `/s/:store_slug/products`. We need to change it to open a search overlay instead.

Design system: background `#FAFAF9` (cream-50), accent `#B45309` (amber-700), dark surfaces `#1C1917` (stone-900), rounded-[20px] cards, Inter font.

### Steps

- [ ] **Step 1: Write search overlay component test**

Create `test/emakola_web/live/storefront/search_test.exs`:

```elixir
defmodule EmakolaWeb.Storefront.SearchTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    # Create store with products using existing seed patterns
    store = create_test_store()
    product1 = create_test_product(store, "Kente Cloth Royal", :active)
    product2 = create_test_product(store, "Shea Butter Cream", :active)
    _draft = create_test_product(store, "Draft Product", :draft)

    %{store: store, product1: product1, product2: product2}
  end

  describe "search overlay" do
    test "search finds matching products", %{conn: conn, store: store, product1: product1} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      # Type in search
      html = view
        |> element("#search-input")
        |> render_change(%{"query" => "Kente"})

      assert html =~ product1.title
      refute html =~ "Shea Butter"
    end

    test "search shows no results message for unmatched query", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      html = view
        |> element("#search-input")
        |> render_change(%{"query" => "nonexistent-xyz"})

      assert html =~ "No products found"
    end

    test "URL param ?q= pre-fills search", %{conn: conn, store: store, product1: product1} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products?q=Kente")

      assert html =~ product1.title
      assert html =~ "Kente"
    end
  end
end
```

Note: the test helper functions (`create_test_store/0`, `create_test_product/3`) should follow existing patterns in `test/support/`. Check existing test files for the factory/helper patterns used in this project. If `ExMachina` factories exist, use those. If tests use direct `Ash.create!` calls with a helper module, follow that pattern.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/storefront/search_test.exs`
Expected: FAIL — test helpers may not exist yet, or search input element not found

- [ ] **Step 3: Add URL param support to ProductListLive**

Modify `lib/emakola_web/live/storefront/product_list_live.ex`:

In `handle_params/3`, extract the `q` query param and apply it:

```elixir
@impl true
def handle_params(params, _uri, socket) do
  query = Map.get(params, "q", "")

  if query != "" and query != socket.assigns.search_query do
    products = search_or_list(socket.assigns.store.id, query, socket.assigns.selected_category)
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:products, products)
     |> assign(:page, 1)
     |> assign(:has_more, length(products) >= @products_per_page)}
  else
    {:noreply, socket}
  end
end
```

Add a `search_or_list/3` private function that calls `CachedCatalog.search_products/2` when query is present, otherwise loads all products.

- [ ] **Step 4: Create search overlay component**

Create `lib/emakola_web/components/search_components.ex`:

```elixir
defmodule EmakolaWeb.SearchComponents do
  use Phoenix.Component
  alias EmakolaWeb.Helpers.Currency

  attr :store, :map, required: true
  attr :results, :list, default: []
  attr :query, :string, default: ""
  attr :searching, :boolean, default: false

  def search_overlay(assigns) do
    ~H"""
    <div
      id="search-overlay"
      class="fixed inset-0 z-[60] bg-black/40 backdrop-blur-sm"
      phx-click="close_search"
      style="display: none;"
    >
      <div
        class="mx-auto max-w-2xl mt-4 sm:mt-20 bg-white rounded-2xl shadow-2xl overflow-hidden"
        phx-click-away="close_search"
        onclick="event.stopPropagation()"
      >
        <!-- Search input -->
        <div class="flex items-center gap-3 px-5 py-4 border-b border-gray-100">
          <svg class="w-5 h-5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input
            id="search-input"
            type="text"
            name="query"
            value={@query}
            placeholder="Search products..."
            class="flex-1 text-base text-gray-900 placeholder-gray-400 bg-transparent border-none outline-none focus:ring-0"
            phx-change="search"
            phx-debounce="300"
            autofocus
          />
          <kbd class="hidden sm:inline-flex items-center px-2 py-0.5 text-xs text-gray-400 bg-gray-100 rounded-md">ESC</kbd>
        </div>

        <!-- Results -->
        <div class="max-h-[60vh] overflow-y-auto">
          <%= cond do %>
            <% @searching -> %>
              <!-- Skeleton loading -->
              <div class="p-4 space-y-3">
                <%= for _i <- 1..3 do %>
                  <div class="flex items-center gap-3 animate-pulse">
                    <div class="w-12 h-12 bg-gray-200 rounded-xl"></div>
                    <div class="flex-1 space-y-2">
                      <div class="h-4 bg-gray-200 rounded w-3/4"></div>
                      <div class="h-3 bg-gray-200 rounded w-1/4"></div>
                    </div>
                  </div>
                <% end %>
              </div>

            <% @query != "" and @results == [] -> %>
              <!-- No results -->
              <div class="py-12 px-4 text-center">
                <svg class="w-16 h-16 mx-auto text-gray-200 mb-4" fill="none" stroke="currentColor" stroke-width="1" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
                </svg>
                <p class="text-gray-500 text-sm">No products found for "<span class="font-medium text-gray-700"><%= @query %></span>"</p>
                <p class="text-gray-400 text-xs mt-1">Try a different search term</p>
              </div>

            <% @query != "" -> %>
              <!-- Results list -->
              <div class="p-2">
                <%= for product <- Enum.take(@results, 6) do %>
                  <a
                    href={"/s/#{@store.slug}/products/#{product.slug}"}
                    class="flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-50 transition-colors group"
                  >
                    <div class="w-12 h-12 rounded-xl bg-gray-100 overflow-hidden flex-shrink-0">
                      <%= if first_image(product) do %>
                        <img src={first_image(product)} alt={product.title} class="w-full h-full object-cover" />
                      <% else %>
                        <div class="w-full h-full flex items-center justify-center text-gray-300">
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z" />
                          </svg>
                        </div>
                      <% end %>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900 truncate group-hover:text-amber-700 transition-colors"><%= product.title %></p>
                      <p class="text-xs text-amber-700 font-semibold"><%= Currency.format(product.min_price, "GHS") %></p>
                    </div>
                  </a>
                <% end %>

                <%= if length(@results) > 6 do %>
                  <a
                    href={"/s/#{@store.slug}/products?q=#{URI.encode(@query)}"}
                    class="block text-center py-3 text-sm font-medium text-amber-700 hover:text-amber-800 border-t border-gray-100 mt-2"
                  >
                    View all <%= length(@results) %> results
                  </a>
                <% end %>
              </div>

            <% true -> %>
              <!-- Empty state -->
              <div class="py-10 px-4 text-center">
                <p class="text-gray-400 text-sm">Start typing to search products</p>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp first_image(product) do
    case product.images do
      [img | _] -> img.url
      _ -> nil
    end
  end
end
```

- [ ] **Step 5: Wire search overlay into storefront nav**

Modify `lib/emakola_web/components/storefront_components.ex`:

Replace the search icon `<a>` tag in `store_nav/1` with a button that toggles the overlay via `Phoenix.LiveView.JS`:

```elixir
<button
  phx-click={Phoenix.LiveView.JS.show(to: "#search-overlay", transition: {"ease-out duration-200", "opacity-0", "opacity-100"}) |> Phoenix.LiveView.JS.focus(to: "#search-input")}
  class="p-2.5 rounded-xl hover:bg-[#F1F5F9] transition-colors"
  aria-label="Search products"
>
  <!-- existing search SVG icon -->
</button>
```

Add search event handlers to the storefront LiveViews that use the nav (or add to a shared hook). The `search` and `close_search` events need to be handled in whatever LiveView renders the overlay.

The simplest approach: add search handling to a shared on_mount hook, or handle in each LiveView. Since the overlay appears on every page, add the search assigns and handlers to the `ResolveStore` hook or create a `SearchHandler` hook.

- [ ] **Step 6: Add search event handling**

Each storefront LiveView that renders `store_nav` needs to handle `search` and `close_search` events. The cleanest approach is adding these assigns in mount and handling events:

```elixir
# In each storefront LiveView mount, add:
|> assign(:search_results, [])
|> assign(:search_query, "")
|> assign(:searching, false)

# Event handlers to add:
def handle_event("search", %{"query" => query}, socket) when byte_size(query) >= 2 do
  store_id = socket.assigns.store.id
  results = Emakola.Catalog.CachedCatalog.search_products(store_id, query)
  results = Ash.load!(results, [:min_price, :images])
  {:noreply, assign(socket, search_results: results, search_query: query, searching: false)}
end

def handle_event("search", %{"query" => _query}, socket) do
  {:noreply, assign(socket, search_results: [], search_query: "", searching: false)}
end

def handle_event("close_search", _, socket) do
  {:noreply, assign(socket, search_results: [], search_query: "", searching: false)}
end
```

To avoid repeating this in every LiveView, create a helper module `EmakolaWeb.Storefront.SearchHandlers` with `defmacro __using__(_)` that injects these handlers via `defoverridable`, or simply add a `use EmakolaWeb.Storefront.SearchHandlers` that provides the common code. The simplest approach: put the handlers in the LiveViews that already exist. Start with `StoreLive` and `ProductListLive` as the most important pages.

- [ ] **Step 7: Render search overlay in storefront layout**

Add the search overlay component to the storefront layout or to each LiveView's render. The overlay is hidden by default and shown via JS. Add to the render of storefront LiveViews:

```elixir
<EmakolaWeb.SearchComponents.search_overlay
  store={@store}
  results={@search_results}
  query={@search_query}
  searching={@searching}
/>
```

- [ ] **Step 8: Run tests and verify**

Run: `mix test test/emakola_web/live/storefront/search_test.exs`
Expected: All tests pass

- [ ] **Step 9: Commit**

```bash
git add lib/emakola_web/components/search_components.ex lib/emakola_web/components/storefront_components.ex lib/emakola_web/live/storefront/product_list_live.ex test/emakola_web/live/storefront/search_test.exs
git commit -m "feat(web): add storefront search overlay with live autocomplete"
```

---

## Task 2: Return/Refund Flow

**Files:**
- Create: `lib/emakola/orders/resources/return.ex`
- Create: `lib/emakola_web/live/admin/return_live.ex`
- Create: `lib/emakola_web/components/return_components.ex`
- Create: `test/emakola/orders/return_test.exs`
- Create: `test/emakola_web/live/admin/return_live_test.exs`
- Modify: `lib/emakola/orders/orders.ex` (add Return resource)
- Modify: `lib/emakola_web/live/storefront/account_live.ex` (add return request UI)
- Modify: `lib/emakola_web/router.ex` (add admin route)
- Migration: `priv/repo/migrations/*_create_returns.exs`

### Context for Agent

The Orders domain is at `lib/emakola/orders/orders.ex`. It currently has Order, LineItem, and Coupon resources. Orders have status: `pending`, `confirmed`, `processing`, `shipped`, `delivered`, `cancelled`.

Order resource is at `lib/emakola/orders/resources/order.ex`. It has `store_id`, `customer_id`, `order_number`, `status`, `total`, `currency`, etc.

The account page at `lib/emakola_web/live/storefront/account_live.ex` shows customer orders. The "Orders" tab lists orders with status badges. We need to add a "Request Return" button on delivered orders.

Admin sidebar is at `lib/emakola_web/components/sidebar_components.ex` — it uses icon name strings mapped to SVG paths. The admin layout renders the sidebar links — check `lib/emakola_web/components/layouts/app.html.heex` for how sidebar links are rendered.

Policies pattern: reads bypass with `authorize_if(always())`, system calls bypass with `authorize_unless(actor_present())`, merchant writes use `ActorHasStoreAccess` check.

### Steps

- [ ] **Step 1: Write Return resource test**

Create `test/emakola/orders/return_test.exs`:

```elixir
defmodule Emakola.Orders.ReturnTest do
  use Emakola.DataCase, async: true

  describe "request_return" do
    test "creates a return request for a delivered order" do
      store = create_test_store()
      customer = create_test_customer(store)
      order = create_test_order(store, customer, :delivered)

      assert {:ok, return} =
               Emakola.Orders.request_return(%{
                 order_id: order.id,
                 customer_id: customer.id,
                 store_id: store.id,
                 reason: :wrong_item,
                 reason_detail: "Received wrong size"
               })

      assert return.status == :requested
      assert return.reason == :wrong_item
      assert return.order_id == order.id
    end

    test "rejects return for non-delivered order" do
      store = create_test_store()
      customer = create_test_customer(store)
      order = create_test_order(store, customer, :processing)

      assert {:error, _} =
               Emakola.Orders.request_return(%{
                 order_id: order.id,
                 customer_id: customer.id,
                 store_id: store.id,
                 reason: :defective
               })
    end
  end

  describe "approve/deny return" do
    test "approve sets status to approved with refund amount" do
      store = create_test_store()
      customer = create_test_customer(store)
      order = create_test_order(store, customer, :delivered)
      {:ok, return} = create_test_return(store, customer, order)

      assert {:ok, approved} =
               Emakola.Orders.approve_return(return, %{
                 admin_notes: "Approved - item was defective",
                 refund_amount: order.total
               })

      assert approved.status == :approved
      assert approved.refund_amount == order.total
    end

    test "deny sets status to denied" do
      store = create_test_store()
      customer = create_test_customer(store)
      order = create_test_order(store, customer, :delivered)
      {:ok, return} = create_test_return(store, customer, order)

      assert {:ok, denied} =
               Emakola.Orders.deny_return(return, %{
                 admin_notes: "Outside return window"
               })

      assert denied.status == :denied
    end
  end
end
```

Adapt the test helper functions to match existing patterns. Check `test/support/` and existing tests like `test/emakola/orders/order_test.exs` for how they create test data.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/orders/return_test.exs`
Expected: FAIL — Return module doesn't exist

- [ ] **Step 3: Generate migration for returns table**

Run: `mix ash.codegen create_returns`

Or manually create migration:

```elixir
defmodule Emakola.Repo.Migrations.CreateReturns do
  use Ecto.Migration

  def change do
    create table(:returns, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :order_id, references(:orders, type: :uuid, on_delete: :delete_all), null: false
      add :customer_id, references(:customers, type: :uuid, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "requested"
      add :reason, :string, null: false
      add :reason_detail, :text
      add :admin_notes, :text
      add :refund_amount, :integer
      add :currency, :string, default: "GHS"

      timestamps()
    end

    create index(:returns, [:store_id])
    create index(:returns, [:order_id])
    create index(:returns, [:customer_id])
    create unique_index(:returns, [:order_id], name: :returns_one_per_order)
  end
end
```

Run: `mix ecto.migrate`

- [ ] **Step 4: Create Return Ash resource**

Create `lib/emakola/orders/resources/return.ex`:

```elixir
defmodule Emakola.Orders.Return do
  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("returns")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :customer_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:requested, :approved, :denied, :refunded])
      default(:requested)
      allow_nil?(false)
      public?(true)
    end

    attribute :reason, :atom do
      constraints(one_of: [:defective, :wrong_item, :not_as_described, :changed_mind, :other])
      allow_nil?(false)
      public?(true)
    end

    attribute :reason_detail, :string do
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :admin_notes, :string do
      public?(true)
      constraints(max_length: 2000)
    end

    attribute :refund_amount, :integer do
      public?(true)
    end

    attribute :currency, :string do
      default("GHS")
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      attribute_writable?(true)
    end

    belongs_to :order, Emakola.Orders.Order do
      define_attribute?(false)
      attribute_writable?(true)
    end

    belongs_to :customer, Emakola.Customers.Customer do
      define_attribute?(false)
      attribute_writable?(true)
    end
  end

  identities do
    identity(:one_per_order, [:order_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    create :request_return do
      accept([:store_id, :order_id, :customer_id, :reason, :reason_detail])
    end

    update :approve do
      require_atomic?(false)
      accept([:admin_notes, :refund_amount])
      change(set_attribute(:status, :approved))
    end

    update :deny do
      require_atomic?(false)
      accept([:admin_notes])
      change(set_attribute(:status, :denied))
    end

    update :mark_refunded do
      require_atomic?(false)
      change(set_attribute(:status, :refunded))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :get_by_order do
      argument(:order_id, :uuid, allow_nil?: false)
      filter(expr(order_id == ^arg(:order_id)))
    end
  end
end
```

- [ ] **Step 5: Register Return in Orders domain**

Modify `lib/emakola/orders/orders.ex` — add inside the `resources do` block:

```elixir
resource Emakola.Orders.Return do
  define(:request_return, action: :request_return)
  define(:approve_return, action: :approve)
  define(:deny_return, action: :deny)
  define(:mark_return_refunded, action: :mark_refunded)
  define(:list_returns_by_store, action: :list_by_store, args: [:store_id])
  define(:get_return_by_order, action: :get_by_order, args: [:order_id])
end
```

- [ ] **Step 6: Run tests**

Run: `mix test test/emakola/orders/return_test.exs`
Expected: Pass (or fix any issues with test helpers)

- [ ] **Step 7: Create return components**

Create `lib/emakola_web/components/return_components.ex`:

```elixir
defmodule EmakolaWeb.ReturnComponents do
  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency

  @reason_labels %{
    defective: "Defective/Damaged",
    wrong_item: "Wrong Item Received",
    not_as_described: "Not as Described",
    changed_mind: "Changed My Mind",
    other: "Other"
  }

  @status_styles %{
    requested: {"Requested", "bg-amber-100 text-amber-800"},
    approved: {"Approved", "bg-green-100 text-green-800"},
    denied: {"Denied", "bg-red-100 text-red-800"},
    refunded: {"Refunded", "bg-blue-100 text-blue-800"}
  }

  attr :status, :atom, required: true

  def return_status_badge(assigns) do
    {label, classes} = Map.get(@status_styles, assigns.status, {"Unknown", "bg-gray-100 text-gray-800"})
    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@classes}"}>
      <%= @label %>
    </span>
    """
  end

  attr :return, :map, required: true

  def return_timeline(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class={"w-2.5 h-2.5 rounded-full " <> timeline_dot_class(:requested, @return.status)}></div>
      <div class={"h-0.5 flex-1 " <> timeline_line_class(:requested, @return.status)}></div>
      <div class={"w-2.5 h-2.5 rounded-full " <> timeline_dot_class(:approved, @return.status)}></div>
      <div class={"h-0.5 flex-1 " <> timeline_line_class(:approved, @return.status)}></div>
      <div class={"w-2.5 h-2.5 rounded-full " <> timeline_dot_class(:refunded, @return.status)}></div>
    </div>
    """
  end

  def reason_label(reason), do: Map.get(@reason_labels, reason, "Unknown")

  defp timeline_dot_class(step, current) do
    if step_reached?(step, current), do: "bg-amber-600", else: "bg-gray-200"
  end

  defp timeline_line_class(step, current) do
    if step_reached?(step, current), do: "bg-amber-600", else: "bg-gray-200"
  end

  defp step_reached?(step, current) do
    order = [:requested, :approved, :refunded]
    step_idx = Enum.find_index(order, &(&1 == step)) || 99
    current_idx = Enum.find_index(order, &(&1 == current)) || -1
    step_idx <= current_idx
  end
end
```

- [ ] **Step 8: Create admin return management page**

Create `lib/emakola_web/live/admin/return_live.ex`:

Build a LiveView page that:
- Lists all returns for the merchant's store with status badges
- Filters by status (all/requested/approved/denied/refunded)
- Shows return detail in a side panel or modal
- Approve/deny buttons with notes textarea
- Refund amount input on approve

Follow the patterns from existing admin LiveViews like `review_live.ex` or `coupon_live.ex` for layout, table structure, and event handling patterns.

- [ ] **Step 9: Add return request UI to customer account page**

Modify `lib/emakola_web/live/storefront/account_live.ex`:

In the orders tab, for orders with `status == :delivered`:
- Add a "Request Return" button
- Wire up a modal with reason dropdown and detail textarea
- Handle `request_return` event that creates the return via `Emakola.Orders.request_return/1`
- Show existing return status if a return already exists for the order

Load returns in mount: `returns = load_returns(customer.id, store.id)`

- [ ] **Step 10: Add admin route**

Modify `lib/emakola_web/router.ex` — add in the `:app` live_session block:

```elixir
live "/admin/returns", Admin.ReturnLive
```

- [ ] **Step 11: Add returns link to admin sidebar**

Check how sidebar links are rendered in the app layout and add a "Returns" link with the appropriate icon, placed after "Orders".

- [ ] **Step 12: Run all tests**

Run: `mix test test/emakola/orders/return_test.exs test/emakola_web/live/admin/return_live_test.exs`
Expected: All pass

- [ ] **Step 13: Commit**

```bash
git add lib/emakola/orders/resources/return.ex lib/emakola/orders/orders.ex lib/emakola_web/live/admin/return_live.ex lib/emakola_web/components/return_components.ex lib/emakola_web/live/storefront/account_live.ex lib/emakola_web/router.ex priv/repo/migrations/ test/
git commit -m "feat(orders): add return/refund flow with customer request and admin management"
```

---

## Task 3: Wishlist/Favorites (Database-Backed)

**Files:**
- Create: `lib/emakola/customers/resources/wishlist_item.ex`
- Create: `test/emakola/customers/wishlist_item_test.exs`
- Create: `test/emakola_web/live/storefront/wishlist_live_test.exs`
- Modify: `lib/emakola/customers/customers.ex` (add WishlistItem)
- Modify: `lib/emakola_web/live/storefront/wishlist_live.ex` (rewrite with DB backing)
- Modify: `lib/emakola_web/components/storefront_components.ex` (heart icon component)
- Migration: `priv/repo/migrations/*_create_wishlist_items.exs`

### Context for Agent

The current `WishlistLive` at `lib/emakola_web/live/storefront/wishlist_live.ex` stores wishlist in LiveView assigns (session-scoped, not persistent). It has basic add/remove events.

The Customers domain is at `lib/emakola/customers/customers.ex`. It has Customer, CustomerToken, Address, CustomerNote.

The storefront nav already has a heart icon linking to `/s/:store_slug/wishlist`. We need to:
1. Create a persistent WishlistItem resource
2. Rewrite WishlistLive to use the database for logged-in customers (keep session fallback for guests)
3. Add heart toggle to product cards and product detail page

The `current_customer` is available in socket assigns (set by `ResolveCustomer` hook).

### Steps

- [ ] **Step 1: Write WishlistItem resource test**

Create `test/emakola/customers/wishlist_item_test.exs`:

```elixir
defmodule Emakola.Customers.WishlistItemTest do
  use Emakola.DataCase, async: true

  describe "add_to_wishlist" do
    test "adds a product to customer wishlist" do
      store = create_test_store()
      customer = create_test_customer(store)
      product = create_test_product(store, "Kente Cloth", :active)

      assert {:ok, item} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer.id,
                 product_id: product.id,
                 store_id: store.id
               })

      assert item.customer_id == customer.id
      assert item.product_id == product.id
    end

    test "prevents duplicate wishlist entries" do
      store = create_test_store()
      customer = create_test_customer(store)
      product = create_test_product(store, "Kente Cloth", :active)

      assert {:ok, _} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer.id,
                 product_id: product.id,
                 store_id: store.id
               })

      assert {:error, _} =
               Emakola.Customers.add_to_wishlist(%{
                 customer_id: customer.id,
                 product_id: product.id,
                 store_id: store.id
               })
    end
  end

  describe "remove_from_wishlist" do
    test "removes item from wishlist" do
      store = create_test_store()
      customer = create_test_customer(store)
      product = create_test_product(store, "Kente Cloth", :active)

      {:ok, item} =
        Emakola.Customers.add_to_wishlist(%{
          customer_id: customer.id,
          product_id: product.id,
          store_id: store.id
        })

      assert :ok = Emakola.Customers.remove_from_wishlist(item)

      items = Emakola.Customers.list_wishlist!(customer.id, store.id)
      assert items == []
    end
  end

  describe "list_wishlist" do
    test "lists all wishlist items for a customer" do
      store = create_test_store()
      customer = create_test_customer(store)
      p1 = create_test_product(store, "Product 1", :active)
      p2 = create_test_product(store, "Product 2", :active)

      Emakola.Customers.add_to_wishlist(%{customer_id: customer.id, product_id: p1.id, store_id: store.id})
      Emakola.Customers.add_to_wishlist(%{customer_id: customer.id, product_id: p2.id, store_id: store.id})

      items = Emakola.Customers.list_wishlist!(customer.id, store.id)
      assert length(items) == 2
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/customers/wishlist_item_test.exs`

- [ ] **Step 3: Create migration**

Create migration for `wishlist_items` table:
- `id` (uuid, primary key)
- `customer_id` (uuid, references customers, not null)
- `product_id` (uuid, references products, not null)
- `store_id` (uuid, references stores, not null)
- `timestamps()`
- Unique index on `[:customer_id, :product_id, :store_id]`

Run: `mix ecto.migrate`

- [ ] **Step 4: Create WishlistItem Ash resource**

Create `lib/emakola/customers/resources/wishlist_item.ex`:

Follow the exact same pattern as other customer resources (Address, CustomerNote). Key details:
- Domain: `Emakola.Customers`
- Table: `wishlist_items`
- Actions: `add` (create), `remove` (destroy), `list_by_customer` (read with customer_id + store_id filter)
- Identity: unique on `[:customer_id, :product_id, :store_id]`
- Same policy pattern as other resources

- [ ] **Step 5: Register in Customers domain**

Modify `lib/emakola/customers/customers.ex`:

```elixir
resource Emakola.Customers.WishlistItem do
  define(:add_to_wishlist, action: :add)
  define(:remove_from_wishlist, action: :remove)
  define(:list_wishlist, action: :list_by_customer, args: [:customer_id, :store_id])
end
```

- [ ] **Step 6: Run resource tests**

Run: `mix test test/emakola/customers/wishlist_item_test.exs`

- [ ] **Step 7: Rewrite WishlistLive with database backing**

Rewrite `lib/emakola_web/live/storefront/wishlist_live.ex`:

For logged-in customers (`@current_customer` is not nil):
- Load wishlist from DB: `Emakola.Customers.list_wishlist!(customer.id, store.id)` with product preloaded
- Add/remove persists to DB
- Show wishlist count in nav

For guests:
- Keep session-based behavior (existing pattern)
- Show "Sign in to save your wishlist" prompt

The page should render a product grid similar to product list, with:
- Product image, title, price
- "Add to Cart" button
- Remove (X) button
- Empty state with heart illustration

- [ ] **Step 8: Add heart toggle to product cards**

Modify `lib/emakola_web/components/storefront_components.ex`:

Add a `wishlist_heart/1` component:
```elixir
attr :product_id, :string, required: true
attr :wishlisted, :boolean, default: false

def wishlist_heart(assigns) do
  # Renders a heart icon button that sends "toggle_wishlist" event
  # Filled heart if wishlisted, outline if not
  # Uses Phoenix.LiveView.JS for instant visual toggle before server round-trip
end
```

Add this heart to the product card component and product detail page.

- [ ] **Step 9: Run all tests**

Run: `mix test test/emakola/customers/wishlist_item_test.exs test/emakola_web/live/storefront/wishlist_live_test.exs`

- [ ] **Step 10: Commit**

```bash
git add lib/emakola/customers/resources/wishlist_item.ex lib/emakola/customers/customers.ex lib/emakola_web/live/storefront/wishlist_live.ex lib/emakola_web/components/storefront_components.ex priv/repo/migrations/ test/
git commit -m "feat(customers): add persistent wishlist with heart toggle and DB backing"
```

---

## Task 4: Order Tracking SMS

**Files:**
- Create: `test/emakola/notifications/tracking_sms_test.exs`
- Modify: `lib/emakola/notifications/templates.ex` (add tracking URL to shipped SMS)
- Modify: `lib/emakola/notifications/workers/order_notification_worker.ex` (already handles all events — verify tracking SMS coverage)

### Context for Agent

The notification system is already fully wired. `OrderNotificationWorker` already:
- Sends SMS for: `order_placed`, `order_confirmed`, `order_shipped`, `order_delivered`, `order_cancelled`
- Sends WhatsApp for the same events
- Sends email for the same events

The SMS templates in `lib/emakola/notifications/templates.ex` already cover all order lifecycle events.

**The tracking SMS feature is essentially already implemented.** The worker already fires for all status transitions. What's missing:
1. The shipped SMS should include a tracking URL (currently says "Track your delivery status" without a URL)
2. Verify that order status transition actions actually enqueue the notification worker

Check `lib/emakola/orders/resources/order.ex` for the status transition actions (confirm, start_processing, mark_shipped, mark_delivered) to see if they enqueue `OrderNotificationWorker`. If not, that's the main work.

### Steps

- [ ] **Step 1: Write test for tracking SMS with URL**

Create `test/emakola/notifications/tracking_sms_test.exs`:

```elixir
defmodule Emakola.Notifications.TrackingSmsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Notifications.Templates

  describe "order_shipped_sms/2" do
    test "includes tracking URL when order has tracking info" do
      order = %{
        order_number: "ORD-20260327-ABC123",
        store_id: Ash.UUID.generate(),
        tracking_url: "https://track.example.com/ABC123"
      }
      store = %{name: "Kente Kingdom", slug: "kente-kingdom"}

      message = Templates.order_shipped_sms(order, store)

      assert message =~ order.order_number
      assert message =~ "track.example.com"
    end

    test "provides store tracking page URL when no external tracking URL" do
      order = %{
        order_number: "ORD-20260327-ABC123",
        store_id: Ash.UUID.generate(),
        tracking_url: nil
      }
      store = %{name: "Kente Kingdom", slug: "kente-kingdom"}

      message = Templates.order_shipped_sms(order, store)

      assert message =~ order.order_number
      assert message =~ "shipped"
    end
  end
end
```

- [ ] **Step 2: Run test to verify current behavior**

Run: `mix test test/emakola/notifications/tracking_sms_test.exs`

- [ ] **Step 3: Update shipped SMS template to include tracking URL**

Modify `lib/emakola/notifications/templates.ex`:

Update `order_shipped_sms/2`:

```elixir
def order_shipped_sms(order, store) do
  tracking_text =
    case Map.get(order, :tracking_url) do
      url when is_binary(url) and url != "" ->
        " Track here: #{url}"
      _ ->
        " Track at: #{storefront_url(store)}/track/#{order.order_number}"
    end

  "Your order #{order.order_number} from #{store.name} has been shipped!" <> tracking_text
end

defp storefront_url(store) do
  host = Application.get_env(:emakola, EmakolaWeb.Endpoint)[:url][:host] || "localhost:4000"
  "https://#{host}/s/#{store.slug}"
end
```

- [ ] **Step 4: Verify notification worker is enqueued on status transitions**

Read `lib/emakola/orders/resources/order.ex` and check the `confirm`, `start_processing`, `mark_shipped`, `mark_delivered` actions. Look for Oban job insertion or after-action hooks.

If notifications are NOT being enqueued on status transitions, add after-action changes that insert `OrderNotificationWorker` jobs. Example:

```elixir
# In the :mark_shipped action
change(fn changeset, _context ->
  Ash.Changeset.after_action(changeset, fn _changeset, order ->
    %{order_id: order.id, event: "order_shipped"}
    |> Emakola.Notifications.Workers.OrderNotificationWorker.new()
    |> Oban.insert()

    {:ok, order}
  end)
end)
```

Do this for each status transition action that should trigger a notification.

- [ ] **Step 5: Run tests**

Run: `mix test test/emakola/notifications/tracking_sms_test.exs`
Expected: Pass

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/notifications/templates.ex lib/emakola/orders/resources/order.ex test/emakola/notifications/tracking_sms_test.exs
git commit -m "feat(notifications): add tracking URL to shipped SMS and verify notification wiring"
```

---

## Task 5: Coupon Display on Storefront

**Files:**
- Create: `test/emakola/orders/coupon_public_test.exs`
- Create: `test/emakola_web/live/storefront/cart_coupon_test.exs`
- Modify: `lib/emakola/orders/resources/coupon.ex` (add `is_public` field, `list_active_public` action)
- Modify: `lib/emakola/orders/orders.ex` (add domain function)
- Modify: `lib/emakola_web/components/storefront_components.ex` (promotion banner)
- Modify: `lib/emakola_web/live/storefront/cart_live.ex` (coupon input field)
- Modify: `lib/emakola_web/live/admin/coupon_live.ex` (add public toggle)
- Migration: `priv/repo/migrations/*_add_is_public_to_coupons.exs`

### Context for Agent

Coupon resource at `lib/emakola/orders/resources/coupon.ex` has: code, description, discount_type (percentage/fixed_amount/free_shipping), discount_value, max_discount_amount, minimum_order_amount, max_uses, uses_count, starts_at, expires_at, active.

Cart page at `lib/emakola_web/live/storefront/cart_live.ex` already has `promo_code` and `promo_error` assigns. Check if there's already a coupon input field in the render — the `cart_live.ex` may already have partial coupon UI.

The admin coupon page at `lib/emakola_web/live/admin/coupon_live.ex` handles full CRUD. Add a "Public" toggle checkbox to the create/edit form.

### Steps

- [ ] **Step 1: Write test for public coupon listing**

```elixir
defmodule Emakola.Orders.CouponPublicTest do
  use Emakola.DataCase, async: true

  describe "list_active_public_coupons" do
    test "returns only active, public, non-expired coupons" do
      store = create_test_store()

      # Active public coupon
      {:ok, public_coupon} = create_coupon(store, %{
        code: "SAVE20",
        is_public: true,
        active: true,
        discount_type: :percentage,
        discount_value: 2000,
        expires_at: DateTime.add(DateTime.utc_now(), 86400)
      })

      # Private coupon (should not appear)
      {:ok, _private} = create_coupon(store, %{
        code: "SECRET10",
        is_public: false,
        active: true,
        discount_type: :percentage,
        discount_value: 1000
      })

      # Expired coupon (should not appear)
      {:ok, _expired} = create_coupon(store, %{
        code: "OLDCODE",
        is_public: true,
        active: true,
        discount_type: :percentage,
        discount_value: 500,
        expires_at: DateTime.add(DateTime.utc_now(), -86400)
      })

      results = Emakola.Orders.list_active_public_coupons!(store.id)
      assert length(results) == 1
      assert hd(results).code == "SAVE20"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/orders/coupon_public_test.exs`

- [ ] **Step 3: Add `is_public` field to Coupon resource**

Create migration adding `is_public` boolean column (default false) to coupons table.

Modify `lib/emakola/orders/resources/coupon.ex`:

Add attribute:
```elixir
attribute :is_public, :boolean do
  default(false)
  allow_nil?(false)
  public?(true)
end
```

Add to `:create` and `:update` accept lists: `:is_public`

Add new action:
```elixir
read :list_active_public do
  argument(:store_id, :uuid, allow_nil?: false)

  filter(expr(
    store_id == ^arg(:store_id) and
    active == true and
    is_public == true and
    (is_nil(expires_at) or expires_at > now()) and
    (is_nil(starts_at) or starts_at <= now()) and
    (is_nil(max_uses) or uses_count < max_uses)
  ))
end
```

- [ ] **Step 4: Register in Orders domain**

Add to `lib/emakola/orders/orders.ex`:

```elixir
define(:list_active_public_coupons, action: :list_active_public, args: [:store_id])
```

Run migration: `mix ecto.migrate`

- [ ] **Step 5: Run test**

Run: `mix test test/emakola/orders/coupon_public_test.exs`

- [ ] **Step 6: Add promotion banner to storefront**

Add a `promo_banner/1` component to `lib/emakola_web/components/storefront_components.ex`:

```elixir
attr :coupons, :list, default: []
attr :store, :map, required: true

def promo_banner(assigns) do
  # Renders a slide-down banner at top of page
  # Shows first active public coupon: "Use code SAVE20 for 20% off!"
  # Dismissible with X button (uses JS.hide)
  # Ticket-style visual: dashed border, amber background
  # Only renders if coupons list is non-empty
end
```

Format coupon display text based on discount_type:
- `:percentage` → "X% off" (discount_value / 100)
- `:fixed_amount` → "GHS X off" (format from pesewas)
- `:free_shipping` → "Free shipping"

- [ ] **Step 7: Add coupon input to cart page**

Modify `lib/emakola_web/live/storefront/cart_live.ex`:

The cart already has `promo_code` and `promo_error` assigns. Add:

1. A coupon input UI in the order summary section:
   - Text input + "Apply" button
   - Success state: green badge showing applied code and discount
   - Error state: red text with error message
   - Remove button to clear applied coupon

2. Event handlers:
   - `apply_coupon`: validates code via `Emakola.Orders.find_coupon_by_code(store_id, code)`, checks validity (active, not expired, usage limit, minimum order), calculates discount, updates cart totals
   - `remove_coupon`: clears the applied coupon

3. Update `assign_totals/2` to account for applied coupon discount.

- [ ] **Step 8: Add public toggle to admin coupon form**

Modify `lib/emakola_web/live/admin/coupon_live.ex`:

Add a checkbox for `is_public` in the coupon create/edit form. Label: "Show on storefront" with helper text "Display this coupon publicly to customers".

- [ ] **Step 9: Load public coupons in storefront LiveViews**

In `StoreLive` and other key storefront pages, load public coupons in mount:

```elixir
public_coupons =
  try do
    Emakola.Orders.list_active_public_coupons!(store.id)
  rescue
    _ -> []
  end

|> assign(:public_coupons, public_coupons)
```

Render the promo banner in the page template.

- [ ] **Step 10: Run tests**

Run: `mix test test/emakola/orders/coupon_public_test.exs test/emakola_web/live/storefront/cart_coupon_test.exs`

- [ ] **Step 11: Commit**

```bash
git add lib/emakola/orders/resources/coupon.ex lib/emakola/orders/orders.ex lib/emakola_web/components/storefront_components.ex lib/emakola_web/live/storefront/cart_live.ex lib/emakola_web/live/admin/coupon_live.ex priv/repo/migrations/ test/
git commit -m "feat(orders): add public coupon display with storefront banner and cart input"
```

---

## Task 6: Inventory Management Admin Page

**Files:**
- Create: `lib/emakola_web/live/admin/inventory_live.ex`
- Create: `lib/emakola_web/components/inventory_components.ex`
- Create: `test/emakola_web/live/admin/inventory_live_test.exs`
- Modify: `lib/emakola_web/router.ex` (add route)
- Modify: `lib/emakola/catalog/catalog.ex` (add variant listing action if needed)

### Context for Agent

Variant resource at `lib/emakola/catalog/resources/variant.ex` has:
- `stock_quantity` (integer, default 0)
- `track_inventory` (boolean, default true)
- `low_stock_alerted` (boolean)
- Actions: `adjust_stock` (atomic delta), `restock` (with alert reset), `low_stock` (read with threshold filter)
- Product relationship: `belongs_to :product`

Catalog domain defines: `list_low_stock(threshold, store_id)`

The admin pages use the app layout with sidebar. Check `lib/emakola_web/components/layouts/app.html.heex` for the layout structure. Existing admin pages like `review_live.ex`, `payments_live.ex`, `coupon_live.ex` show the patterns for: page header, filters, tables, modals.

### Steps

- [ ] **Step 1: Write inventory page test**

Create `test/emakola_web/live/admin/inventory_live_test.exs`:

```elixir
defmodule EmakolaWeb.Admin.InventoryLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    {merchant, store} = create_authenticated_merchant()
    product = create_test_product(store, "Test Product", :active)
    variant = create_test_variant(product, store, %{stock_quantity: 5, sku: "TST-001"})

    %{merchant: merchant, store: store, product: product, variant: variant}
  end

  describe "inventory page" do
    test "displays stock overview cards", %{conn: conn, store: store} do
      conn = log_in_merchant(conn, store)
      {:ok, _view, html} = live(conn, "/admin/inventory")

      assert html =~ "Inventory"
      assert html =~ "TST-001"
    end

    test "adjusts stock quantity inline", %{conn: conn, store: store, variant: variant} do
      conn = log_in_merchant(conn, store)
      {:ok, view, _html} = live(conn, "/admin/inventory")

      html = view
        |> element("#adjust-stock-#{variant.id}")
        |> render_click(%{"delta" => "10"})

      assert html =~ "15"  # 5 + 10
    end
  end
end
```

Adapt authentication helpers to match existing test patterns. Check how other admin LiveView tests authenticate merchants.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/admin/inventory_live_test.exs`

- [ ] **Step 3: Add variant listing action if needed**

Check if a `list_variants_by_store` action exists on Variant. If not, add one:

In `lib/emakola/catalog/resources/variant.ex`:
```elixir
read :list_by_store do
  argument(:store_id, :uuid, allow_nil?: false)
  filter(expr(store_id == ^arg(:store_id)))
  prepare(build(sort: [stock_quantity: :asc], load: [:product]))
end
```

In `lib/emakola/catalog/catalog.ex`:
```elixir
define(:list_variants_by_store, action: :list_by_store, args: [:store_id])
```

- [ ] **Step 4: Create inventory components**

Create `lib/emakola_web/components/inventory_components.ex`:

```elixir
defmodule EmakolaWeb.InventoryComponents do
  use Phoenix.Component

  def stock_status_badge(assigns) do
    {label, classes} = stock_status(assigns.quantity)
    assigns = assign(assigns, label: label, classes: classes)

    ~H"""
    <span class={"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium #{@classes}"}>
      <span class={"w-1.5 h-1.5 rounded-full " <> dot_class(@quantity)}></span>
      <%= @label %>
    </span>
    """
  end

  defp stock_status(qty) when qty <= 0, do: {"Out of Stock", "bg-red-50 text-red-700"}
  defp stock_status(qty) when qty < 10, do: {"Low Stock", "bg-amber-50 text-amber-700"}
  defp stock_status(_qty), do: {"In Stock", "bg-green-50 text-green-700"}

  defp dot_class(qty) when qty <= 0, do: "bg-red-500 animate-pulse"
  defp dot_class(qty) when qty < 10, do: "bg-amber-500"
  defp dot_class(_qty), do: "bg-green-500"

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :color, :string, default: "gray"
  attr :icon_path, :string, required: true

  def stat_card(assigns) do
    ~H"""
    <div class={"rounded-2xl border p-5 bg-white"}>
      <div class="flex items-center gap-3">
        <div class={"w-10 h-10 rounded-xl flex items-center justify-center bg-#{@color}-50"}>
          <svg class={"w-5 h-5 text-#{@color}-600"} fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d={@icon_path} />
          </svg>
        </div>
        <div>
          <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
          <p class="text-xs text-gray-500"><%= @label %></p>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 5: Create inventory LiveView**

Create `lib/emakola_web/live/admin/inventory_live.ex`:

Key sections:
1. **Stat cards** at top: Total SKUs, In Stock, Low Stock (< 10), Out of Stock (= 0)
2. **Filter bar**: status filter (All/In Stock/Low Stock/Out of Stock), search by product name or SKU
3. **Stock table**: Product name, Variant/SKU, Current Stock (with color), Status badge, +/- adjustment buttons
4. **Inline stock adjustment**: clicking +/- calls `Emakola.Catalog.Variant |> Ash.get!() |> Ash.update!(:adjust_stock, %{delta: delta})`
5. **Bulk restock modal**: select multiple variants, set new quantity

Follow patterns from `review_live.ex` or `payments_live.ex` for page structure.

Load data in mount:
```elixir
variants = load_variants_with_products(store.id)
stats = compute_stock_stats(variants)
```

Event handlers:
- `adjust_stock` — increments/decrements a single variant
- `filter` — filters the table by status
- `search` — filters by product name or SKU

- [ ] **Step 6: Add route and sidebar link**

Modify `lib/emakola_web/router.ex` — add in `:app` live_session:
```elixir
live "/admin/inventory", Admin.InventoryLive
```

Add sidebar link for "Inventory" with the "package" icon, placed after "Products".

- [ ] **Step 7: Run tests**

Run: `mix test test/emakola_web/live/admin/inventory_live_test.exs`

- [ ] **Step 8: Commit**

```bash
git add lib/emakola_web/live/admin/inventory_live.ex lib/emakola_web/components/inventory_components.ex lib/emakola_web/router.ex lib/emakola/catalog/resources/variant.ex lib/emakola/catalog/catalog.ex test/
git commit -m "feat(admin): add inventory management page with stock overview and inline editing"
```

---

## Task 7: Store Analytics PDF Export

**Files:**
- Create: `lib/emakola/analytics/pdf_report.ex`
- Create: `lib/emakola_web/controllers/export_controller.ex`
- Create: `test/emakola/analytics/pdf_report_test.exs`
- Modify: `mix.exs` (add chromic_pdf dependency)
- Modify: `lib/emakola_web/router.ex` (add export route)
- Modify: `lib/emakola_web/live/admin/report_live/index.ex` (add export button)

### Context for Agent

The dashboard and report pages already compute analytics data. Check:
- `lib/emakola_web/live/admin/report_live/index.ex` — what data it loads
- `lib/emakola/analytics/` — existing analytics modules
- `lib/emakola_web/live/admin/dashboard_live.ex` or similar — dashboard data loading

For PDF generation, `chromic_pdf` is the best Elixir library — it uses Chrome headless via the CDP protocol, produces high-quality PDFs, and is well-maintained. Alternative: generate a clean HTML page and let the browser print it, but that's less reliable.

Since adding a dependency requires `mix deps.get`, the agent should handle that.

### Steps

- [ ] **Step 1: Add chromic_pdf dependency**

Modify `mix.exs` — add to deps:
```elixir
{:chromic_pdf, "~> 1.17"}
```

Run: `mix deps.get`

Add ChromicPDF to the application supervision tree in `lib/emakola/application.ex`:
```elixir
children = [
  # ... existing children ...
  ChromicPDF
]
```

- [ ] **Step 2: Write PDF report test**

Create `test/emakola/analytics/pdf_report_test.exs`:

```elixir
defmodule Emakola.Analytics.PdfReportTest do
  use Emakola.DataCase, async: false  # ChromicPDF is global

  alias Emakola.Analytics.PdfReport

  describe "generate/3" do
    test "generates a PDF binary for a store's analytics" do
      store = create_test_store()
      # Create some orders for the store
      customer = create_test_customer(store)
      create_test_order(store, customer, :delivered)
      create_test_order(store, customer, :confirmed)

      date_range = %{
        start_date: Date.add(Date.utc_today(), -30),
        end_date: Date.utc_today()
      }

      assert {:ok, pdf_binary} = PdfReport.generate(store, date_range)
      assert is_binary(pdf_binary)
      assert byte_size(pdf_binary) > 0
      # PDF files start with %PDF
      assert <<"%PDF", _rest::binary>> = pdf_binary
    end
  end

  describe "report_data/2" do
    test "computes analytics data for date range" do
      store = create_test_store()
      customer = create_test_customer(store)
      create_test_order(store, customer, :delivered)

      date_range = %{
        start_date: Date.add(Date.utc_today(), -30),
        end_date: Date.utc_today()
      }

      data = PdfReport.report_data(store, date_range)

      assert is_map(data)
      assert Map.has_key?(data, :total_revenue)
      assert Map.has_key?(data, :order_count)
      assert Map.has_key?(data, :top_products)
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/emakola/analytics/pdf_report_test.exs`

- [ ] **Step 4: Create PDF report module**

Create `lib/emakola/analytics/pdf_report.ex`:

```elixir
defmodule Emakola.Analytics.PdfReport do
  @moduledoc """
  Generates PDF analytics reports for stores.
  Uses ChromicPDF to render HTML templates to PDF.
  """

  require Ash.Query

  def generate(store, date_range) do
    data = report_data(store, date_range)
    html = render_html(store, data, date_range)

    ChromicPDF.print_to_pdf({:html, html},
      print_to_pdf: %{
        paperWidth: 8.5,
        paperHeight: 11,
        marginTop: 0.5,
        marginBottom: 0.5,
        marginLeft: 0.5,
        marginRight: 0.5
      }
    )
  end

  def report_data(store, date_range) do
    orders = load_orders_in_range(store.id, date_range)

    %{
      total_revenue: Enum.sum(Enum.map(orders, & &1.total)),
      order_count: length(orders),
      avg_order_value: avg_order_value(orders),
      top_products: top_products(store.id, date_range),
      order_status_breakdown: status_breakdown(orders),
      currency: store.currency || "GHS"
    }
  end

  defp load_orders_in_range(store_id, %{start_date: start_date, end_date: end_date}) do
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(end_date, ~T[23:59:59], "Etc/UTC")

    Emakola.Orders.Order
    |> Ash.Query.filter(store_id == ^store_id and inserted_at >= ^start_dt and inserted_at <= ^end_dt)
    |> Ash.Query.load([:line_items])
    |> Ash.read!(authorize?: false)
  end

  defp avg_order_value([]), do: 0
  defp avg_order_value(orders) do
    div(Enum.sum(Enum.map(orders, & &1.total)), length(orders))
  end

  defp top_products(store_id, _date_range) do
    # Load active products sorted by order count or revenue
    # Simplified: return top products by name
    Emakola.Catalog.list_products_by_store_and_status!(store_id, :active)
    |> Enum.take(10)
    |> Enum.map(&%{title: &1.title, id: &1.id})
  end

  defp status_breakdown(orders) do
    Enum.frequencies_by(orders, & &1.status)
  end

  defp render_html(store, data, date_range) do
    # Generate clean HTML report
    # Use inline CSS for PDF rendering (no external stylesheets)
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; color: #1a1a1a; padding: 0; margin: 0; font-size: 13px; }
        .header { background: #1C1917; color: white; padding: 30px 40px; }
        .header h1 { margin: 0 0 4px 0; font-size: 22px; font-weight: 600; }
        .header .subtitle { color: #94A3B8; font-size: 13px; }
        .content { padding: 30px 40px; }
        .stats { display: flex; gap: 20px; margin-bottom: 30px; }
        .stat-card { flex: 1; border: 1px solid #E2E8F0; border-radius: 12px; padding: 16px; }
        .stat-value { font-size: 24px; font-weight: 700; color: #0F172A; }
        .stat-label { font-size: 11px; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-top: 2px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { text-align: left; padding: 10px 12px; background: #F8FAFC; font-size: 11px; text-transform: uppercase; color: #64748B; letter-spacing: 0.5px; border-bottom: 1px solid #E2E8F0; }
        td { padding: 10px 12px; border-bottom: 1px solid #F1F5F9; }
        .section-title { font-size: 15px; font-weight: 600; color: #0F172A; margin: 30px 0 10px 0; }
        .footer { text-align: center; color: #94A3B8; font-size: 11px; padding: 20px; border-top: 1px solid #E2E8F0; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{store.name} Analytics Report</h1>
        <div class="subtitle">#{Date.to_string(date_range.start_date)} to #{Date.to_string(date_range.end_date)} &middot; Generated #{Date.to_string(Date.utc_today())}</div>
      </div>
      <div class="content">
        <div class="stats">
          <div class="stat-card">
            <div class="stat-value">#{format_currency(data.total_revenue, data.currency)}</div>
            <div class="stat-label">Total Revenue</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{data.order_count}</div>
            <div class="stat-label">Orders</div>
          </div>
          <div class="stat-card">
            <div class="stat-value">#{format_currency(data.avg_order_value, data.currency)}</div>
            <div class="stat-label">Avg Order Value</div>
          </div>
        </div>

        <div class="section-title">Order Status Breakdown</div>
        <table>
          <tr><th>Status</th><th>Count</th></tr>
          #{Enum.map_join(data.order_status_breakdown, "\n", fn {status, count} -> "<tr><td>#{status}</td><td>#{count}</td></tr>" end)}
        </table>

        <div class="section-title">Top Products</div>
        <table>
          <tr><th>#</th><th>Product</th></tr>
          #{Enum.with_index(data.top_products, 1) |> Enum.map_join("\n", fn {p, i} -> "<tr><td>#{i}</td><td>#{p.title}</td></tr>" end)}
        </table>
      </div>
      <div class="footer">#{store.name} &middot; Powered by Emakola</div>
    </body>
    </html>
    """
  end

  defp format_currency(amount, "GHS"), do: "GH&#8373; #{:erlang.float_to_binary(amount / 100, decimals: 2)}"
  defp format_currency(amount, "NGN"), do: "&#8358; #{:erlang.float_to_binary(amount / 100, decimals: 2)}"
  defp format_currency(amount, _), do: "#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
end
```

- [ ] **Step 5: Create export controller**

Create `lib/emakola_web/controllers/export_controller.ex`:

```elixir
defmodule EmakolaWeb.ExportController do
  use EmakolaWeb, :controller

  alias Emakola.Analytics.PdfReport

  def analytics_pdf(conn, params) do
    # Authenticate: get current merchant and their store
    # This controller should be behind auth — check how other admin controllers work
    store = conn.assigns[:current_store] || get_store_from_session(conn)

    date_range = parse_date_range(params)

    case PdfReport.generate(store, date_range) do
      {:ok, pdf_binary} ->
        filename = "#{store.slug}-analytics-#{Date.to_string(date_range.start_date)}-to-#{Date.to_string(date_range.end_date)}.pdf"

        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, pdf_binary)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: "/admin/reports")
    end
  end

  defp parse_date_range(params) do
    start_date =
      case params["start_date"] do
        nil -> Date.add(Date.utc_today(), -30)
        date_str -> Date.from_iso8601!(date_str)
      end

    end_date =
      case params["end_date"] do
        nil -> Date.utc_today()
        date_str -> Date.from_iso8601!(date_str)
      end

    %{start_date: start_date, end_date: end_date}
  end

  defp get_store_from_session(conn) do
    # Follow the pattern used by admin LiveViews to get the current store
    # This likely involves reading from the session or conn assigns
    # Check how RequireAuth hook and AssignDefaults hook work
    nil
  end
end
```

Note: The authentication pattern for this controller needs to match how the app authenticates admin users. Check the `RequireAuth` and `AssignDefaults` hooks to understand how `current_user` and store are resolved, then apply the same pattern here (or use a plug pipeline).

- [ ] **Step 6: Add export route**

Modify `lib/emakola_web/router.ex`:

Add a new scope for authenticated admin downloads (outside the live_session but within auth):

```elixir
# Inside the "/" scope, after the live_session :app block:
scope "/admin", EmakolaWeb do
  pipe_through [:browser]  # Add auth plug if needed
  get "/export/analytics.pdf", ExportController, :analytics_pdf
end
```

Or if the auth is handled via session/plug, put it in the appropriate pipeline.

- [ ] **Step 7: Add export button to report page**

Modify `lib/emakola_web/live/admin/report_live/index.ex`:

Add an "Export PDF" button in the page header area:

```elixir
<a
  href={"/admin/export/analytics.pdf?start_date=#{@start_date}&end_date=#{@end_date}"}
  class="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-stone-900 text-white text-sm font-medium hover:bg-stone-800 transition-colors"
>
  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
  </svg>
  Export PDF
</a>
```

Add date range assigns (`@start_date`, `@end_date`) if not already present. Add date range selector UI: preset buttons (This Week, This Month, Last 30 Days) and custom date inputs.

- [ ] **Step 8: Run tests**

Run: `mix test test/emakola/analytics/pdf_report_test.exs`

Note: ChromicPDF requires Chrome/Chromium to be installed. If tests run in CI without Chrome, these tests should be tagged `@tag :pdf` and skipped in CI. For local testing, Chrome should be available.

- [ ] **Step 9: Commit**

```bash
git add mix.exs mix.lock lib/emakola/analytics/pdf_report.ex lib/emakola_web/controllers/export_controller.ex lib/emakola_web/live/admin/report_live/index.ex lib/emakola_web/router.ex lib/emakola/application.ex test/
git commit -m "feat(analytics): add PDF export for store analytics reports"
```

---

## Post-Implementation

After all 7 tasks are complete:

- [ ] Run full test suite: `mix test`
- [ ] Format: `mix format`
- [ ] Credo: `mix credo --strict`
- [ ] Verify no broken routes: `mix phx.routes`
- [ ] Update seeds if needed: add sample returns, wishlist items, public coupons
- [ ] Manual smoke test: start server with `mix phx.server` and verify each feature works
