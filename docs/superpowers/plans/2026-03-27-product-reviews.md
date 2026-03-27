# Customer Auth + Product Reviews Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add customer login/registration to the storefront, then verified-purchase product reviews with star ratings.

**Architecture:** Extend Customer resource with AshAuthentication (password strategy). Create storefront login/register pages, session handling, and account page wired to real data. Then add Review resource with eligibility checks and shared review UI components.

**Tech Stack:** Elixir, Ash 3.x, AshAuthentication, Phoenix LiveView, PostgreSQL

---

## Phase 1: Customer Authentication

### Task 1: Extend Customer Resource with Authentication

**Files:**
- Modify: `lib/emakola/customers/resources/customer.ex`
- Create: `lib/emakola/customers/resources/customer_token.ex`
- Modify: `lib/emakola/customers/customers.ex`
- Create: `priv/repo/migrations/TIMESTAMP_add_customer_auth.exs`
- Create: `test/emakola/customers/customer_auth_test.exs`

- [ ] **Step 1: Write failing tests**

Create `test/emakola/customers/customer_auth_test.exs`:

```elixir
defmodule Emakola.Customers.CustomerAuthTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  setup do
    {_merchant, store} = Factory.create_merchant_with_store!()
    %{store: store}
  end

  describe "customer registration with password" do
    test "creates a customer with email and password", %{store: store} do
      customer =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "shopper@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id
        })
        |> Ash.create!()

      assert to_string(customer.email) == "shopper@example.com"
      assert customer.store_id == store.id
      assert customer.hashed_password != nil
    end

    test "rejects duplicate email within same store", %{store: store} do
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "dup@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        store_id: store.id
      })
      |> Ash.create!()

      assert {:error, _} =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "dup@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store.id
        })
        |> Ash.create()
    end

    test "same email in different stores is allowed", %{store: store} do
      {_m, store2} = Factory.create_merchant_with_store!()

      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "multi@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        store_id: store.id
      })
      |> Ash.create!()

      customer2 =
        Emakola.Customers.Customer
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "multi@example.com",
          password: "Password123!",
          password_confirmation: "Password123!",
          store_id: store2.id
        })
        |> Ash.create!()

      assert customer2.store_id == store2.id
    end
  end

  describe "customer sign in" do
    test "signs in with correct password", %{store: store} do
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "login@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        store_id: store.id
      })
      |> Ash.create!()

      assert {:ok, customer} =
        Emakola.Customers.Customer
        |> Ash.Query.for_read(:sign_in_with_password, %{
          email: "login@example.com",
          password: "Password123!"
        })
        |> Ash.read_one(authorize?: false)

      assert customer != nil
    end
  end
end
```

- [ ] **Step 2: Create migration for customer auth fields**

Create migration:

```elixir
defmodule Emakola.Repo.Migrations.AddCustomerAuth do
  use Ecto.Migration

  def change do
    alter table(:customers) do
      add :hashed_password, :string
    end

    create table(:customer_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :jti, :string, null: false
      add :subject, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :string, null: false
      add :extra_data, :map, default: %{}
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:customer_tokens, [:jti])
  end
end
```

- [ ] **Step 3: Create CustomerToken resource**

Create `lib/emakola/customers/resources/customer_token.ex`:

```elixir
defmodule Emakola.Customers.CustomerToken do
  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("customer_tokens")
    repo(Emakola.Repo)
  end

  token do
    api(Emakola.Customers)
  end
end
```

- [ ] **Step 4: Add AshAuthentication to Customer resource**

Modify `lib/emakola/customers/resources/customer.ex` to add:

In the `use Ash.Resource` call, add the extension:
```elixir
  use Ash.Resource,
    domain: Emakola.Customers,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]
```

Add the authentication block after the `use` statement:
```elixir
  authentication do
    tokens do
      enabled?(true)
      token_resource(Emakola.Customers.CustomerToken)
      signing_secret(Application.compile_env(:emakola, :token_signing_secret))
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)

        register_action_name(:register_with_password)
        sign_in_action_name(:sign_in_with_password)
      end
    end
  end
```

Add the `hashed_password` attribute:
```elixir
    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end
```

- [ ] **Step 5: Register CustomerToken in domain**

In `lib/emakola/customers/customers.ex`, add:
```elixir
    resource(Emakola.Customers.CustomerToken)
```

- [ ] **Step 6: Run migration and tests**

```bash
mix ecto.migrate
mix test test/emakola/customers/customer_auth_test.exs -v
```

- [ ] **Step 7: Commit**

```bash
git add lib/emakola/customers/ priv/repo/migrations/*customer_auth* test/emakola/customers/customer_auth_test.exs
git commit -m "feat(customers): add password authentication to Customer resource"
```

---

### Task 2: Storefront Customer Session Handling

**Files:**
- Modify: `lib/emakola_web/plugs/cart_session.ex`
- Create: `lib/emakola_web/hooks/resolve_customer.ex`
- Modify: `lib/emakola_web/router.ex`

- [ ] **Step 1: Extend CartSession to pass customer_token**

In `lib/emakola_web/plugs/cart_session.ex`, update `live_session_data` to include customer_token:

```elixir
  def live_session_data(conn) do
    %{
      "cart_session_id" => get_session(conn, "cart_session_id"),
      "customer_token" => get_session(conn, "customer_token")
    }
  end
```

- [ ] **Step 2: Create ResolveCustomer on_mount hook**

Create `lib/emakola_web/hooks/resolve_customer.ex`:

```elixir
defmodule EmakolaWeb.Hooks.ResolveCustomer do
  @moduledoc """
  LiveView on_mount hook that resolves the current customer from session token.
  Sets @current_customer assign for storefront pages.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    customer_token = session["customer_token"]

    if customer_token do
      case AshAuthentication.subject_to_user(customer_token, Emakola.Customers.Customer) do
        {:ok, customer} ->
          {:cont, assign(socket, :current_customer, customer)}

        _ ->
          {:cont, assign(socket, :current_customer, nil)}
      end
    else
      {:cont, assign(socket, :current_customer, nil)}
    end
  end
end
```

- [ ] **Step 3: Add hook to storefront live_session**

In `lib/emakola_web/router.ex`, update the storefront `live_session` to include the customer hook:

```elixir
    live_session :storefront,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStore, :default},
        {EmakolaWeb.Hooks.ResolveCustomer, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
```

- [ ] **Step 4: Add storefront auth routes**

In `lib/emakola_web/router.ex`, add customer auth routes OUTSIDE the main storefront live_session (they need their own session handling):

```elixir
  # Customer auth routes (separate live_session — no auth required)
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through :browser

    live_session :storefront_auth,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [{EmakolaWeb.Hooks.ResolveStore, :default}],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/login", CustomerLoginLive
      live "/register", CustomerRegisterLive
    end
  end
```

Also add a session controller route for customer token exchange:

```elixir
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through :browser

    post "/auth/customer-session", CustomerSessionController, :create
    delete "/auth/customer-session", CustomerSessionController, :delete
  end
```

- [ ] **Step 5: Create CustomerSessionController**

Create `lib/emakola_web/controllers/customer_session_controller.ex`:

```elixir
defmodule EmakolaWeb.Storefront.CustomerSessionController do
  use EmakolaWeb, :controller

  def create(conn, %{"store_slug" => slug, "token" => token}) do
    conn
    |> put_session(:customer_token, token)
    |> redirect(to: "/s/#{slug}/account")
  end

  def delete(conn, %{"store_slug" => slug}) do
    conn
    |> delete_session(:customer_token)
    |> redirect(to: "/s/#{slug}")
  end
end
```

- [ ] **Step 6: Verify compilation**

```bash
mix compile --warnings-as-errors
```

- [ ] **Step 7: Commit**

```bash
git add lib/emakola_web/plugs/cart_session.ex lib/emakola_web/hooks/resolve_customer.ex lib/emakola_web/router.ex lib/emakola_web/controllers/customer_session_controller.ex
git commit -m "feat(web): add customer session handling and auth routes"
```

---

### Task 3: Customer Login & Register LiveViews

**Files:**
- Create: `lib/emakola_web/live/storefront/customer_login_live.ex`
- Create: `lib/emakola_web/live/storefront/customer_register_live.ex`
- Create: `test/emakola_web/live/storefront/customer_auth_live_test.exs`

- [ ] **Step 1: Create CustomerLoginLive**

Create `lib/emakola_web/live/storefront/customer_login_live.ex` — a clean login form with email + password, link to register, store branding. On submit, authenticate via `Ash.Query.for_read(:sign_in_with_password, ...)`, generate token with `AshAuthentication.user_to_subject/1`, redirect to session controller.

- [ ] **Step 2: Create CustomerRegisterLive**

Create `lib/emakola_web/live/storefront/customer_register_live.ex` — register form with name, email, password, password confirmation. On submit, create customer with `:register_with_password` action (include `store_id`). Auto-login after registration.

- [ ] **Step 3: Write tests**

Test: login page renders, register page renders, successful registration creates customer, successful login redirects.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(web): add customer login and register storefront pages"
```

---

### Task 4: Wire Account Page to Real Customer Data

**Files:**
- Modify: `lib/emakola_web/live/storefront/account_live.ex`
- Create: `test/emakola_web/live/storefront/account_live_auth_test.exs`

- [ ] **Step 1: Rewrite AccountLive mount**

Replace placeholder data with real customer from `@current_customer`. Load orders, addresses from Ash. If no customer in session, redirect to login.

- [ ] **Step 2: Add logout event**

Handle `"logout"` event — clear customer_token from session, redirect to store home.

- [ ] **Step 3: Write tests and commit**

```bash
git commit -m "feat(web): wire account page to real customer data with logout"
```

---

## Phase 2: Product Reviews

### Task 5: Create Review Resource

**Files:**
- Create: `lib/emakola/catalog/resources/review.ex`
- Create: `priv/repo/migrations/TIMESTAMP_create_reviews.exs`
- Modify: `lib/emakola/catalog/catalog.ex`
- Modify: `lib/emakola/catalog/resources/product.ex`
- Create: `test/emakola/catalog/review_test.exs`

- [ ] **Step 1: Write tests for Review CRUD, eligibility, and aggregates**

Tests cover: creation with valid data, rating 1-5 validation, body required, duplicate prevention, hide/unhide, eligibility check (eligible, not eligible, already reviewed), product avg_rating and review_count aggregates.

- [ ] **Step 2: Create Review resource**

Ash resource with: store_id, product_id, customer_id, order_id, rating (1-5), title (optional, max 100), body (required, max 2000), status (:published/:hidden), verified_purchase (true). Identity on [:store_id, :product_id, :customer_id]. Actions: create, read, hide, unhide. Class method `eligible?(store_id, product_id, customer_id)`.

- [ ] **Step 3: Create migration, register in domain, add Product aggregates**

Migration: reviews table with indexes. Domain: register Review. Product: add `has_many :reviews`, `review_count` and `avg_rating` aggregates filtered by published status.

- [ ] **Step 4: Run tests and commit**

```bash
git commit -m "feat(catalog): add Review resource with eligibility check and product aggregates"
```

---

### Task 6: Review UI Components

**Files:**
- Create: `lib/emakola_web/components/review_components.ex`

- [ ] **Step 1: Create ReviewComponents module**

Shared components: `review_summary/1` (avg rating + count), `review_section/1` (full section with form + list), `star_display/1`, `star_selector/1`. The review form checks `@can_review` and `@already_reviewed` assigns.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(web): add shared review components (stars, form, list)"
```

---

### Task 7: Wire Reviews into Product Detail

**Files:**
- Modify: `lib/emakola_web/live/storefront/product_detail_live.ex`
- Modify: All 6 theme `product_detail.ex` files
- Create: `test/emakola_web/live/storefront/product_review_test.exs`

- [ ] **Step 1: Add review assigns to ProductDetailLive mount**

Load reviews, check eligibility using `@current_customer`, add review form state assigns.

- [ ] **Step 2: Add review event handlers**

Handle `set_review_rating`, `submit_review` events. Create review with customer_id from `@current_customer`.

- [ ] **Step 3: Add ReviewComponents.review_section to all theme product_detail pages**

Single component call at the bottom of each theme's product detail template.

- [ ] **Step 4: Update load_product to include review aggregates**

Add `:avg_rating, :review_count` to the load list.

- [ ] **Step 5: Write tests and commit**

```bash
git commit -m "feat(web): wire product reviews into storefront product detail pages"
```

---

### Task 8: Admin Review Management

**Files:**
- Create: `lib/emakola_web/live/admin/review_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Create: `test/emakola_web/live/admin/review_live_test.exs`

- [ ] **Step 1: Create ReviewLive admin page**

Table with product name, customer, rating stars, review text, status badge, hide/show toggle. Filter by status (All/Published/Hidden).

- [ ] **Step 2: Add route and write tests**

Route: `/admin/reviews`. Tests: renders page, can hide/unhide.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(admin): add review management page with hide/unhide"
```

---

### Task 9: Final Verification

- [ ] **Step 1: Format, credo, full test suite**
- [ ] **Step 2: Commit any fixes**
