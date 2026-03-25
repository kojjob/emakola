# Customers Domain Design

**Date**: 2026-03-23
**Status**: Approved
**Approach**: Flat Domain (Approach A)

## Overview

Enhance the existing stub Customers domain into a fully-featured domain with 3 resources: Customer (enhanced), Address (new), and CustomerNote (new). Follows the flat domain pattern used by Catalog and Orders. Includes a find-or-create action for automatic customer resolution at checkout and integration with the Orders/CheckoutService.

## Resources

### Customer (existing — enhanced)

**Table**: `customers` (already exists)

**Attributes** (additions in bold):
- `id` — uuid, primary key
- `store_id` — uuid, required, FK to stores
- `email` — ci_string, required
- `name` — string, optional
- `phone` — string, optional
- **`tags`** — `{:array, :string}`, default `[]`
- **`last_order_at`** — utc_datetime_usec, optional. Updated by the CheckoutService after order creation via `Ash.Changeset.for_update(:touch_last_order)`.
- `inserted_at`, `updated_at` — timestamps

**Relationships**:
- `belongs_to :store` (existing)
- `has_many :addresses, Address`
- `has_many :notes, CustomerNote`
- `has_many :orders, Emakola.Orders.Order`

**Aggregates**:
- `total_orders` — count of `:orders`
- `total_spent` — sum of `:orders`, field `:total` (returns integer in minor currency units — pesewas/kobo)

**Identity**: `unique_store_email` on `[:store_id, :email]` (existing)

**Actions**:
- `create` — accepts `[:email, :name, :phone, :store_id, :tags]`
- `update` — accepts `[:name, :phone, :tags]`
- `touch_last_order` — update action, accepts `[]`, sets `last_order_at` to `DateTime.utc_now()`. Called by CheckoutService after order creation.
- `find_or_create` — generic action, args: `email` (ci_string, required), `store_id` (uuid, required), `name` (string, optional), `phone` (string, optional). Queries by email + store_id. Returns existing customer or creates new one. **Implementation note**: Must be extracted to a separate module implementing `Ash.Resource.Actions.Implementation` with `require Ash.Query` at module level (per CLAUDE.md Ash DSL gotcha). For concurrent checkout race conditions, use `Ash.create` with retry on unique constraint violation rather than upsert — the identity `unique_store_email` will catch duplicates.
- `list_by_store` — read action, arg: `store_id`. Sorted by `inserted_at: :desc`.
- `search` — read action, args: `query` (string, required) + `store_id` (uuid, required). Uses OR logic with `fragment("lower(?)", ...)` across name, email, phone. Filter includes `store_id == ^arg(:store_id)`. Same pattern as `Product.search`.

### Address (new)

**Table**: `addresses`

**Attributes**:
- `id` — uuid, primary key
- `customer_id` — uuid, required, FK to customers
- `store_id` — uuid, required (denormalized for multi-tenancy)
- `label` — string, optional (e.g., "Home", "Office")
- `first_name` — string, optional
- `last_name` — string, optional
- `line_1` — string, required
- `line_2` — string, optional
- `city` — string, required
- `region` — string, optional (Ghana regions like "Greater Accra")
- `country` — string, default "GH"
- `postal_code` — string, optional (many West African addresses lack postal codes)
- `phone` — string, optional (delivery driver contact)
- `is_default` — boolean, default false
- `inserted_at`, `updated_at` — timestamps

**Relationships**:
- `belongs_to :customer, Customer`
- `belongs_to :store, Emakola.Accounts.Store`

**Indexes**:
- Composite index on `[:customer_id, :store_id]` for `list_by_customer` query performance

**Actions**:
- `create` — accepts all fields
- `update` — accepts all fields except `customer_id`, `store_id`
- `destroy` — default
- `list_by_customer` — read action, args: `customer_id` + `store_id`
- `set_as_default` — **generic action** (not update action). Takes the address ID as argument. Uses `Ash.bulk_update` to clear `is_default` on all other addresses for the same customer, then updates the target address. Must be extracted to a separate implementation module with `require Ash.Query`.

### CustomerNote (new)

**Table**: `customer_notes`

**Attributes**:
- `id` — uuid, primary key
- `customer_id` — uuid, required, FK to customers
- `store_id` — uuid, required (denormalized for multi-tenancy)
- `author_id` — uuid, optional, FK to users (the merchant `Emakola.Accounts.User` who wrote the note). Nullable because system-generated notes (e.g., from automated processes) may have no author.
- `content` — string, required
- `inserted_at`, `updated_at` — timestamps

**Relationships**:
- `belongs_to :customer, Customer`
- `belongs_to :store, Emakola.Accounts.Store`
- `belongs_to :author, Emakola.Accounts.User`

**Indexes**:
- Composite index on `[:customer_id, :store_id]` for `list_by_customer` query performance

**Actions**:
- `create` — accepts `[:customer_id, :store_id, :author_id, :content]`
- `destroy` — default
- `list_by_customer` — read action, args: `customer_id` + `store_id`. Sorted by `inserted_at: :desc`.

## Domain Module

```elixir
Emakola.Customers:
  Customer:
    - create_customer (action: :create)
    - update_customer (action: :update)
    - find_or_create_customer (action: :find_or_create, args: [:email, :store_id])
    - list_customers_by_store (action: :list_by_store, args: [:store_id])
    - search_customers (action: :search, args: [:query, :store_id])

  Address:
    - create_address (action: :create)
    - update_address (action: :update)
    - destroy_address (action: :destroy)
    - list_addresses_by_customer (action: :list_by_customer, args: [:customer_id])
    - set_default_address (action: :set_as_default)

  CustomerNote:
    - create_note (action: :create)
    - destroy_note (action: :destroy)
    - list_notes_by_customer (action: :list_by_customer, args: [:customer_id])
```

## Integration with Orders

### CheckoutService Changes

**Current**: accepts `customer_id` in opts.
**New**: accepts `customer_email` (required), `customer_name` (optional), `customer_phone` (optional) in opts. **Also retains `customer_id` as a fallback** for backward compatibility — if `customer_id` is provided, it is used directly without find-or-create. Existing tests that use `customer_id` continue to work.

**Flow**:
1. If `customer_id` provided in opts, use it directly (backward compatible path)
2. Otherwise, call `Customer.find_or_create` with email + store_id + optional name/phone
3. If customer has a default address and no `shipping_address` provided in opts, resolve the default address
4. Snapshot the address as a map on the Order (preserves address at time of purchase)
5. Link order to customer via `customer_id`
6. After order creation, call `Customer.touch_last_order` to update `last_order_at`

**Order resource**: no changes needed — already has `belongs_to :customer`.

## Migrations

1. **Alter customers table**: add `tags` (array of text, default `[]`) and `last_order_at` (utc_datetime_usec) columns
2. **Create addresses table**: all fields as described, FK to customers and stores, composite index on `[:customer_id, :store_id]`
3. **Create customer_notes table**: all fields as described, FK to customers, stores, and users, composite index on `[:customer_id, :store_id]`

## Testing Strategy

### Unit Tests
- **Customer enhanced**: create with tags, update tags, find_or_create (both paths — existing and new), list_by_store, search across name/email/phone, touch_last_order
- **Address**: CRUD (create, update, destroy), list_by_customer, set_as_default (clears previous default), required field validations (line_1, city)
- **CustomerNote**: create, destroy, list_by_customer ordering, required content validation, nullable author_id

### Integration Tests
- Checkout flow with find-or-create: new customer email creates customer record
- Checkout flow with find-or-create: existing customer email links to existing record
- Checkout flow with customer_id fallback (backward compatibility)
- Default address resolution at checkout when no shipping_address provided
- `last_order_at` updated after successful checkout

### Edge Cases
- Duplicate emails across different stores (allowed)
- Duplicate emails within same store (rejected)
- Concurrent find_or_create for same email + store_id (unique constraint handles race)
- Address without postal_code (allowed — West African reality)
- set_as_default when customer has no other addresses
- set_as_default when customer has only one address (the target)
- find_or_create with only email (no name/phone)
- Notes by different authors on same customer
- Notes with nil author_id (system-generated)
- Search with partial phone number match

## Non-Goals (YAGNI)

- Customer authentication/login (customers don't log in yet — merchants manage them)
- Customer merge/deduplication tooling
- Address validation against external APIs
- Customer groups/segments beyond simple tags
- Order history aggregation views (can be built later with existing aggregates)
