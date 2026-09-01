# Admin Pages Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the four page redesigns drawn on the "Makola Admin Pages" canvas — Team roster filters + presence, Stores metrics, Delivery Zones metrics, Partners hub — one PR per page.

**Architecture:** Each page keeps its LiveView and event handlers; new numbers come from existing Ash aggregates and small query helpers in the domain layer (`Emakola.Platform.Stats`, `Emakola.Shipping`, `Emakola.Suppliers`), never from invented data. Filtering on the platform pages stays in-memory over the already-loaded rows (the Stores page pattern). The Partners hub moves the fourteen inline sections behind per-tool routes that reuse the existing section components and event handlers.

**Tech Stack:** Elixir 1.18 / Phoenix 1.8 LiveView / Ash 3.x / TailwindCSS. Tests: ExUnit + `Phoenix.LiveViewTest`, `Emakola.LiveViewHelpers`, `Emakola.Factory`.

**Spec:** design canvas https://claude.ai/code/artifact/63140d84-f5d7-480a-a96a-cfde13215a0f — sources `design/admin-metrics-pages/*.dc.html` + `canvas.json` (notes carry the data-source decisions).

## Global Constraints

- TDD: every task starts with a failing test (`mix test <file>`), then the minimum code.
- Money renders through the shared formatter as `GH₵ 1,250` — never floats, never per-page formatting.
- No emoji anywhere (copy, code, commits). Conventional commits: `feat(web): ...`, `test(web): ...`.
- Platform pages keep the platform vocabulary (blue selection, `bg-slate-900 rounded-[10px]` buttons, `severity_pill`, `filter_chip_classes` chips). Merchant pages keep the admin vocabulary (`admin_page_header`, `stat_card` with `tone`, `admin_card`).
- Merchant-facing copy: short labels, digits and pictures first (low-literacy audience).
- Nothing invents delivery-time metrics: Orders have no `delivered_at`/`shipped_at`.
- Before every commit: `mix test`, `mix format`, `mix credo --strict`; before pushing: `mix dialyzer`.
- One `mix test` at a time against the shared database.

---

## Page 1 — Platform Team: roster filters and presence

Branch `feature/platform-team-filters`.

### Task 1: Presence and filters in `TeamLive`

**Files:**
- Modify: `lib/emakola_web/live/platform/team_live.ex` (mount assigns, `load_team/1`, new events `filter_status`, `filter`, `clear_filters`)
- Modify: `lib/emakola_web/live/platform/team_components.ex` (roster header: search + permission select + status chips; row presence dot + `data-presence`; panel "Online"/"Last seen" line)
- Test: `test/emakola_web/live/platform/team_live_test.exs`

**Interfaces:**
- Produces assigns: `presence :: %{user_id => %{state: :online | :away | :offline, last_seen_at: DateTime.t() | nil}}`, `status_filter :: :all | :owners | :twofa_off | :deactivated | :invites`, `search :: String.t()`, `permission_filter :: atom | nil`, `visible_staff :: [User]`, `filter_counts :: %{all: n, owners: n, twofa_off: n, deactivated: n, invites: n}`.
- Online rule: an unrevoked session whose `last_seen_at` is within the last 10 minutes (`Sessions.touch/1` writes at most every 5). Away = has a session, older. Offline = no active session.

- [ ] **Step 1: Write the failing tests** (describe "roster filters" and "presence") — see the test file; they assert `#roster-count` text, `[data-presence]` values, and that filtered-out rows are absent.
- [ ] **Step 2: Run** `mix test test/emakola_web/live/platform/team_live_test.exs` — expect the new tests to FAIL (no `#filter-twofa_off`, no `[data-presence]`).
- [ ] **Step 3: Implement** — `load_team/1` builds `presence` from the sessions it already lists; `apply_filters/1` derives `visible_staff` and `filter_counts`; components render the chips with counts and the presence dot.
- [ ] **Step 4: Run the file again** — PASS; then `mix test` for the whole suite.
- [ ] **Step 5: Commit** `feat(web): platform staff can be filtered and show who is online`.

## Page 2 — Delivery Zones metrics (branch `feature/delivery-zone-metrics`)

### Task 2: `Emakola.Shipping.DeliveryMetrics`

**Files:**
- Create: `lib/emakola/shipping/delivery_metrics.ex`
- Modify: `lib/emakola/shipping/shipping.ex` (expose `zone_for_region/2`; `find_zone/2` uses it)
- Test: `test/emakola/shipping/delivery_metrics_test.exs`

**Interfaces:**
- `DeliveryMetrics.for_store(store_id, zones, opts \\ [days: 30])` returns
  `%{delivered: n, on_the_way: n, to_pack: n, fees_collected: pesewas, free_deliveries: n, fees_waived: pesewas, total_orders: n, zones_on: n, per_zone: %{zone_id => %{orders: n, fees: pesewas}}, unmatched: %{orders: n, fees: pesewas, regions: [{"Volta", 3}, ...]}}`.
- Orders: `Emakola.Orders.Order` for the store, `inserted_at >= now - days`, `status != :cancelled`; zone attribution = `Shipping.zone_for_region(zones, shipping_address["region"])` (name match, the same rule checkout uses); `on_the_way` = `:shipped`; `to_pack` = `:pending | :confirmed | :processing`; free delivery = matched zone with fee > 0 and order `delivery_fee == 0` (waived = that zone's fee).

- [ ] Write the unit test with a store, two zones (one paused), and orders across regions/statuses/dates; assert every key.
- [ ] Run `mix test test/emakola/shipping/delivery_metrics_test.exs` — FAIL (module missing).
- [ ] Implement; run — PASS. Commit `feat(shipping): delivery zone metrics from the orders a store already has`.

### Task 3: Delivery page renders the metrics

**Files:**
- Modify: `lib/emakola_web/live/admin/delivery_live/index.ex` (assign `metrics` in `load_zones/1`; tiles via `.stat_card`; Orders + Fees columns; unmatched row; "Where your orders go" bars; "What buyers pay" card; money through `EmakolaWeb.Helpers.Currency.format_price/1`)
- Test: `test/emakola_web/live/admin/delivery_live_test.exs`

- [ ] Write LiveView tests: `#delivery-metrics` shows delivered count and `GH₵` fees; `#zone-orders-<id>` / `#zone-fees-<id>` per zone; `#unmatched-zone-row` names the region; no orders → zeros and no unmatched row.
- [ ] Run the file — FAIL; implement; PASS; `mix test`; commit `feat(web): delivery zones show what they earned and where orders fell through`.

## Page 3 — Platform Stores metrics (branch `feature/platform-store-metrics`)

### Task 4: platform totals the tile row needs

**Files:**
- Modify: `lib/emakola/platform/stats.ex`
- Test: `test/emakola/platform/stats_test.exs`

**Interfaces (all return integers, 0 on error, like the existing functions):**
- `merchants_with_multiple_stores/0` — merchants holding more than one `StoreMembership`
- `merchants_joined_since(days)` — `Merchant.inserted_at >= now - days`
- `orders_since(days)`, `gmv_since(days)` (successful payments only, the `total_gmv` rule), `stores_with_orders_since(days)` (distinct `store_id`)
- `featured_stores/0`, `featuring_eligible_stores/0` (`DirectoryStanding.eligible == true`, `authorize?: false`)

- [ ] Write the unit tests (factories: `create_merchant_with_store!`, `create_store_membership!`, `create_order!`, `create_payment!`, a `DirectoryStanding` `:record`); run — FAIL; implement; PASS; commit `feat(platform): stats for the stores tile row`.

### Task 5: Stores page — tiles, row facts, chips, "Store at a glance"

**Files:**
- Modify: `lib/emakola_web/live/platform/store_live/index.ex`
- Test: `test/emakola_web/live/platform/store_live_test.exs`

**Interfaces:**
- `load_stores/3` adds `load: [:product_count, :last_order_at, :payout_verified, store_memberships: [:merchant]]`; row shows member initials, `product_count`, `last_order_at` relative.
- New chips `:no_payout` (`payout_verified != true`) and `:quiet` (`last_order_at` nil or older than 30 days), counted like the existing ones.
- `handle_params` (connected only) assigns `platform_stats` from Task 4 for the four tiles: Stores (total / live / hidden), Merchants (total / multi-store / joined this week), Orders 30d (count / GMS paid / stores that sold), Featured (featured / eligible).
- Selecting a store loads `[:delivered_order_count_90d, :cancelled_order_count_90d, :successful_payment_count_90d, :view_count, :verified_review_count, :verified_review_rating_sum, :last_product_published_at, :kyc_approved]` for the "Store at a glance" strip (`#store-glance`).

- [ ] Tests: `#platform-store-stats` shows the merchant total; a row shows `data-merchants="2"` and the product count; chips `#filter-no_payout` / `#filter-quiet` narrow the list; `#store-glance` shows delivered count and members; run — FAIL; implement; PASS; `mix test`; commit `feat(web): platform stores show merchants and activity`.

## Page 4 — Partners hub (branch `feature/partners-hub`)

### Task 6: one event module, per-tool pages

**Files:**
- Create: `lib/emakola_web/live/admin/supply_network_live/events.ex` — every `handle_event/3` clause moved verbatim from `supply_network_live.ex` (they only touch `socket.assigns` + `Data.load_*`), plus `update_connection/4`.
- Create: `lib/emakola_web/live/admin/supply_tool_live.ex` — `mount(%{"tool" => slug})`: `Inputs.default_assigns()` + `Data.load_all/1` + `assign(:tool, tool)`; unknown slug → redirect to the hub. `handle_event/3` delegates to `Events`.
- Modify: `lib/emakola_web/router.ex` — `live "/admin/settings/supply-network/:tool", Admin.SupplyToolLive` inside `live_session :app` (after line 588).
- Modify: the section component modules so each tool's block is a public function component: `GoalComponents.goal/1` (income-plan), `OpportunityComponents.radar/1` + `business_in_a_box/1` (opportunity-radar), `CollaborationComponents.group_buys/1`, `sales_teams/1`, `franchises/1`, `passport/1`, `inventory_eligibility/1`, `CatalogComponents.content_studio/1`, `earn_catalog/1`, `listings/1`, `ActivationComponents.supplier_inbox/1`, `sales_kits/1`.
- Tool slugs → components: `income-plan`, `opportunity-radar`, `content-studio`, `commerce-passport`, `group-buys`, `sales-teams`, `micro-franchise`, `stock-holds`, `orders-to-fulfil`, `sales-kits`, `partner-products` (earn catalog + listings).
- Test: `test/emakola_web/live/admin/supply_tool_live_test.exs` — each slug renders its section id; unknown slug redirects. The existing `supply_network_live_test.exs` describes move to the tool route that hosts the ids they assert.

### Task 7: the hub

**Files:**
- Modify: `lib/emakola_web/live/admin/supply_network_live/components.ex` — `page/1` becomes the hub: header (`admin_page_header`, two-people icon, "Partners" / "Earn without buying stock", Browse suppliers + Invite a store), four `stat_card` tiles (`connection_count`, `listing_count` + low-stock count, `sales_revenue` + `sales_order_count`, `inbound_count`), First Money strip (`first_money`), partners list (rows from the `:connections` stream with per-partner listing count via `listing.offer.wholesaler_store_id` and order count via the sales shares of those listings; incoming invite row with Accept/Decline; invite form in place), Orders to fulfil (first two inbound rows + link to `orders-to-fulfil`), Sales kits (three counters + first two shares), Earn tools grid (eight doors, each with its live number: goal progress percent, `opportunity_radar_count`, `content_draft_count`, passport tier/score, `group_buy_count`, `sales_team_count`, franchise counts, reservation count), Added from partners (first three listings + "Show all").
- Modify: `lib/emakola_web/live/admin/supply_network_live/data.ex` — `partner_rows/1` (connections zipped with listing/order counts) and `low_stock_listing_count`.
- Modify: `lib/emakola_web/live/admin/supply_network_live.ex` — `handle_event/3` delegates to `Events`; keep `#supply-network-page`, `#connection-count`, `#supply-connection-form`, `#supply-connections`, `#first-money-journey`, `#sales-shares`, `#listing-count`, `#inbound-fulfillment-count` so the connection/journey tests keep passing on the hub.
- Test: `test/emakola_web/live/admin/supply_network_live_test.exs` (connections + first money + sales kits stay on the hub) and a new `describe "hub"` asserting tiles, partner rows (`#partner-<connection_id>` with `data-products`), the door counts (`#earn-tool-content-studio` shows the draft count) and links to the tool routes.

- [ ] Task 6 red/green/commit `refactor(web): supply network events and sections are reusable across pages`; Task 7 red/green/commit `feat(web): partners is a hub, not fourteen stacked sections`; `mix test`, credo, dialyzer; PR.
