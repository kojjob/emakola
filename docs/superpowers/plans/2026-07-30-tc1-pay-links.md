# TC-1 Pay Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shareable DM checkout links — catalog (reusable) and custom-amount (single-use) — at `makola.io/pay/:code`, producing ordinary orders so fees/settlement/refunds work unchanged.

**Architecture:** New `Emakola.Orders.PayLink` Ash resource + a slim `checkout_custom!/3` path in `CheckoutService` that creates a real order with a variant-less line item (snapshot fields carry the deal). Buyer LiveView mirrors `checkout_live`'s gateway initiation; webhook confirm claims single-use links `FOR UPDATE`. Admin LiveView + JSON:API expose creation.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x (attribute multitenancy on `store_id`), AshPostgres, Oban, Mox (gateway mocks), ExUnit.

**Spec:** `docs/superpowers/specs/2026-07-30-pay-links-design.md` (lands on `main` via PR #362; the plan is self-contained regardless).

## Global Constraints

- Money: integer minor units only (pesewas); custom `amount >= 100`; never floats.
- Every tenant-scoped query carries tenant context; PayLink uses attribute multitenancy `store_id`, `global?(true)` (matches `Fulfillment`).
- TDD: write the failing test first for every step; `mix test <file>` between steps.
- No storefront LiveView catch-all `handle_event/3` exists — every rendered control MUST have a handler (an unmatched event crashes the page).
- `assert_redirect/2` takes binary strings only, never regex.
- After `mix ash.codegen`, check generated migration formatting (`null: false` one-liners fail CI's formatter — split onto own line) and run `mix format`.
- Conventional commits; scopes here: `orders`, `web`, `payments`, `test`.
- Run `mix format && mix credo --strict` before each commit; full `mix test` before the final push. Parse the "Result:" line of test output — piped exit codes lie.

---

### Task 1: Drive-by flake fix — capture_log race in order_settlement_test

**Files:**
- Modify: `test/emakola/payments/order_settlement_test.exs:509-520`

**Interfaces:** none (test-only).

The test asserts `capture_log(...) == ""`, but async-suite `capture_log` sees ALL concurrent tests' output — CI run 30539592945 failed when a JSON:API test's warning landed in the window. Assert absence of THIS order's message instead of global silence.

- [ ] **Step 1: Change the assertion**

Replace (at ~line 514-519):

```elixir
      log =
        capture_log(fn ->
          assert OrderSettlement.sum_matches_total?(order, allocations)
        end)

      assert log == ""
```

with:

```elixir
      log =
        capture_log(fn ->
          assert OrderSettlement.sum_matches_total?(order, allocations)
        end)

      # Async-suite capture_log sees concurrent tests' output; assert only
      # that OUR order id was not logged, not that the world was silent.
      refute log =~ order.id
```

- [ ] **Step 2: Run the test file**

Run: `mix test test/emakola/payments/order_settlement_test.exs`
Expected: PASS (all tests).

- [ ] **Step 3: Commit**

```bash
git add test/emakola/payments/order_settlement_test.exs
git commit -m "test(payments): fix capture_log race in sum-invariant guard test"
```

---

### Task 2: LineItem — nullable variant + custom create action + stock-skip

**Files:**
- Modify: `lib/emakola/orders/resources/line_item.ex`
- Modify: `lib/emakola/orders/changes/decrement_stock.ex:33-40`
- Modify: `lib/emakola/orders/orders.ex` (code interface)
- Create: migration via `mix ash.codegen`
- Test: `test/emakola/orders/line_item_custom_test.exs`

**Interfaces:**
- Produces: `LineItem` create action `:create_custom` accepting
  `%{order_id, store_id, product_title, unit_price, quantity, fulfillment_id}`;
  sets `line_total = unit_price * quantity`, leaves `variant_id`/`variant_sku` nil.
- Produces: domain code interface `Emakola.Orders.create_custom_line_item/1..2`.
- Consumes: existing `:create` action + `Changes.DenormalizeVariant` (unchanged).

- [ ] **Step 1: Write the failing tests**

Create `test/emakola/orders/line_item_custom_test.exs`:

```elixir
defmodule Emakola.Orders.LineItemCustomTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.LineItem

  defp store_and_order do
    store = Emakola.Factory.create_store!()

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    {store, order}
  end

  test "create_custom builds a variant-less line with snapshots and line_total" do
    {store, order} = store_and_order()

    line =
      LineItem
      |> Ash.Changeset.for_create(:create_custom, %{
        order_id: order.id,
        store_id: store.id,
        product_title: "Custom kente dress — as agreed",
        unit_price: 25_000,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

    assert line.variant_id == nil
    assert line.variant_sku == nil
    assert line.product_title == "Custom kente dress — as agreed"
    assert line.unit_price == 25_000
    assert line.line_total == 25_000
  end

  test "create_custom rejects a missing title" do
    {store, order} = store_and_order()

    assert {:error, %Ash.Error.Invalid{}} =
             LineItem
             |> Ash.Changeset.for_create(:create_custom, %{
               order_id: order.id,
               store_id: store.id,
               unit_price: 25_000,
               quantity: 1
             })
             |> Ash.create(authorize?: false)
  end

  test "create_custom rejects non-positive unit_price" do
    {store, order} = store_and_order()

    assert {:error, %Ash.Error.Invalid{}} =
             LineItem
             |> Ash.Changeset.for_create(:create_custom, %{
               order_id: order.id,
               store_id: store.id,
               product_title: "X",
               unit_price: 0,
               quantity: 1
             })
             |> Ash.create(authorize?: false)
  end
end
```

(If `Emakola.Factory.create_store!/0` doesn't exist under that name, use the
store creation helper the factory actually exports — check
`test/support/factory.ex` and use its store builder; the rest is unchanged.)

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/orders/line_item_custom_test.exs`
Expected: FAIL — `:create_custom` is not an action / `variant_id` NOT NULL violation.

- [ ] **Step 3: Make LineItem variant optional + add the action**

In `lib/emakola/orders/resources/line_item.ex`:

1. `attribute :variant_id, :uuid` block: change `allow_nil?(false)` → `allow_nil?(true)`.
2. In the `belongs_to :variant` block add `allow_nil?(true)` if `define_attribute?` is false (the attribute above governs nullability).
3. Add to `actions do`:

```elixir
    create :create_custom do
      accept([:order_id, :store_id, :product_title, :unit_price, :quantity, :fulfillment_id])

      validate(present([:product_title, :unit_price]),
        message: "custom lines require a title and price"
      )

      validate(compare(:unit_price, greater_than: 0),
        message: "must be greater than 0"
      )

      change(fn changeset, _ctx ->
        qty = Ash.Changeset.get_attribute(changeset, :quantity) || 0
        price = Ash.Changeset.get_attribute(changeset, :unit_price) || 0
        Ash.Changeset.force_change_attribute(changeset, :line_total, qty * price)
      end)
    end
```

4. In `lib/emakola/orders/changes/decrement_stock.ex`, guard the loop body
   (currently `variant = line_item.variant` then decrements):

```elixir
      case line_item.variant do
        nil ->
          # Custom (variant-less) pay-link line — no stock to decrement.
          :ok

        variant ->
          # ... existing decrement body unchanged ...
      end
```

5. In `lib/emakola/orders/orders.ex`, inside `resource Emakola.Orders.LineItem do`:

```elixir
      define(:create_custom_line_item, action: :create_custom)
```

- [ ] **Step 4: Generate + inspect the migration**

Run: `mix ash.codegen make_line_item_variant_optional`
Inspect the generated migration under `priv/repo/migrations/`: it should
`modify :variant_id, :uuid, null: true` (or drop the NOT NULL). Fix any
`references(...), null: ...` one-liner formatting; run `mix format`.
Run: `mix ecto.migrate && MIX_ENV=test mix ecto.migrate`

- [ ] **Step 5: Run the tests**

Run: `mix test test/emakola/orders/line_item_custom_test.exs test/emakola/orders/`
Expected: new file PASS; existing orders tests still PASS (DenormalizeVariant path untouched).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/orders priv/repo/migrations test/emakola/orders/line_item_custom_test.exs
git commit -m "feat(orders): variant-less custom line items behind create_custom"
```

---

### Task 3: PayLink resource + Order.pay_link_id

**Files:**
- Create: `lib/emakola/orders/resources/pay_link.ex`
- Create: `lib/emakola/orders/changes/generate_pay_link_code.ex`
- Modify: `lib/emakola/orders/resources/order.ex` (attribute + accept)
- Modify: `lib/emakola/orders/orders.ex` (register resource + interfaces)
- Create: migration via `mix ash.codegen`
- Test: `test/emakola/orders/pay_link_test.exs`

**Deliberate deferral:** the spec's `protected :boolean` column (added by the
TC-2 amendment) is NOT built here — its inherit-from-store semantics depend on
TC-2's `buyer_protection_enabled` setting. TC-2's plan adds both together.

**Interfaces:**
- Produces: `Emakola.Orders.PayLink` with attributes
  `code :string` (unique, 8-char lower base32), `type :atom (:catalog | :custom)`,
  `variant_id :uuid nil`, `quantity :integer default 1`, `title :string nil`,
  `amount :integer nil`, `collect_delivery :boolean default true`,
  `status :atom (:active | :paid | :cancelled) default :active`,
  `expires_at :utc_datetime_usec nil`, `note :string nil`,
  `opened_count :integer default 0`, `created_by_user_id :uuid`, timestamps.
- Produces: actions `:create`, `:get_by_code` (read), `:cancel`, `:mark_paid`,
  `:increment_opened`; domain interfaces `Emakola.Orders.create_pay_link/1..2`,
  `get_pay_link_by_code/1..2`, `cancel_pay_link/1..2`.
- Produces: helper `Emakola.Orders.PayLink.usable?/1` → `:ok | {:error, :expired | :cancelled | :consumed}`.
- Produces: `Order.pay_link_id :uuid nil`, accepted on `:create`.
- Expiry is data: `usable?/1` compares `expires_at` to `DateTime.utc_now()`; no worker.

- [ ] **Step 1: Write the failing tests**

Create `test/emakola/orders/pay_link_test.exs`:

```elixir
defmodule Emakola.Orders.PayLinkTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.PayLink

  defp create!(store, attrs) do
    PayLink
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  test "custom link gets an 8-char code, active status, 7-day default expiry" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    assert String.match?(link.code, ~r/^[a-z2-7]{8}$/)
    assert link.status == :active
    assert_in_delta DateTime.diff(link.expires_at, DateTime.utc_now(), :day), 7, 1
  end

  test "catalog link has no default expiry and keeps its variant" do
    store = Emakola.Factory.create_store!()
    variant = Emakola.Factory.create_variant!(store)
    link = create!(store, %{type: :catalog, variant_id: variant.id})

    assert link.expires_at == nil
    assert link.variant_id == variant.id
  end

  test "custom link requires amount >= 100" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Deal",
               amount: 99
             })
             |> Ash.create(authorize?: false)
  end

  test "catalog link requires variant_id; custom requires title+amount" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :catalog})
             |> Ash.create(authorize?: false)

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :custom})
             |> Ash.create(authorize?: false)
  end

  test "usable?/1 covers active, expired, cancelled, consumed" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})
    assert :ok = PayLink.usable?(link)

    expired = %{link | expires_at: DateTime.add(DateTime.utc_now(), -1, :day)}
    assert {:error, :expired} = PayLink.usable?(expired)

    assert {:error, :cancelled} = PayLink.usable?(%{link | status: :cancelled})
    assert {:error, :consumed} = PayLink.usable?(%{link | status: :paid})
  end

  test "tenant isolation: store B cannot read store A's link by code" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    link = create!(store_a, %{type: :custom, title: "Deal", amount: 25_000})

    assert {:ok, []} =
             PayLink
             |> Ash.Query.for_read(:get_by_code, %{code: link.code})
             |> Ash.Query.set_tenant(store_b.id)
             |> Ash.read(authorize?: false)
  end

  test "increment_opened bumps the counter" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    updated =
      link
      |> Ash.Changeset.for_update(:increment_opened, %{})
      |> Ash.update!(authorize?: false)

    assert updated.opened_count == 1
  end
end
```

(Adjust `Emakola.Factory.create_store!/create_variant!` to the factory's
actual helper names — check `test/support/factory.ex` before writing.)

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/orders/pay_link_test.exs`
Expected: FAIL — module `Emakola.Orders.PayLink` undefined.

- [ ] **Step 3: Implement the code generator change**

Create `lib/emakola/orders/changes/generate_pay_link_code.ex`:

```elixir
defmodule Emakola.Orders.Changes.GeneratePayLinkCode do
  @moduledoc """
  Sets an 8-char lowercase base32 `code` (5 random bytes → a-z2-7, no
  ambiguous 0/1/8/9) on a new PayLink. ~40 bits — unguessable, short
  enough to read aloud over a call.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    code =
      :crypto.strong_rand_bytes(5)
      |> Base.encode32(case: :lower, padding: false)

    Ash.Changeset.force_change_attribute(changeset, :code, code)
  end
end
```

- [ ] **Step 4: Implement the resource**

Create `lib/emakola/orders/resources/pay_link.ex`:

```elixir
defmodule Emakola.Orders.PayLink do
  @moduledoc """
  A shareable checkout link a merchant drops into a DM. Two flavors:

    * `:catalog` — points at a variant, reusable, no default expiry.
    * `:custom` — negotiated `title` + `amount` (minor units), single-use
      (consumed → `:paid` by the webhook claim), default expiry 7 days.

  Expiry is data — `usable?/1` compares against now; nothing sweeps links.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("pay_links")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)
    attribute(:type, :atom, allow_nil?: false, public?: true, constraints: [one_of: [:catalog, :custom]])
    attribute(:variant_id, :uuid, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, default: 1, public?: true)
    attribute(:title, :string, public?: true, constraints: [max_length: 200])
    attribute(:amount, :integer, public?: true)
    attribute(:collect_delivery, :boolean, allow_nil?: false, default: true, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:active)
      public?(true)
      constraints(one_of: [:active, :paid, :cancelled])
    end

    attribute(:expires_at, :utc_datetime_usec, public?: true)
    attribute(:note, :string, public?: true, constraints: [max_length: 500])
    attribute(:opened_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:created_by_user_id, :uuid, public?: true)
    timestamps()
  end

  identities do
    identity(:unique_code, [:code])
  end

  policies do
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant store-membership for create/cancel; public buyer reads and
    # webhook/internal updates opt in via authorize?: false at call sites —
    # the same posture as Order/LineItem.
    policy action_type([:create, :update]) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate(present([:variant_id]),
      where: [attribute_equals(:type, :catalog)],
      message: "catalog links need a product variant"
    )

    validate(present([:title, :amount]),
      where: [attribute_equals(:type, :custom)],
      message: "custom links need a title and amount"
    )

    validate(compare(:amount, greater_than_or_equal_to: 100),
      where: [present(:amount)],
      message: "must be at least 100 (GH₵1.00)"
    )

    validate(compare(:quantity, greater_than: 0))
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :type,
        :variant_id,
        :quantity,
        :title,
        :amount,
        :collect_delivery,
        :expires_at,
        :note,
        :created_by_user_id
      ])

      change(Emakola.Orders.Changes.GeneratePayLinkCode)

      # Custom deals go stale: default 7-day expiry when none given.
      change(fn changeset, _ctx ->
        type = Ash.Changeset.get_attribute(changeset, :type)
        expires = Ash.Changeset.get_attribute(changeset, :expires_at)

        if type == :custom and is_nil(expires) do
          Ash.Changeset.force_change_attribute(
            changeset,
            :expires_at,
            DateTime.add(DateTime.utc_now(), 7, :day)
          )
        else
          changeset
        end
      end)
    end

    read :get_by_code do
      get?(true)
      argument(:code, :string, allow_nil?: false)
      filter(expr(code == ^arg(:code)))
    end

    update :cancel do
      accept([])
      validate(attribute_in(:status, [:active]))
      change(set_attribute(:status, :cancelled))
    end

    update :mark_paid do
      accept([])
      validate(attribute_in(:status, [:active]))
      change(set_attribute(:status, :paid))
    end

    update :increment_opened do
      accept([])
      change(atomic_update(:opened_count, expr(opened_count + 1)))
    end
  end

  @doc "Is this link still payable? Checks status, then expiry."
  def usable?(%__MODULE__{status: :cancelled}), do: {:error, :cancelled}
  def usable?(%__MODULE__{status: :paid}), do: {:error, :consumed}

  def usable?(%__MODULE__{expires_at: %DateTime{} = at}) do
    if DateTime.compare(at, DateTime.utc_now()) == :lt, do: {:error, :expired}, else: :ok
  end

  def usable?(%__MODULE__{}), do: :ok
end
```

- [ ] **Step 5: Register in the domain + Order provenance**

In `lib/emakola/orders/orders.ex` add inside `resources do`:

```elixir
    resource Emakola.Orders.PayLink do
      define(:create_pay_link, action: :create)
      define(:get_pay_link_by_code, action: :get_by_code, args: [:code])
      define(:cancel_pay_link, action: :cancel)
      define(:mark_pay_link_paid, action: :mark_paid)
    end
```

In `lib/emakola/orders/resources/order.ex`: add near the other uuid attributes

```elixir
    attribute(:pay_link_id, :uuid, public?: true)
```

and add `:pay_link_id` to the `:create` action's `accept([...])` list.

- [ ] **Step 6: Codegen + migrate**

Run: `mix ash.codegen add_pay_links`
Inspect migration (unique index on `code`, `pay_link_id` on orders); fix
formatting; `mix format`.
Run: `mix ecto.migrate && MIX_ENV=test mix ecto.migrate`

- [ ] **Step 7: Run tests**

Run: `mix test test/emakola/orders/pay_link_test.exs`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/emakola/orders priv/repo/migrations test/emakola/orders/pay_link_test.exs
git commit -m "feat(orders): PayLink resource with code generation and single-use states"
```

---

### Task 4: CheckoutService.checkout_custom!/3 + phone-first customer resolution

**Files:**
- Modify: `lib/emakola/orders/checkout_service.ex`
- Test: `test/emakola/orders/checkout_custom_test.exs`

**Interfaces:**
- Produces: `CheckoutService.checkout_custom!(store_id, %{title: String.t(), unit_price: pos_integer()}, opts)` →
  `{:ok, order} | {:error, reason}`. `opts`: `:customer_name`, `:customer_phone`
  (required), `:customer_email` (optional), `:shipping_address`, `:notes`,
  `:pay_link_id`.
- Produces: `CheckoutService.phone_placeholder_email/1` — deterministic
  `"p<digits>@phone.customers.makola.io"` from an E.164/local phone, so the
  same phone always resolves to the same customer via the existing
  email-keyed `Customer :find_or_create`.
- Consumes: Task 2's `:create_custom` line action; Task 3's `Order.pay_link_id`.
- Reuses: `resolve_customer/2`, `create_fulfillments/5` (single merchant-owned
  group: `%{nil => fulfillment_id}`), the existing totals-update code path.

- [ ] **Step 1: Write the failing tests**

Create `test/emakola/orders/checkout_custom_test.exs`:

```elixir
defmodule Emakola.Orders.CheckoutCustomTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.CheckoutService

  test "creates a paid-pending order with one variant-less line and correct total" do
    store = Emakola.Factory.create_store!()

    assert {:ok, order} =
             CheckoutService.checkout_custom!(
               store.id,
               %{title: "Custom kente dress", unit_price: 25_000},
               customer_name: "Ama Mensah",
               customer_phone: "+233201234567",
               pay_link_id: Ash.UUID.generate()
             )

    assert order.total == 25_000
    assert order.pay_link_id

    [line] =
      Emakola.Orders.LineItem
      |> Ash.Query.filter(order_id == ^order.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert line.variant_id == nil
    assert line.product_title == "Custom kente dress"
  end

  test "same phone twice resolves to the same customer" do
    store = Emakola.Factory.create_store!()
    opts = [customer_name: "Ama", customer_phone: "0201234567"]

    {:ok, o1} = CheckoutService.checkout_custom!(store.id, %{title: "A", unit_price: 500}, opts)
    {:ok, o2} = CheckoutService.checkout_custom!(store.id, %{title: "B", unit_price: 700}, opts)

    assert o1.customer_id == o2.customer_id
  end

  test "explicit email wins over the placeholder" do
    store = Emakola.Factory.create_store!()

    {:ok, order} =
      CheckoutService.checkout_custom!(
        store.id,
        %{title: "A", unit_price: 500},
        customer_name: "Ama",
        customer_phone: "0201234567",
        customer_email: "ama@example.com"
      )

    customer = Ash.get!(Emakola.Customers.Customer, order.customer_id,
      authorize?: false, tenant: store.id)

    assert to_string(customer.email) == "ama@example.com"
  end

  test "rejects unit_price below 1" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             CheckoutService.checkout_custom!(
               store.id,
               %{title: "A", unit_price: 0},
               customer_name: "Ama", customer_phone: "0201234567"
             )
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/orders/checkout_custom_test.exs`
Expected: FAIL — `checkout_custom!/3` undefined.

- [ ] **Step 3: Implement**

Add to `lib/emakola/orders/checkout_service.ex` (public function near `checkout!/3`, helpers at the bottom):

```elixir
  @doc """
  Checkout for a single custom (variant-less) pay-link line. Creates a real
  pending order — fees, settlement, refunds, notifications all see an
  ordinary order. No stock, coupons, or supplier dispatch apply.

  `opts`: :customer_name, :customer_phone (required), :customer_email
  (optional — a deterministic phone placeholder is derived when absent),
  :shipping_address, :notes, :pay_link_id.
  """
  def checkout_custom!(store_id, %{title: title, unit_price: unit_price}, opts) do
    cond do
      not is_binary(title) or title == "" ->
        {:error, :invalid_title}

      not is_integer(unit_price) or unit_price < 1 ->
        {:error, :invalid_unit_price}

      true ->
        opts = Keyword.put_new(opts, :customer_email, phone_placeholder_email(opts[:customer_phone]))
        run_checkout_custom(store_id, title, unit_price, opts)
    end
  end

  @doc """
  Deterministic placeholder email for phone-first buyers: the same phone
  always maps to the same address, so the email-keyed Customer
  :find_or_create stays idempotent. The domain is ours; nothing routes to
  a stranger's inbox, and buyer receipts go out via SMS/WhatsApp anyway.
  """
  def phone_placeholder_email(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")
    "p#{digits}@phone.customers.makola.io"
  end

  defp run_checkout_custom(store_id, title, unit_price, opts) do
    result =
      Emakola.Repo.transaction(fn ->
        {customer_id, resolved_address} = resolve_customer(store_id, opts)
        shipping_address = Keyword.get(opts, :shipping_address) || resolved_address

        order =
          Emakola.Orders.Order
          |> Ash.Changeset.for_create(:create, %{
            store_id: store_id,
            customer_id: customer_id,
            notes: Keyword.get(opts, :notes),
            shipping_address: shipping_address,
            pay_link_id: Keyword.get(opts, :pay_link_id)
          })
          |> Ash.create!(authorize?: false)

        # One merchant-owned fulfillment group (supplier_id nil).
        fulfillment_ids = create_fulfillments(store_id, order.id, [], %{}, %{})

        line =
          Emakola.Orders.LineItem
          |> Ash.Changeset.for_create(:create_custom, %{
            order_id: order.id,
            store_id: store_id,
            product_title: title,
            unit_price: unit_price,
            quantity: 1,
            fulfillment_id: Map.get(fulfillment_ids, nil)
          })
          |> Ash.create!(authorize?: false)

        order
        |> Ash.Changeset.for_update(:update_totals, %{
          subtotal: line.line_total,
          delivery_fee: 0,
          discount_amount: 0,
          total: line.line_total
        })
        |> Ash.update!(authorize?: false)
      end)

    case result do
      {:ok, order} ->
        # Outside the transaction, exactly like checkout!/3: receipts to both
        # sides; a notification-subsystem error never fails the checkout.
        case Emakola.Notifications.Dispatcher.dispatch(order, :order_placed) do
          {:ok, _job} -> :ok
          {:error, reason} ->
            Logger.error("[checkout_custom] order_placed dispatch failed: #{inspect(reason)}",
              order_id: order.id, store_id: store_id)
        end

        {:ok, order}

      {:error, reason} ->
        {:error, reason}
    end
  end
```

**Check before coding:** `create_fulfillments/5` with empty items must still
create the merchant-owned (nil-supplier) group — read its implementation; if
it groups only over items, create the single fulfillment directly instead:

```elixir
        fulfillment =
          Emakola.Orders.Fulfillment
          |> Ash.Changeset.for_create(:create, %{order_id: order.id, store_id: store_id})
          |> Ash.create!(authorize?: false)

        # then: fulfillment_id: fulfillment.id
```

Similarly confirm the totals-update action name used by `run_checkout` (read
its tail — the existing code updates the order with subtotal/total after
line items; reuse the exact same action + argument names it uses).

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola/orders/checkout_custom_test.exs test/emakola/orders/`
Expected: PASS, existing checkout tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/orders/checkout_service.ex test/emakola/orders/checkout_custom_test.exs
git commit -m "feat(orders): checkout_custom! path for variant-less pay-link orders"
```

---

### Task 5: Single-use claim on webhook confirm

**Files:**
- Create: `lib/emakola/orders/pay_link_claim.ex`
- Modify: `lib/emakola/payments/workers/paystack_webhook_handler.ex` (~line 196, after `maybe_confirm_order`)
- Modify: `lib/emakola/payments/workers/hubtel_webhook_handler.ex` (same confirm site)
- Test: `test/emakola/orders/pay_link_claim_test.exs`

**Interfaces:**
- Produces: `Emakola.Orders.PayLinkClaim.claim_for_order(order_id)` → `:ok`.
  Loads the order; when it has a `pay_link_id` whose link is `type: :custom`,
  claims the link row `FOR UPDATE` inside a transaction and marks it `:paid`.
  If the link was ALREADY `:paid` (a second in-flight payment won the race),
  appends a refund-attention warning to the order's notes and logs an error.
  Always returns `:ok` — a claim problem must never fail webhook processing.
- Consumes: `PayLink :mark_paid` (Task 3), `Emakola.Orders.update_order_notes/2`.

- [ ] **Step 1: Write the failing tests**

Create `test/emakola/orders/pay_link_claim_test.exs`:

```elixir
defmodule Emakola.Orders.PayLinkClaimTest do
  use Emakola.DataCase, async: false

  alias Emakola.Orders.{PayLink, PayLinkClaim}

  defp custom_link_and_order(store) do
    link =
      PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id, type: :custom, title: "Deal", amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Ama", customer_phone: "0201234567", pay_link_id: link.id
      )

    {link, order}
  end

  test "first claim marks the link paid" do
    store = Emakola.Factory.create_store!()
    {link, order} = custom_link_and_order(store)

    assert :ok = PayLinkClaim.claim_for_order(order.id)

    assert Ash.get!(PayLink, link.id, authorize?: false, tenant: store.id).status == :paid
  end

  test "second claim flags the second order for refund attention" do
    store = Emakola.Factory.create_store!()
    {link, order1} = custom_link_and_order(store)

    {:ok, order2} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Kofi", customer_phone: "0209876543", pay_link_id: link.id
      )

    assert :ok = PayLinkClaim.claim_for_order(order1.id)
    assert :ok = PayLinkClaim.claim_for_order(order2.id)

    reloaded = Ash.get!(Emakola.Orders.Order, order2.id, authorize?: false, tenant: store.id)
    assert reloaded.notes =~ "already used"
  end

  test "orders without a pay link are a no-op" do
    store = Emakola.Factory.create_store!()

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    assert :ok = PayLinkClaim.claim_for_order(order.id)
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/orders/pay_link_claim_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 3: Implement the claim**

Create `lib/emakola/orders/pay_link_claim.ex`:

```elixir
defmodule Emakola.Orders.PayLinkClaim do
  @moduledoc """
  Consumes a single-use (custom) pay link when its order's payment confirms.

  Runs in a transaction with a `FOR UPDATE` lock on the pay_links row — the
  same claim pattern as merchant refunds — so exactly one confirming payment
  wins. A loser (second in-flight payment on a just-consumed link) gets its
  order flagged for merchant refund attention rather than silently
  double-selling. Never raises into the webhook worker.
  """

  import Ecto.Query, only: [from: 2]
  require Logger

  alias Emakola.Repo

  def claim_for_order(order_id) do
    order = Ash.get!(Emakola.Orders.Order, order_id, authorize?: false)

    case order.pay_link_id do
      nil -> :ok
      pay_link_id -> claim(order, pay_link_id)
    end
  rescue
    e ->
      Logger.error("[pay_link_claim] claim failed for order=#{order_id}: #{inspect(e)}")
      :ok
  end

  defp claim(order, pay_link_id) do
    Repo.transaction(fn ->
      row =
        Repo.one(
          from(pl in "pay_links",
            where: pl.id == type(^pay_link_id, :binary_id),
            lock: "FOR UPDATE",
            select: %{type: pl.type, status: pl.status}
          )
        )

      case row do
        %{type: "custom", status: "active"} ->
          link = Ash.get!(Emakola.Orders.PayLink, pay_link_id, authorize?: false)

          link
          |> Ash.Changeset.for_update(:mark_paid, %{})
          |> Ash.update!(authorize?: false)

        %{type: "custom", status: "paid"} ->
          Logger.error(
            "[pay_link_claim] link #{pay_link_id} already used — order #{order.id} needs a refund"
          )

          note = String.trim("#{order.notes || ""}\n⚠️ Pay link already used — refund this payment.")

          order
          |> Ash.Changeset.for_update(:update_notes, %{notes: note})
          |> Ash.update!(authorize?: false)

        _ ->
          # Catalog links are reusable; cancelled links keep their status.
          :ok
      end
    end)

    :ok
  end
end
```

- [ ] **Step 4: Hook both webhook handlers**

In `lib/emakola/payments/workers/paystack_webhook_handler.ex`, directly after
the `maybe_confirm_order(payment.order_id)` call (~line 196), add:

```elixir
        Emakola.Orders.PayLinkClaim.claim_for_order(payment.order_id)
```

(guard for nil: `payment.order_id && Emakola.Orders.PayLinkClaim.claim_for_order(payment.order_id)`).
Find the equivalent confirm site in `hubtel_webhook_handler.ex` (grep
`confirm`) and add the same line there.

- [ ] **Step 5: Run tests**

Run: `mix test test/emakola/orders/pay_link_claim_test.exs test/emakola/payments/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/orders/pay_link_claim.ex lib/emakola/payments/workers test/emakola/orders/pay_link_claim_test.exs
git commit -m "feat(payments): FOR UPDATE single-use claim for custom pay links on webhook confirm"
```

---

### Task 6: Buyer LiveView at /pay/:code

**Files:**
- Create: `lib/emakola_web/live/storefront/pay_link_live.ex`
- Modify: `lib/emakola_web/router.ex` (apex scope)
- Test: `test/emakola_web/live/storefront/pay_link_live_test.exs`

**Interfaces:**
- Consumes: `Emakola.Orders.get_pay_link_by_code/1` + `PayLink.usable?/1`
  (Task 3), `checkout!/3` (catalog) / `checkout_custom!/3` (custom, Task 4),
  `Emakola.Payments.OrderSettlement.prepare/2` + `Emakola.Payments.create_payment/2`
  + the configured gateway exactly as `checkout_live.ex:470-530` does.
- Produces: route `live "/pay/:code", Storefront.PayLinkLive` in the
  `host: @apex_hosts` scope, its own `live_session :pay_link` with
  `layout: {EmakolaWeb.Layouts, :storefront}`.
- Store lifecycle: renders the unavailable state unless the link's store is
  live (same check the storefront resolver uses — grep `live?` in
  `lib/emakola/stores/stores.ex` and call the same function).
- `opened_count` increments ONLY when `connected?(socket)` — dead renders
  and WhatsApp link-preview prefetches must not count.
- Rate-limit parity: before coding, check what rate limiting (if any) wraps
  `checkout_live`'s payment initiation (grep `RateLimit`/`Hammer` around the
  storefront checkout path) and give the `"pay"` handler the exact same
  posture — the spec requires parity with storefront checkout, not more.

- [ ] **Step 1: Write the failing tests**

Create `test/emakola_web/live/storefront/pay_link_live_test.exs`:

```elixir
defmodule EmakolaWeb.Storefront.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  setup :verify_on_exit!

  defp custom_link!(store, attrs \\ %{}) do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(%{store_id: store.id, type: :custom, title: "Kente dress", amount: 25_000}, attrs)
    )
    |> Ash.create!(authorize?: false)
  end

  test "renders a custom link with store name, title, amount and buyer form", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ store.name
    assert html =~ "Kente dress"
    assert html =~ "250"
    assert html =~ "phone"
  end

  test "connected mount increments opened_count exactly once", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    {:ok, _view, _html} = live(conn, "/pay/#{link.code}")

    reloaded = Ash.get!(Emakola.Orders.PayLink, link.id, authorize?: false, tenant: store.id)
    assert reloaded.opened_count == 1
  end

  test "expired link renders the inactive message, not a form", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{expires_at: DateTime.add(DateTime.utc_now(), -1, :day)})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")

    assert html =~ "no longer active"
    refute html =~ "phx-submit"
  end

  test "cancelled and consumed links render the inactive message", %{conn: conn} do
    store = Emakola.Factory.create_store!()

    for status <- [:cancelled, :paid] do
      link = custom_link!(store)

      link
      |> Ash.Changeset.for_update(if(status == :paid, do: :mark_paid, else: :cancel), %{})
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/pay/#{link.code}")
      assert html =~ "no longer active"
    end
  end

  test "unknown code 404s", %{conn: conn} do
    assert_raise EmakolaWeb.NotFoundError, fn -> live(conn, "/pay/zzzzzzzz") end
  end

  test "hidden address fields when collect_delivery is false", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store, %{collect_delivery: false})

    {:ok, _view, html} = live(conn, "/pay/#{link.code}")
    refute html =~ "shipping_address"
  end

  test "submitting the form creates the order and initiates payment", %{conn: conn} do
    store = Emakola.Factory.create_store!()
    link = custom_link!(store)

    expect(Emakola.Payments.GatewayMock, :initiate_payment, fn params ->
      assert params.amount == 25_000
      {:ok, %{reference: "PAY-test-ref", authorization_url: "https://pay.test/x"}}
    end)

    {:ok, view, _html} = live(conn, "/pay/#{link.code}")

    view
    |> form("#pay-link-form", %{
      "buyer" => %{"name" => "Ama Mensah", "phone" => "0201234567"}
    })
    |> render_submit()

    [order] =
      Emakola.Orders.Order
      |> Ash.Query.filter(pay_link_id == ^link.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert order.total == 25_000
  end
end
```

Adapt three things to the codebase's actual names before running: the 404
error module (check how storefront LiveViews raise not-found — grep
`NotFoundError` / `Ash.Error.Query.NotFound` handling in
`storefront/store_live.ex`), the gateway mock module name (grep
`GatewayMock` in `test/support/mocks.ex`), and how tests select the mock
gateway (grep `:payment_gateway` config in `config/test.exs`).

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/storefront/pay_link_live_test.exs`
Expected: FAIL — route/module undefined.

- [ ] **Step 3: Add the route**

In `lib/emakola_web/router.ex`, inside `scope "/", EmakolaWeb, host: @apex_hosts do`
(after the marketing routes, before the platform live_session):

```elixir
    # Pay links — express checkout shared into DMs. `pay` is a reserved
    # subdomain label, so no store can shadow this path.
    live_session :pay_link,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [{EmakolaWeb.Hooks.AssignDefaults, :default}] do
      live "/pay/:code", Storefront.PayLinkLive
    end
```

- [ ] **Step 4: Implement the LiveView**

Create `lib/emakola_web/live/storefront/pay_link_live.ex`. Structure (write
it in full; the money/gateway block is copied from `checkout_live.ex:470-530`
with pay-link params — reuse its `maybe_attach_split`/`split_mode` helpers by
copying the private functions or extracting them; prefer copying to keep the
change surgical):

```elixir
defmodule EmakolaWeb.Storefront.PayLinkLive do
  @moduledoc """
  Express checkout for a shared pay link (`/pay/:code`, apex host).

  Loads link + store by code (no ResolveStore — the link IS the tenant
  pointer). Renders: usable link → item + buyer form; anything else → a
  friendly inactive/sold-out state. Payment initiation mirrors
  `CheckoutLive`; the callback lands on the store's normal order
  confirmation page.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Orders.PayLink

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    case Emakola.Orders.get_pay_link_by_code(code, authorize?: false) do
      {:ok, link} ->
        store = Ash.get!(Emakola.Stores.Store, link.store_id, authorize?: false)

        if connected?(socket) do
          link
          |> Ash.Changeset.for_update(:increment_opened, %{})
          |> Ash.update(authorize?: false)
        end

        {:ok,
         socket
         |> assign(:link, link)
         |> assign(:store, store)
         |> assign(:state, page_state(link, store))
         |> assign(:variant, load_variant(link))
         |> assign(:quantity, 1)
         |> assign(:processing, false)
         |> assign(:form_errors, %{})}

      {:error, _} ->
        raise Ash.Error.Query.NotFound
    end
  end

  # :ok | :inactive | :store_unavailable | :sold_out
  defp page_state(link, store) do
    cond do
      not Emakola.Stores.live?(store) -> :store_unavailable
      PayLink.usable?(link) != :ok -> :inactive
      link.type == :catalog and out_of_stock?(link) -> :sold_out
      true -> :ok
    end
  end

  # ... load_variant/1, out_of_stock?/1 (catalog links only, read the
  # variant's stock the way ProductDetailLive does), render/1 with the four
  # states, handle_event("validate", ...), handle_event("set_quantity", ...)
  # (catalog only), handle_event("pay", %{"buyer" => buyer}, socket) →
  # checkout + initiate (below).
end
```

The `"pay"` handler, concretely:

```elixir
  @impl true
  def handle_event("pay", %{"buyer" => buyer}, socket) do
    %{link: link, store: store} = socket.assigns

    with :ok <- PayLink.usable?(link),
         {:ok, order} <- create_order(link, store, buyer, socket.assigns.quantity) do
      initiate_payment(socket, store, order)
    else
      {:error, reason} ->
        {:noreply, assign(socket, form_errors: %{base: friendly_error(reason)}, processing: false)}
    end
  end

  defp create_order(%PayLink{type: :custom} = link, store, buyer, _qty) do
    Emakola.Orders.CheckoutService.checkout_custom!(
      store.id,
      %{title: link.title, unit_price: link.amount},
      customer_name: buyer["name"],
      customer_phone: buyer["phone"],
      customer_email: presence(buyer["email"]),
      shipping_address: shipping_address(link, buyer),
      pay_link_id: link.id
    )
  end

  defp create_order(%PayLink{type: :catalog} = link, store, buyer, qty) do
    Emakola.Orders.CheckoutService.checkout!(
      store.id,
      [%{variant_id: link.variant_id, quantity: qty}],
      customer_email:
        presence(buyer["email"]) ||
          Emakola.Orders.CheckoutService.phone_placeholder_email(buyer["phone"]),
      customer_name: buyer["name"],
      customer_phone: buyer["phone"],
      shipping_address: shipping_address(link, buyer),
      pay_link_id: link.id
    )
  end
```

**Check before coding:** `checkout!/3` must pass `:pay_link_id` through to
the order create — Task 4 only added it to `checkout_custom!`. Add
`pay_link_id: Keyword.get(opts, :pay_link_id)` to the order-create map inside
`run_checkout` too (1 line, covered by the catalog-link test).

`initiate_payment/3` mirrors `checkout_live.ex:470-530`: `OrderSettlement.prepare` →
params (with `callback_url`/`return_url` pointing at
`"#{EmakolaWeb.Endpoint.url()}/s/#{store.slug}/orders/#{order.order_number}/confirmation"`) →
`gateway.initiate_payment` → `Emakola.Payments.create_payment` with
`split_mode` → redirect external to `authorization_url`.

Render: four states. The `:ok` state form MUST have `id="pay-link-form"`,
`phx-submit="pay"`, `phx-change="validate"`; name/phone required inputs,
optional email, address fieldset only when `link.collect_delivery`; catalog
links show product card + quantity select (`phx-change="set_quantity"`).
Inactive/sold-out/unavailable states show the store name and "this link is
no longer active — contact the seller" (or sold out) with NO form.

- [ ] **Step 5: Run tests**

Run: `mix test test/emakola_web/live/storefront/pay_link_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/storefront/pay_link_live.ex lib/emakola_web/router.ex lib/emakola/orders/checkout_service.ex test/emakola_web/live/storefront/pay_link_live_test.exs
git commit -m "feat(web): pay-link express checkout at /pay/:code"
```

---

### Task 7: Admin pay-links page

**Files:**
- Create: `lib/emakola_web/live/admin/pay_link_live/index.ex`
- Modify: `lib/emakola_web/router.ex` (`:app` live_session, after `/admin/coupons`)
- Modify: `lib/emakola_web/components/sidebar_components.ex` (nav entry near the Marketing group)
- Modify: `lib/emakola/orders/resources/pay_link.ex` + `orders.ex` (list action + paid aggregate)
- Test: `test/emakola_web/live/admin/pay_link_live_test.exs`

**Interfaces:**
- Consumes: `Emakola.Orders.create_pay_link/2`, `cancel_pay_link/2` (Task 3),
  `setup_authenticated_merchant(conn)` from `Emakola.LiveViewHelpers`.
- Produces: route `live "/admin/pay-links", Admin.PayLinkLive.Index`;
  PayLink read action `:list_for_admin` (sorted `inserted_at` desc) and an
  aggregate `paid_orders_count` (count of orders where `pay_link_id` matches —
  add `has_many :orders, Emakola.Orders.Order` with
  `destination_attribute :pay_link_id` and `count :paid_orders_count, :orders`).

- [ ] **Step 1: Write the failing tests**

Create `test/emakola_web/live/admin/pay_link_live_test.exs`:

```elixir
defmodule EmakolaWeb.Admin.PayLinkLiveTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  setup %{conn: conn} do
    {conn, user, store} = setup_authenticated_merchant(conn)
    %{conn: conn, user: user, store: store}
  end

  test "lists links with funnel columns and empty state", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Pay Links"

    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id, type: :custom, title: "Deal", amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    {:ok, _view, html} = live(conn, "/admin/pay-links")
    assert html =~ "Deal"
    assert html =~ "250"
  end

  test "creates a custom link from the modal and shows the share URL", %{conn: conn} do
    {:ok, view, _} = live(conn, "/admin/pay-links")

    view |> element("button", "New pay link") |> render_click()

    html =
      view
      |> form("#pay-link-create-form", %{
        "pay_link" => %{"type" => "custom", "title" => "Kente", "amount_ghs" => "250"}
      })
      |> render_submit()

    assert html =~ "/pay/"
    assert html =~ "wa.me"
  end

  test "cancels an active link", %{conn: conn, store: store} do
    link =
      Emakola.Orders.PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id, type: :custom, title: "Deal", amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, view, _} = live(conn, "/admin/pay-links")
    view |> element("#cancel-link-#{link.id}") |> render_click()

    assert Ash.get!(Emakola.Orders.PayLink, link.id,
             authorize?: false, tenant: store.id).status == :cancelled
  end

  test "another store's merchant cannot see the link", %{conn: _conn, store: store} do
    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id, type: :custom, title: "Secret", amount: 25_000
    })
    |> Ash.create!(authorize?: false)

    other_conn = Phoenix.ConnTest.build_conn()
    {other_conn, _user, _other_store} = setup_authenticated_merchant(other_conn)

    {:ok, _view, html} = live(other_conn, "/admin/pay-links")
    refute html =~ "Secret"
  end
end
```

(Adapt `setup_authenticated_merchant/1`'s exact return shape from
`test/support/live_view_helpers.ex:56` before running. The `amount_ghs`
field converts GH₵ input to pesewas in the form component — see Step 3.)

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — route undefined.

- [ ] **Step 3: Implement**

Route (in the `:app` live_session after `/admin/coupons`):

```elixir
      live "/admin/pay-links", Admin.PayLinkLive.Index
```

Sidebar: add next to the Marketing links in `sidebar_components.ex`, matching
the exact markup of the neighboring entries (copy the `/admin/coupons` entry,
label "Pay Links", icon in the set the file already uses).

Resource additions in `pay_link.ex`:

```elixir
  relationships do
    has_many :orders, Emakola.Orders.Order do
      destination_attribute(:pay_link_id)
    end
  end

  aggregates do
    count(:paid_orders_count, :orders)
  end

  # in actions:
    read :list_for_admin do
      prepare(build(sort: [inserted_at: :desc], load: [:paid_orders_count]))
    end
```

and in `orders.ex`: `define(:list_pay_links_for_admin, action: :list_for_admin)`.

LiveView `Admin.PayLinkLive.Index`, following the Makola Admin design
language (stat tiles row: active links, opened total, paid total; rounded-2xl
card table; status pills; rich empty state). Core pieces:

- `mount`: load links via
  `Emakola.Orders.list_pay_links_for_admin!(actor: current_user, tenant: store.id)`;
  assign `show_create: false`, `created_link: nil`, form changeset.
- `handle_event("open_create"/"close_create", ...)` toggle the modal.
- `handle_event("create", %{"pay_link" => params}, socket)`:
  convert `amount_ghs` (string, GH₵) → pesewas with
  `trunc(Decimal.to_float(Decimal.new(amount_ghs)) * 100)` — or, better,
  parse with `Decimal.mult(Decimal.new(amount_ghs), 100) |> Decimal.to_integer()`
  and rescue parse errors into a form error; call `Emakola.Orders.create_pay_link`
  (actor + tenant); on success assign `created_link` and render the
  share block:

```elixir
  defp share_url(link), do: "#{EmakolaWeb.Endpoint.url()}/pay/#{link.code}"

  defp whatsapp_share(link, store) do
    text =
      "#{store.name}: #{item_label(link)} — #{Emakola.Money.format(amount_for(link))}. Pay securely: #{share_url(link)}"

    "https://wa.me/?text=#{URI.encode_www_form(text)}"
  end
```

  (Check the money formatter's real module — grep `def format` in
  `lib/emakola` for the pesewas→"GH₵X.XX" helper the admin already uses,
  and use that.)
- `handle_event("cancel_link", %{"id" => id}, socket)`: fetch + `cancel_pay_link`
  with actor/tenant, refresh list.
- Product picker for catalog links: a `<select>` of the store's active
  variants (load via the catalog list action the product admin uses —
  grep `list_products` usage in `admin/product_live/index.ex`) — v1 keeps it
  to a simple select, no search.

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/pay_link_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web lib/emakola/orders test/emakola_web/live/admin/pay_link_live_test.exs
git commit -m "feat(web): admin pay-links page with create modal, funnel columns, WhatsApp share"
```

---

### Task 8: JSON:API exposure

**Files:**
- Modify: `lib/emakola/orders/resources/pay_link.ex` (json_api block)
- Modify: `lib/emakola_web/api_router.ex` (routes — mirror how orders are declared; check the file's structure first)
- Test: `test/emakola_web/controllers/api/pay_link_endpoints_test.exs`

**Interfaces:**
- Produces: `GET /api/v1/pay_links`, `POST /api/v1/pay_links`,
  `PATCH /api/v1/pay_links/:id/cancel` under the existing merchant bearer
  auth + `X-Store-ID` tenancy.
- Consumes: the auth/tenant plumbing `order_endpoints_test.exs` already
  exercises — copy its setup block verbatim.

- [ ] **Step 1: Write the failing tests**

Create `test/emakola_web/controllers/api/pay_link_endpoints_test.exs` with
the same auth setup as `test/emakola_web/controllers/api/order_endpoints_test.exs`
(copy its `setup`), then:

```elixir
  test "POST /api/v1/pay_links creates a custom link", %{conn: conn, store: store} do
    conn =
      post(conn, "/api/v1/pay_links", %{
        "data" => %{
          "type" => "pay_link",
          "attributes" => %{"type" => "custom", "title" => "Deal", "amount" => 25_000}
        }
      })

    assert %{"data" => %{"attributes" => attrs}} = json_response(conn, 201)
    assert attrs["code"] =~ ~r/^[a-z2-7]{8}$/
    assert attrs["status"] == "active"
  end

  test "GET /api/v1/pay_links scopes to X-Store-ID", %{conn: conn} do
    assert %{"data" => _} = conn |> get("/api/v1/pay_links") |> json_response(200)
  end

  test "requests without X-Store-ID are rejected", %{conn: conn} do
    conn = delete_req_header(conn, "x-store-id")
    assert json_response(get(conn, "/api/v1/pay_links"), 400)
  end
```

(Mirror the exact request/assert idioms of `order_endpoints_test.exs` —
including how it builds the bearer token and store header, and the actual
error status for a missing header.)

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — no route.

- [ ] **Step 3: Implement**

In `pay_link.ex` add (mirroring `order.ex:169`'s json_api block shape):

```elixir
  json_api do
    type "pay_link"

    routes do
      base("/pay_links")
      index(:list_for_admin)
      get(:read)
      post(:create)
      patch(:cancel, route: "/:id/cancel")
    end
  end
```

and add `extensions: [AshJsonApi.Resource]` to the `use Ash.Resource` options
(match how `order.ex` declares it). Check `lib/emakola_web/api_router.ex` —
if resources are auto-discovered from the domain, nothing to add; if listed
explicitly, add PayLink the same way orders appear.

- [ ] **Step 4: Run tests + regenerate the OpenAPI contract if CI checks it**

Run: `mix test test/emakola_web/controllers/api/`
Expected: PASS. If `docs/API.md`/spec snapshots exist in CI, run
`mix openapi.spec.json --spec EmakolaWeb.ApiRouter` and commit the artifact.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/orders/resources/pay_link.ex lib/emakola_web test/emakola_web/controllers/api/pay_link_endpoints_test.exs
git commit -m "feat(orders): expose pay_links via merchant JSON:API"
```

---

### Task 9: Guard test — variant-less orders render everywhere

**Files:**
- Test: `test/emakola/orders/custom_order_rendering_test.exs`

**Interfaces:**
- Consumes: `checkout_custom!/3` (Task 4); admin order show route
  (`/admin/orders/:id`); order email builders in
  `lib/emakola/notifications/emails/order_email.ex`.

The loud-failure insurance for nullable variants: an admin viewing a custom
order, and the order email builder, must render from snapshot fields without
crashing on a nil variant.

- [ ] **Step 1: Write the failing/passing tests**

```elixir
defmodule Emakola.Orders.CustomOrderRenderingTest do
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  use Emakola.LiveViewHelpers

  test "admin order show renders a custom order from snapshots" do
    conn = Phoenix.ConnTest.build_conn()
    {conn, _user, store} = setup_authenticated_merchant(conn)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Custom kente dress", unit_price: 25_000},
        customer_name: "Ama", customer_phone: "0201234567"
      )

    {:ok, _view, html} = live(conn, "/admin/orders/#{order.id}")
    assert html =~ "Custom kente dress"
    assert html =~ "250.00"
  end

  test "order email builds for a custom order without raising" do
    store = Emakola.Factory.create_store!()

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Custom kente dress", unit_price: 25_000},
        customer_name: "Ama", customer_phone: "0201234567"
      )

    # Grep order_email.ex for its public build function and call it here —
    # the assertion is simply that it returns a %Swoosh.Email{} and the
    # body mentions the snapshot title.
    email = Emakola.Notifications.Emails.OrderEmail.order_confirmation(order)
    assert email.html_body =~ "Custom kente dress"
  end
end
```

(Adjust the email function name to the module's actual public API before
running; if admin order show queries `line_item.variant` anywhere it will
crash here — fix the render to use snapshot fields with a nil guard, which
is exactly what this test exists to force.)

- [ ] **Step 2: Run, fix any nil-variant crashes surfaced, re-run to green**

Run: `mix test test/emakola/orders/custom_order_rendering_test.exs`

- [ ] **Step 3: Commit**

```bash
git add test/emakola/orders/custom_order_rendering_test.exs lib/
git commit -m "test(orders): guard variant-less orders render in admin and email"
```

---

### Task 10: Full verification + PR

**Files:** none new.

- [ ] **Step 1: Full quality gate**

Run, in order, and read actual output (never trust piped exit codes):

```bash
mix format --check-formatted
mix credo --strict
mix test
```

Expected: formatter clean, credo clean, test output `Result:` line shows 0 failures.

- [ ] **Step 2: Rebase onto main** (PR #362's specs land there)

```bash
git fetch origin main && git rebase origin/main
mix test   # re-verify after rebase
```

- [ ] **Step 3: Update TODO.md**

In the PLANNED section's Pay Links entry, append `→ implemented (TC-1 PR)` on
the spec line. Commit as `docs: mark TC-1 pay links implemented`.

- [ ] **Step 4: Push + PR**

```bash
git push -u origin HEAD
gh pr create --base main --title "feat(orders): TC-1 pay links — DM express checkout" --body "..."
```

PR body: summarize buyer flow, single-use claim, admin page, API; link the
spec file; note the drive-by flake fix (Task 1); end with the standard
Claude Code footer.
