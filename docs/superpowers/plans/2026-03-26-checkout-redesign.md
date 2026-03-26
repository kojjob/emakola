# Checkout Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the checkout experience with accordion steps, product images, coupon system, rich MoMo waiting state, and celebration confirmation page.

**Architecture:** Accordion-based 3-step checkout (Contact -> Payment -> Review) with collapsible sections. New Coupon Ash resource in Orders domain with merchant admin CRUD. Cart items gain `image_url` field from product images. Order resource gains `delivery_fee`, `discount_amount`, and `coupon_id` fields.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x, TailwindCSS, PostgreSQL, ETS (cart)

**Spec:** `docs/superpowers/specs/2026-03-26-checkout-redesign-design.md`

## ERRATA (from plan review)

Agents MUST apply these corrections over the plan examples:

1. **Factory helper:** Use `create_store!()` (bang), not `create_store()`. All tests must `import Emakola.Factory`.
2. **Store module:** Use `Emakola.Accounts.Store`, NOT `Emakola.Stores.Store` (in coupon resource relationship).
3. **variant_label:** Use `variant_label(variant, socket.assigns.option_types)`, NOT `socket.assigns.product`.
4. **Admin test auth:** No `setup :register_and_log_in_user`. Use local `create_authenticated_merchant!` + `authenticate_conn` pattern from existing admin tests (e.g., `test/emakola_web/live/admin/`).
5. **require Ash.Query:** Must be at MODULE level in checkout_service.ex, not inside function body.
6. **increment_usage race guard:** The `:increment_usage` action needs a filter `filter expr(is_nil(max_uses) or uses_count < max_uses)` to prevent exceeding max_uses under concurrency.
7. **Task 6 is split:** Into 6a (coupon assigns + handlers), 6b (step order reversal), 6c (render rewrite), 6d (coupon UI wiring).

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `lib/emakola/orders/resources/coupon.ex` | Ash resource for coupons (CRUD, identity, multi-tenant) |
| `lib/emakola_web/live/admin/coupon_live.ex` | Merchant admin coupon management LiveView |
| `priv/repo/migrations/*_add_coupons_and_order_fields.exs` | Single migration: coupons table + order fields |
| `test/emakola/orders/coupon_test.exs` | Coupon resource unit tests |
| `test/emakola/orders/checkout_service_coupon_test.exs` | Coupon validation + discount calculation tests |
| `test/emakola_web/live/admin/coupon_live_test.exs` | Admin coupon CRUD LiveView tests |

### Modified Files
| File | Changes |
|------|---------|
| `lib/emakola/orders/orders.ex:8-23` | Register Coupon resource |
| `lib/emakola/orders/resources/order.ex:48-58,84-94` | Add `delivery_fee`, `discount_amount` attrs + `coupon` relationship |
| `lib/emakola/orders/checkout_service.ex:85-155` | Coupon validation, discount calc, re-validate in transaction |
| `lib/emakola_web/live/storefront/product_detail_live.ex:128-137` | Include `image_url` in cart item map |
| `lib/emakola_web/live/storefront/cart_live.ex:100-348` | Product images, mobile order summary |
| `lib/emakola_web/live/storefront/checkout_live.ex:1-830` | Full accordion redesign + coupon UI + MoMo state |
| `lib/emakola_web/live/storefront/order_confirmation_live.ex:1-250` | Celebration redesign |
| `lib/emakola_web/router.ex:121-122` | Add `/admin/coupons` route |

---

## Task Dependency Graph

```
Task 1 (Migration + Coupon Resource)
  |
  ├── Task 2 (Order Resource Fields) ── depends on Task 1
  |     |
  |     └── Task 3 (CheckoutService Coupon Logic) ── depends on Task 2
  |           |
  |           └── Task 6 (Checkout LiveView Redesign) ── depends on Task 3
  |                 |
  |                 └── Task 8 (MoMo Waiting State) ── depends on Task 6
  |
  └── Task 5 (Admin Coupon UI) ── depends on Task 1

Task 4 (Cart Images) ── independent
  |
  └── Task 6 (Checkout LiveView) ── depends on Task 4 + Task 3

Task 7 (Cart Page Redesign) ── depends on Task 4

Task 9 (Confirmation Page) ── depends on Task 6
```

**Parallel tracks:**
- Track A: Tasks 1 → 2 → 3 → 5 (coupon backend + admin)
- Track B: Task 4 → 7 (cart images)
- Track C: Task 6 → 8 → 9 (checkout + MoMo + confirmation) — depends on A + B

---

## Task 1: Coupon Ash Resource + Migration

**Files:**
- Create: `lib/emakola/orders/resources/coupon.ex`
- Create: `priv/repo/migrations/*_add_coupons_and_order_fields.exs`
- Modify: `lib/emakola/orders/orders.ex:8-23`
- Create: `test/emakola/orders/coupon_test.exs`

- [ ] **Step 1: Write failing test for coupon creation**

```elixir
# test/emakola/orders/coupon_test.exs
defmodule Emakola.Orders.CouponTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.Coupon

  setup do
    store = create_store()
    %{store: store}
  end

  describe "create" do
    test "creates a coupon with valid attributes", %{store: store} do
      assert {:ok, coupon} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "SAVE10",
                 discount_type: :percentage,
                 discount_value: 1000,
                 active: true
               })
               |> Ash.create()

      assert coupon.code == "SAVE10"
      assert coupon.discount_type == :percentage
      assert coupon.discount_value == 1000
      assert coupon.uses_count == 0
      assert coupon.active == true
    end

    test "enforces unique code per store", %{store: store} do
      attrs = %{store_id: store.id, code: "UNIQUE1", discount_type: :fixed_amount, discount_value: 500}

      {:ok, _} = Coupon |> Ash.Changeset.for_create(:create, attrs) |> Ash.create()
      assert {:error, _} = Coupon |> Ash.Changeset.for_create(:create, attrs) |> Ash.create()
    end

    test "validates percentage <= 10000 (100%)", %{store: store} do
      assert {:error, _} =
               Coupon
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 code: "TOOMUCH",
                 discount_type: :percentage,
                 discount_value: 15000
               })
               |> Ash.create()
    end
  end

  describe "find_by_code" do
    test "finds coupon by store and code", %{store: store} do
      {:ok, created} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "FIND_ME",
          discount_type: :fixed_amount,
          discount_value: 2000
        })
        |> Ash.create()

      assert {:ok, [found]} =
               Coupon
               |> Ash.Query.filter(store_id == ^store.id and code == "FIND_ME")
               |> Ash.read()

      assert found.id == created.id
    end
  end

  describe "increment_usage" do
    test "atomically increments uses_count", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "COUNT1",
          discount_type: :percentage,
          discount_value: 500,
          max_uses: 10
        })
        |> Ash.create()

      assert coupon.uses_count == 0

      {:ok, updated} =
        coupon
        |> Ash.Changeset.for_update(:increment_usage, %{})
        |> Ash.update()

      assert updated.uses_count == 1
    end
  end

  describe "deactivate" do
    test "sets active to false", %{store: store} do
      {:ok, coupon} =
        Coupon
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          code: "DEACT1",
          discount_type: :fixed_amount,
          discount_value: 1000
        })
        |> Ash.create()

      {:ok, deactivated} =
        coupon
        |> Ash.Changeset.for_update(:deactivate, %{})
        |> Ash.update()

      assert deactivated.active == false
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/orders/coupon_test.exs`
Expected: Compilation error — `Emakola.Orders.Coupon` not found

- [ ] **Step 3: Create the migration**

```bash
mix ecto.gen.migration add_coupons_and_order_fields
```

Then write the migration:

```elixir
defmodule Emakola.Repo.Migrations.AddCouponsAndOrderFields do
  use Ecto.Migration

  def change do
    create table(:coupons, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :description, :string
      add :discount_type, :string, null: false
      add :discount_value, :integer, default: 0
      add :max_discount_amount, :integer
      add :minimum_order_amount, :integer
      add :max_uses, :integer
      add :uses_count, :integer, default: 0, null: false
      add :starts_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:coupons, [:store_id, :code])
    create index(:coupons, [:store_id])

    alter table(:orders) do
      add :coupon_id, references(:coupons, type: :uuid, on_delete: :nilify_all)
      add :delivery_fee, :integer, default: 0
      add :discount_amount, :integer, default: 0
    end
  end
end
```

- [ ] **Step 4: Create the Coupon Ash resource**

```elixir
# lib/emakola/orders/resources/coupon.ex
defmodule Emakola.Orders.Coupon do
  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("coupons")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :code, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 50)
    end

    attribute :description, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :discount_type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:percentage, :fixed_amount, :free_shipping])
    end

    attribute :discount_value, :integer do
      default(0)
      public?(true)
    end

    attribute :max_discount_amount, :integer do
      public?(true)
    end

    attribute :minimum_order_amount, :integer do
      public?(true)
    end

    attribute :max_uses, :integer do
      public?(true)
    end

    attribute :uses_count, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :starts_at, :utc_datetime do
      public?(true)
    end

    attribute :expires_at, :utc_datetime do
      public?(true)
    end

    attribute :active, :boolean do
      default(true)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity :unique_code_per_store, [:store_id, :code]
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id, :code, :description, :discount_type, :discount_value,
        :max_discount_amount, :minimum_order_amount, :max_uses,
        :starts_at, :expires_at, :active
      ])

      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :code) do
          nil -> changeset
          code -> Ash.Changeset.change_attribute(changeset, :code, String.upcase(code))
        end
      end

      validate fn changeset, _context ->
        type = Ash.Changeset.get_attribute(changeset, :discount_type)
        value = Ash.Changeset.get_attribute(changeset, :discount_value)

        if type == :percentage and is_integer(value) and value > 10_000 do
          {:error, field: :discount_value, message: "percentage cannot exceed 100% (10000 basis points)"}
        else
          :ok
        end
      end
    end

    update :update do
      accept([
        :code, :description, :discount_type, :discount_value,
        :max_discount_amount, :minimum_order_amount, :max_uses,
        :starts_at, :expires_at, :active
      ])
    end

    update :deactivate do
      change set_attribute(:active, false)
    end

    update :increment_usage do
      change atomic_update(:uses_count, expr(uses_count + 1))
    end

    read :list_by_store do
      argument :store_id, :uuid, allow_nil?: false
      filter expr(store_id == ^arg(:store_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :find_by_code do
      argument :store_id, :uuid, allow_nil?: false
      argument :code, :string, allow_nil?: false

      filter expr(store_id == ^arg(:store_id) and code == ^arg(:code))

      prepare fn query, _context ->
        code = Ash.Query.get_argument(query, :code)
        if code, do: Ash.Query.set_argument(query, :code, String.upcase(code)), else: query
      end
    end
  end

  relationships do
    belongs_to :store, Emakola.Stores.Store do
      attribute_writable?(true)
      define_attribute?(false)
    end
  end
end
```

- [ ] **Step 5: Register Coupon in Orders domain**

In `lib/emakola/orders/orders.ex`, add to resources:

```elixir
resource Emakola.Orders.Coupon do
  define :create_coupon, action: :create
  define :list_coupons_by_store, action: :list_by_store, args: [:store_id]
  define :find_coupon_by_code, action: :find_by_code, args: [:store_id, :code]
  define :deactivate_coupon, action: :deactivate
  define :increment_coupon_usage, action: :increment_usage
end
```

- [ ] **Step 6: Run migration and tests**

Run: `mix ecto.migrate && mix test test/emakola/orders/coupon_test.exs`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add -f lib/emakola/orders/resources/coupon.ex lib/emakola/orders/orders.ex priv/repo/migrations/*_add_coupons_and_order_fields.exs test/emakola/orders/coupon_test.exs
git commit -m "feat(orders): add Coupon resource with CRUD, validation, and atomic usage increment"
```

---

## Task 2: Order Resource -- Add delivery_fee, discount_amount, coupon_id

**Files:**
- Modify: `lib/emakola/orders/resources/order.ex:48-94`

- [ ] **Step 1: Add new attributes and relationship to Order resource**

In `lib/emakola/orders/resources/order.ex`, add after the `total` attribute (around line 58):

```elixir
attribute :delivery_fee, :integer do
  default(0)
  public?(true)
end

attribute :discount_amount, :integer do
  default(0)
  public?(true)
end
```

Add in the relationships block (after `has_many :line_items`):

```elixir
belongs_to :coupon, Emakola.Orders.Coupon do
  attribute_writable?(true)
  public?(true)
end
```

Update the `:create` action's `accept` list to include `:delivery_fee`, `:discount_amount`, `:coupon_id`.

- [ ] **Step 2: Run existing tests to verify nothing breaks**

Run: `mix test test/emakola/orders/ --trace`
Expected: All existing order tests pass (new fields have defaults)

- [ ] **Step 3: Commit**

```bash
git add -f lib/emakola/orders/resources/order.ex
git commit -m "feat(orders): add delivery_fee, discount_amount, coupon_id to Order resource"
```

---

## Task 3: CheckoutService -- Coupon Validation + Discount Calculation

**Files:**
- Modify: `lib/emakola/orders/checkout_service.ex:85-155`
- Create: `test/emakola/orders/checkout_service_coupon_test.exs`

- [ ] **Step 1: Write failing tests for coupon validation**

```elixir
# test/emakola/orders/checkout_service_coupon_test.exs
defmodule Emakola.Orders.CheckoutServiceCouponTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.CheckoutService
  alias Emakola.Orders.Coupon

  setup do
    store = create_store()
    %{store: store}
  end

  describe "validate_coupon/3" do
    test "validates an active coupon", %{store: store} do
      {:ok, coupon} = create_coupon(store, %{code: "VALID10", discount_type: :percentage, discount_value: 1000})
      assert {:ok, ^coupon} = CheckoutService.validate_coupon(store.id, "valid10", 50_000)
    end

    test "rejects inactive coupon", %{store: store} do
      {:ok, _} = create_coupon(store, %{code: "INACTIVE", discount_type: :percentage, discount_value: 500, active: false})
      assert {:error, :coupon_inactive} = CheckoutService.validate_coupon(store.id, "INACTIVE", 50_000)
    end

    test "rejects expired coupon", %{store: store} do
      {:ok, _} = create_coupon(store, %{
        code: "EXPIRED", discount_type: :fixed_amount, discount_value: 1000,
        expires_at: DateTime.add(DateTime.utc_now(), -3600)
      })
      assert {:error, :coupon_expired} = CheckoutService.validate_coupon(store.id, "EXPIRED", 50_000)
    end

    test "rejects coupon not yet started", %{store: store} do
      {:ok, _} = create_coupon(store, %{
        code: "FUTURE", discount_type: :percentage, discount_value: 500,
        starts_at: DateTime.add(DateTime.utc_now(), 86400)
      })
      assert {:error, :coupon_not_started} = CheckoutService.validate_coupon(store.id, "FUTURE", 50_000)
    end

    test "rejects coupon with max uses exceeded", %{store: store} do
      {:ok, coupon} = create_coupon(store, %{code: "MAXED", discount_type: :percentage, discount_value: 500, max_uses: 1})
      coupon |> Ash.Changeset.for_update(:increment_usage, %{}) |> Ash.update!()
      assert {:error, :coupon_max_uses_reached} = CheckoutService.validate_coupon(store.id, "MAXED", 50_000)
    end

    test "rejects coupon when subtotal below minimum", %{store: store} do
      {:ok, _} = create_coupon(store, %{code: "MINORDER", discount_type: :percentage, discount_value: 500, minimum_order_amount: 100_000})
      assert {:error, :coupon_minimum_not_met} = CheckoutService.validate_coupon(store.id, "MINORDER", 50_000)
    end

    test "rejects coupon from wrong store", %{store: store} do
      other_store = create_store()
      {:ok, _} = create_coupon(other_store, %{code: "WRONG", discount_type: :percentage, discount_value: 500})
      assert {:error, :coupon_not_found} = CheckoutService.validate_coupon(store.id, "WRONG", 50_000)
    end
  end

  describe "calculate_discount/3" do
    test "calculates percentage discount" do
      coupon = %{discount_type: :percentage, discount_value: 1000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 5_000
    end

    test "caps percentage discount with max_discount_amount" do
      coupon = %{discount_type: :percentage, discount_value: 5000, max_discount_amount: 10_000}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 10_000
    end

    test "calculates fixed amount discount" do
      coupon = %{discount_type: :fixed_amount, discount_value: 3000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 3000
    end

    test "caps fixed amount at subtotal" do
      coupon = %{discount_type: :fixed_amount, discount_value: 100_000, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 1500) == 50_000
    end

    test "free shipping returns delivery fee" do
      coupon = %{discount_type: :free_shipping, discount_value: 0, max_discount_amount: nil}
      assert CheckoutService.calculate_discount(coupon, 50_000, 2500) == 2500
    end
  end

  defp create_coupon(store, attrs) do
    Coupon
    |> Ash.Changeset.for_create(:create, Map.merge(%{store_id: store.id, active: true}, attrs))
    |> Ash.create()
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/orders/checkout_service_coupon_test.exs`
Expected: FAIL — `validate_coupon/3` and `calculate_discount/3` not defined

- [ ] **Step 3: Implement validate_coupon and calculate_discount in CheckoutService**

Add to `lib/emakola/orders/checkout_service.ex`:

```elixir
@doc "Validates a coupon code for a given store and subtotal."
def validate_coupon(store_id, code, subtotal) do
  require Ash.Query

  case Emakola.Orders.Coupon
       |> Ash.Query.filter(store_id == ^store_id and code == ^String.upcase(code))
       |> Ash.read() do
    {:ok, [coupon]} -> check_coupon_validity(coupon, subtotal)
    {:ok, []} -> {:error, :coupon_not_found}
    _ -> {:error, :coupon_not_found}
  end
end

defp check_coupon_validity(coupon, subtotal) do
  now = DateTime.utc_now()

  cond do
    not coupon.active ->
      {:error, :coupon_inactive}
    coupon.expires_at && DateTime.compare(now, coupon.expires_at) == :gt ->
      {:error, :coupon_expired}
    coupon.starts_at && DateTime.compare(now, coupon.starts_at) == :lt ->
      {:error, :coupon_not_started}
    coupon.max_uses && coupon.uses_count >= coupon.max_uses ->
      {:error, :coupon_max_uses_reached}
    coupon.minimum_order_amount && subtotal < coupon.minimum_order_amount ->
      {:error, :coupon_minimum_not_met}
    true ->
      {:ok, coupon}
  end
end

@doc "Calculates discount amount in pesewas."
def calculate_discount(%{discount_type: :percentage} = coupon, subtotal, _delivery_fee) do
  raw = div(subtotal * coupon.discount_value, 10_000)
  if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw
end

def calculate_discount(%{discount_type: :fixed_amount} = coupon, subtotal, _delivery_fee) do
  min(coupon.discount_value, subtotal)
end

def calculate_discount(%{discount_type: :free_shipping}, _subtotal, delivery_fee) do
  delivery_fee
end
```

- [ ] **Step 4: Update run_checkout/4 to accept and apply coupon**

Modify `run_checkout` (lines 85-155) to accept `coupon_id` in opts. Inside the transaction:
1. If `coupon_id` is provided, re-validate the coupon
2. Calculate discount and adjust total
3. Increment coupon usage atomically
4. Store `coupon_id`, `delivery_fee`, and `discount_amount` on the order

- [ ] **Step 5: Run tests**

Run: `mix test test/emakola/orders/checkout_service_coupon_test.exs`
Expected: All pass

- [ ] **Step 6: Run full test suite**

Run: `mix test`
Expected: All existing tests still pass

- [ ] **Step 7: Commit**

```bash
git add -f lib/emakola/orders/checkout_service.ex test/emakola/orders/checkout_service_coupon_test.exs
git commit -m "feat(orders): add coupon validation and discount calculation to CheckoutService"
```

---

## Task 4: Cart Images -- Add image_url to Cart Items

**Files:**
- Modify: `lib/emakola_web/live/storefront/product_detail_live.ex:128-137`
- Modify: `lib/emakola/cart/cart_store.ex` (doc update only)

- [ ] **Step 1: Modify add_to_cart in ProductDetailLive**

In `lib/emakola_web/live/storefront/product_detail_live.ex`, find the cart item map construction (lines 128-137). Add `image_url` field:

```elixir
# Find the primary image for this product
primary_image =
  (socket.assigns.product.images || [])
  |> Enum.sort_by(& &1.position)
  |> List.first()

image_url = if primary_image, do: primary_image.thumbnail_url || primary_image.url, else: nil

item = %{
  variant_id: variant.id,
  quantity: 1,
  product_title: socket.assigns.product.title,
  variant_info: variant_label(variant, socket.assigns.product),
  unit_price: variant.price,
  sku: variant.sku || "",
  image_url: image_url
}
```

- [ ] **Step 2: Verify compilation and existing tests**

Run: `mix compile && mix test test/emakola_web/live/storefront/ --trace`
Expected: All pass (image_url is additive, doesn't break anything)

- [ ] **Step 3: Commit**

```bash
git add -f lib/emakola_web/live/storefront/product_detail_live.ex
git commit -m "feat(cart): include product image_url when adding items to cart"
```

---

## Task 5: Merchant Admin Coupon UI

**Files:**
- Create: `lib/emakola_web/live/admin/coupon_live.ex`
- Modify: `lib/emakola_web/router.ex:121-122`
- Create: `test/emakola_web/live/admin/coupon_live_test.exs`

- [ ] **Step 1: Add route**

In `lib/emakola_web/router.ex`, in the admin scope (around line 122, near `/admin/discounts`), add:

```elixir
live "/admin/coupons", Admin.CouponLive
```

- [ ] **Step 2: Write failing test**

```elixir
# test/emakola_web/live/admin/coupon_live_test.exs
defmodule EmakolaWeb.Admin.CouponLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "coupon list" do
    test "renders empty state", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/admin/coupons")
      assert has_element?(view, "[data-test='no-coupons']")
    end

    test "lists existing coupons", %{conn: conn, store: store} do
      create_coupon(store, %{code: "SAVE10", discount_type: :percentage, discount_value: 1000})
      {:ok, view, _html} = live(conn, "/admin/coupons")
      assert has_element?(view, "[data-test='coupon-code']", "SAVE10")
    end
  end

  describe "create coupon" do
    test "creates a new coupon", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/admin/coupons")

      view
      |> element("[data-test='new-coupon-btn']")
      |> render_click()

      view
      |> form("[data-test='coupon-form']", %{
        "coupon" => %{
          "code" => "NEWCODE",
          "discount_type" => "percentage",
          "discount_value" => "10"
        }
      })
      |> render_submit()

      assert has_element?(view, "[data-test='coupon-code']", "NEWCODE")
    end
  end

  describe "deactivate coupon" do
    test "toggles coupon active status", %{conn: conn, store: store} do
      create_coupon(store, %{code: "TOGGLE1", discount_type: :fixed_amount, discount_value: 5000})
      {:ok, view, _html} = live(conn, "/admin/coupons")

      view
      |> element("[data-test='toggle-active-TOGGLE1']")
      |> render_click()

      assert has_element?(view, "[data-test='status-TOGGLE1']", "Inactive")
    end
  end
end
```

- [ ] **Step 3: Implement CouponLive**

Create `lib/emakola_web/live/admin/coupon_live.ex` with:
- List view with table (Code, Type, Value, Uses/Max, Status, Actions)
- Create/edit form modal (code, type, value, min order, max uses, dates, active)
- Toggle active/inactive
- Search by code
- Percentage input as whole number (10 = 10%), convert to basis points (1000) on save
- Fixed amount input as cedis, convert to pesewas on save
- Conditionally show discount_value field (hide for free_shipping)

Full LiveView implementation with Tailwind styling matching admin dashboard patterns.

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/admin/coupon_live_test.exs`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -f lib/emakola_web/live/admin/coupon_live.ex lib/emakola_web/router.ex test/emakola_web/live/admin/coupon_live_test.exs
git commit -m "feat(admin): add coupon management UI with CRUD and search"
```

---

## Task 6: Checkout LiveView -- Accordion Redesign + Coupon UI

**Files:**
- Modify: `lib/emakola_web/live/storefront/checkout_live.ex` (full rewrite of render + new event handlers)

This is the largest task. The existing file is 830 lines. The rewrite keeps the backend logic (create_order, handle_payment, verify_payment_status, poll logic) but completely replaces the render function and adds coupon UI.

- [ ] **Step 1: Add new assigns for coupon and accordion state**

In `mount/3`, add:
```elixir
|> assign(:coupon_code, "")
|> assign(:coupon, nil)
|> assign(:discount_amount, 0)
|> assign(:coupon_error, nil)
|> assign(:show_mobile_summary, false)
|> assign(:form_errors, %{})
```

- [ ] **Step 2: Reverse step order (Contact=1, Payment=2, Review=3)**

Update default `step` to 1 (already is), but update all step labels and navigation:
- Step 1: "Contact & Delivery" (was Payment)
- Step 2: "Payment" (was Details)
- Step 3: "Review & Pay" (was Confirm)

Update `go_to_step`, `submit_details` handlers accordingly.

- [ ] **Step 3: Add coupon event handlers**

```elixir
def handle_event("apply_coupon", %{"coupon_code" => code}, socket) do
  case CheckoutService.validate_coupon(socket.assigns.store.id, code, socket.assigns.cart_total) do
    {:ok, coupon} ->
      discount = CheckoutService.calculate_discount(
        coupon, socket.assigns.cart_total, socket.assigns.delivery_fee
      )
      {:noreply,
       socket
       |> assign(:coupon, coupon)
       |> assign(:coupon_code, code)
       |> assign(:discount_amount, discount)
       |> assign(:coupon_error, nil)}

    {:error, reason} ->
      {:noreply,
       socket
       |> assign(:coupon_error, coupon_error_message(reason))
       |> assign(:coupon, nil)
       |> assign(:discount_amount, 0)}
  end
end

def handle_event("remove_coupon", _params, socket) do
  {:noreply,
   socket
   |> assign(:coupon, nil)
   |> assign(:coupon_code, "")
   |> assign(:discount_amount, 0)
   |> assign(:coupon_error, nil)}
end

def handle_event("toggle_mobile_summary", _params, socket) do
  {:noreply, update(socket, :show_mobile_summary, &(!&1))}
end
```

- [ ] **Step 4: Rewrite render function with accordion layout**

Full HEEx template rewrite with:
- Secure checkout header with back link and lock icon
- 3-segment progress bar
- Accordion sections:
  - Step 1 (Contact): form fields with inline validation, collapses to summary
  - Step 2 (Payment): 2x2 payment card grid, collapses to selected method
  - Step 3 (Review): coupon input, order items with images, totals, place order button
- Desktop sidebar with order summary (items with `image_url`, subtotal, discount, delivery, total)
- Mobile collapsible order summary
- Completed sections show summary + Edit link with green checkmark

- [ ] **Step 5: Update place_order to pass coupon_id**

Modify `create_order/1` to include `coupon_id: socket.assigns.coupon && socket.assigns.coupon.id` in opts passed to `CheckoutService.checkout!`.

- [ ] **Step 6: Run all checkout tests**

Run: `mix test test/emakola_web/live/storefront/checkout_live_test.exs`
Expected: Existing tests may need updating for new step order. Fix as needed.

- [ ] **Step 7: Run full suite**

Run: `mix test`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add -f lib/emakola_web/live/storefront/checkout_live.ex
git commit -m "feat(checkout): redesign with accordion steps, coupon UI, product images, mobile summary"
```

---

## Task 7: Cart Page -- Product Images + Mobile Summary

**Files:**
- Modify: `lib/emakola_web/live/storefront/cart_live.ex:100-348`

- [ ] **Step 1: Replace image placeholders with real images**

In the cart item render loop, replace the grey placeholder div with:

```heex
<div class="flex-shrink-0 w-24 h-30 sm:w-32 sm:h-40 bg-[#F1F5F9] rounded-xl overflow-hidden">
  <%= if item[:image_url] do %>
    <img src={item.image_url} alt={item.product_title} class="w-full h-full object-cover" loading="lazy" />
  <% else %>
    <div class="w-full h-full flex items-center justify-center">
      <.image_placeholder />
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Add mobile order summary**

Replace `hidden lg:block` on the order summary with a collapsible section on mobile:

```heex
<%!-- Mobile order summary (collapsible) --%>
<div class="lg:hidden mb-6">
  <button
    phx-click="toggle_mobile_summary"
    class="w-full flex items-center justify-between bg-white rounded-xl border border-[#E2E8F0] p-4"
  >
    <span class="text-sm font-semibold text-[#0F172A]">
      Order Summary ({length(@cart)} items)
    </span>
    <span class="text-sm font-bold text-[#0F172A]">
      {Currency.format_price(@cart_total, @store.currency)}
    </span>
  </button>
  <div :if={@show_mobile_summary} class="mt-2 bg-white rounded-xl border border-[#E2E8F0] p-4">
    <%!-- items list --%>
  </div>
</div>
```

Add `show_mobile_summary` assign and toggle handler.

- [ ] **Step 3: Run tests**

Run: `mix test test/emakola_web/live/storefront/cart_live_test.exs`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add -f lib/emakola_web/live/storefront/cart_live.ex
git commit -m "feat(cart): add product images and collapsible mobile order summary"
```

---

## Task 8: MoMo Rich Waiting State

**Files:**
- Modify: `lib/emakola_web/live/storefront/checkout_live.ex` (add timer + rich UI)

- [ ] **Step 1: Add timer assigns and tick handler**

In mount, add:
```elixir
|> assign(:timer_seconds, 180)
```

Add handler:
```elixir
@impl true
def handle_info(:tick_timer, socket) do
  if socket.assigns.timer_seconds > 0 and socket.assigns.payment_status == :awaiting_payment do
    Process.send_after(self(), :tick_timer, 1000)
    {:noreply, assign(socket, :timer_seconds, socket.assigns.timer_seconds - 1)}
  else
    {:noreply, socket}
  end
end
```

Start timer when entering awaiting_payment state (in `initiate_gateway_payment`):
```elixir
Process.send_after(self(), :tick_timer, 1000)
```

**Reconnect handling:** In mount, if order exists and payment is pending, calculate remaining time:
```elixir
timer_seconds =
  if socket.assigns.order do
    elapsed = DateTime.diff(DateTime.utc_now(), socket.assigns.order.inserted_at)
    max(180 - elapsed, 0)
  else
    180
  end
```

- [ ] **Step 2: Replace amber waiting box with rich status UI**

Replace the `:awaiting_payment` div with:
- Brand-colored phone icon (yellow halo for MTN, red for Vodafone)
- 3-step progress tracker with green checks for completed steps
- MM:SS countdown timer with `font-variant-numeric: tabular-nums`
- USSD fallback hint
- Help link

- [ ] **Step 3: Add timeout and failure states**

```heex
<div :if={@payment_status == :timeout} class="...">
  <%!-- Timeout UI with retry button --%>
</div>

<div :if={@payment_status == :failed} class="...">
  <%!-- Failed UI with retry button --%>
</div>
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/storefront/checkout_live_test.exs`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -f lib/emakola_web/live/storefront/checkout_live.ex
git commit -m "feat(checkout): add rich MoMo waiting state with progress tracker and countdown"
```

---

## Task 9: Order Confirmation Page -- Celebration Redesign

**Files:**
- Modify: `lib/emakola_web/live/storefront/order_confirmation_live.ex:1-250`

- [ ] **Step 1: Update mount to load product images**

Modify `load_order/2` to include images in the preload chain:
```elixir
|> Ash.Query.load(line_items: [variant: [product: [:images]]])
```

- [ ] **Step 2: Rewrite render with celebration design**

Replace the entire render function:

- Animated green checkmark (CSS `@keyframes` for scale-in + fade):
```heex
<style>
  @keyframes checkmark-pop {
    0% { transform: scale(0); opacity: 0; }
    60% { transform: scale(1.2); }
    100% { transform: scale(1); opacity: 1; }
  }
  .animate-checkmark { animation: checkmark-pop 0.6s ease-out forwards; }
</style>
```

- "You're all set!" heading with personalized greeting
- Order number subtitle
- "What happens next" vertical timeline (3 steps)
- Compact order summary with product thumbnail row from images
- Discount line if `@order.discount_amount > 0`
- Total paid
- "Continue Shopping" primary CTA
- "Contact seller on WhatsApp" secondary CTA with wa.me deep link
- SMS notification note

- [ ] **Step 3: Add helper to extract thumbnail from line item**

```elixir
defp line_item_image(line_item) do
  case line_item do
    %{variant: %{product: %{images: [img | _]}}} ->
      img.thumbnail_url || img.url
    _ ->
      nil
  end
end
```

- [ ] **Step 4: Run tests**

Run: `mix test test/emakola_web/live/storefront/order_confirmation_live_test.exs`
Expected: All pass (update assertions if needed for new HTML structure)

- [ ] **Step 5: Commit**

```bash
git add -f lib/emakola_web/live/storefront/order_confirmation_live.ex
git commit -m "feat(confirmation): redesign with celebration animation, delivery timeline, WhatsApp CTA"
```

---

## Task 10: Final Integration Test + Format + Cleanup

**Files:** All modified files

- [ ] **Step 1: Run full test suite**

Run: `mix test`
Expected: All tests pass

- [ ] **Step 2: Format all code**

Run: `mix format`

- [ ] **Step 3: Run Credo**

Run: `mix credo --strict`
Fix any issues.

- [ ] **Step 4: Format check**

Run: `mix format --check-formatted`
Expected: No formatting issues

- [ ] **Step 5: Final commit if any fixes**

```bash
git add -A
git commit -m "chore: format and lint cleanup for checkout redesign"
```

- [ ] **Step 6: Verify app compiles and runs**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation
