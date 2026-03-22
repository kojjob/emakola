# Emakola — Phase 0 Cleanup + Catalog Domain Design

> Approved design spec for cleaning up the FounderPad boilerplate and building the Catalog domain.
> Date: 2026-03-22 | Revision: 2 (post spec-review fixes)

---

## Overview

Emakola is a multi-tenant ecommerce platform for West Africa (Ghana-first, then Nigeria). The codebase was scaffolded from a SaaS boilerplate (FounderPad) and contains enterprise SaaS features (billing, workspaces, team management) alongside completely empty ecommerce domains. This spec covers two phases:

1. **Phase 0**: Remove FounderPad-specific UI/routes that don't apply, fix compilation blockers, create missing Store resource, and establish a clean foundation.
2. **Catalog Domain**: Build the full product catalog — Category, Product, OptionType, OptionValue, Variant, Image — following TDD and Ash 3.x patterns.

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Product-Variant model | Shopify-style (required variants) | Every product has at least one variant holding price/SKU/stock. Flexible for all product types. |
| Currency | Single currency per store | Ghana-first launch. Store's `currency` attribute (GHS/NGN/USD) determines interpretation of integer prices. |
| Options architecture | Separate OptionType/OptionValue resources | Unlimited reuse, normalized schema, supports complex products. |
| Category structure | Unlimited nesting via parent_id | Open to all product types — clothing, electronics, food, building materials. |
| Image handling | S3 upload + async processing (libvips) | Optimized thumbnails/medium sizes for low-bandwidth mobile networks. WebP format. |
| Product status | draft → active → archived | Covers full lifecycle without over-engineering. |
| Money storage | Integer minor units (pesewas/kobo) | No floats. Display formatting in presentation layer only. |
| Multi-tenancy | `store_id` on ALL catalog resources | Denormalized for safety — every resource has its own `store_id` for Ash attribute-based multitenancy. |

---

## Phase 0: Clean House

### Remove

1. **Duplicate files** causing compilation failure:
   - `lib/emakola 2.ex`
   - `lib/emakola_web 2.ex`

2. **Duplicate module file** (contains Organisation module, not Store):
   - `lib/emakola/accounts/resources/store.ex` — this file defines `Emakola.Accounts.Organisation` (duplicate of `organisation.ex`). Delete it; the real Store resource will be created fresh.

3. **FounderPad LiveView pages** (not applicable to ecommerce):
   - `WorkspacesLive`
   - `ActivityLive`
   - `BillingLive`
   - `TeamLive`
   - `SettingsLive`
   - Associated test files

4. **FounderPad controllers**:
   - `CheckoutController` (Stripe checkout — Emakola uses Paystack/Hubtel)
   - `SitemapController` (premature, no content to index)

5. **FounderPad routes**:
   - Stripe webhook route (`/webhooks/stripe`)
   - Checkout route (`/checkout/:plan_slug`)
   - Docs sub-pages (`/docs/api`, `/docs/changelog`)

6. **FounderPad LiveView pages** for docs:
   - `Docs.ApiSpecsLive`
   - `Docs.ChangelogLive`

7. **Non-functional API routes and modules** (dependencies not installed):
   - `EmakolaWeb.Api.GraphqlSchema` — references `AshGraphql`/`Absinthe` which are not in `mix.exs`
   - `EmakolaWeb.Api.JsonApiRouter` — references `AshJsonApi` which is not in `mix.exs`
   - `/api/v1` route scope (JSON:API)
   - `/api/graphql` and `/api/graphiql` route scopes
   - These can be re-added later when API dependencies are installed and catalog resources exist.

### Create

1. **`Emakola.Accounts.Store` resource** — The Merchant resource references `Emakola.Accounts.Store` and `Emakola.Accounts.StoreMembership` but neither exists. This is a prerequisite for the entire Catalog domain.

   **Store resource spec:**
   - Table: `stores`
   - Attributes: `id` (uuid), `name` (string, required), `slug` (string, required, unique), `description` (string), `currency` (string, required, default "GHS", one_of: ["GHS", "NGN", "USD"]), `logo_url` (string), `domain` (string, nullable — custom domain), `timezone` (string, default "Africa/Accra"), `active` (boolean, default true), timestamps
   - Relationships: `has_many :store_memberships`, `many_to_many :merchants through StoreMembership`, `has_many :products` (added in Catalog phase)
   - Identity: unique `[:slug]`
   - Actions: `create` (auto-generates slug from name), `read`, `update`, `destroy`

2. **`Emakola.Accounts.StoreMembership` resource** — Join between Merchant and Store.
   - Table: `store_memberships`
   - Attributes: `id` (uuid), `role` (atom, one_of: [:owner, :admin, :staff], default :staff), timestamps
   - Relationships: `belongs_to :merchant`, `belongs_to :store`
   - Identity: unique `[:merchant_id, :store_id]`

3. **Register both in `Emakola.Accounts` domain.**

4. **Generate migration** for `stores` and `store_memberships` tables.

5. **`/health` endpoint** — GET route returning JSON `{"status": "ok"}`. Required by Dockerfile and fly.toml.

### Modify

1. **Router** — Strip to: auth routes, landing page, dashboard shell, onboarding, `/health`. Remove API route scopes.
2. **Layouts** — Replace Phoenix default branding with Emakola branding.
3. **`mix.exs`** — Update `elixir: "~> 1.18"` (currently `~> 1.15`, contradicts stated stack requirement).

### Keep Intact

- Accounts domain (User, Organisation, Membership, Merchant, Token)
- Billing, Notifications, Audit, Webhooks, FeatureFlags, Analytics domains
- Oban, PubSub, Telemetry infrastructure
- `OnboardingLive`, `DashboardLive`, `LandingLive`

### Success Criteria

- `mix compile` succeeds with zero errors
- `mix test` passes (existing tests, or clean slate if tests relied on removed modules)
- `mix format --check-formatted` passes
- `mix credo --strict` clean
- `/health` returns 200 OK
- `Emakola.Accounts.Store` and `Emakola.Accounts.StoreMembership` resources exist and are registered

---

## Catalog Domain Architecture

### Resource Map

```
Emakola.Catalog
├── Category            Self-referencing tree, unlimited nesting
├── Product             Container, belongs to store + category
├── OptionType          Named option (e.g., "Size"), belongs to product
├── OptionValue         Option choice (e.g., "Large"), belongs to option type
├── Variant             Price, SKU, stock — belongs to product
├── VariantOptionValue  Join: variant ↔ option value
└── Image               S3 URLs + processed sizes, belongs to product/variant
```

### Relationships

```
Store (1) ──→ (many) Product          multi-tenant via store_id
Category (1) ──→ (many) Product       product belongs to one category
Category (0..1) ──→ (many) Category   self-referencing parent/children
Product (1) ──→ (many) OptionType     option types scoped to product
OptionType (1) ──→ (many) OptionValue  values scoped to option type
Product (1) ──→ (many) Variant
Variant (many) ←──→ (many) OptionValue  via variant_option_values join
Product (1) ──→ (many) Image
Variant (0..1) ──→ (many) Image        variant-specific images optional
```

### Multi-Tenancy

**Every** Catalog resource includes `store_id` with Ash attribute-based multitenancy — including OptionType, OptionValue, VariantOptionValue, and Image. This is denormalized from parent resources on create. All queries must include tenant context. Store isolation is critical — never leak data across stores.

Rationale: The CLAUDE.md states "Every tenant-scoped query MUST include tenant context." Relying on implicit isolation through parent joins is fragile. Denormalizing `store_id` ensures Ash multitenancy filtering works on direct queries against any resource.

---

## Resource Specifications

### Category

**Table:** `categories`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required, foreign key → stores |
| `name` | string | required |
| `slug` | string | required |
| `description` | string | optional |
| `parent_id` | uuid | nullable, self-referencing foreign key |
| `position` | integer | default 0, for ordering |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Identities:** unique `[store_id, slug]`

**Actions:**
- `create` — accepts name, description, parent_id. Auto-generates slug from name.
- `read` — standard read.
- `update` — accepts name, description, parent_id, position.
- `destroy` — fails if category has products (or reassign to parent).
- `list_roots` — filter where `parent_id` is nil, ordered by position.
- `list_children` — filter by `parent_id`, ordered by position.

**Validations:**
- Name required, non-empty.
- Slug auto-generated from name, unique per store.
- Prevent circular parent references (category cannot be its own ancestor).
- `parent_id` must reference a category in the same store.

**Edge Cases:**
- Circular reference detection (A → B → C → A)
- Deep nesting performance (query with recursive CTE or preload strategy)
- Orphaned children when parent deleted (block delete or reassign)
- Duplicate slugs from similar names (append numeric suffix)
- Unicode/special characters in names (proper slugification for Akan, Hausa, Yoruba)

---

### Product

**Table:** `products`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required, foreign key → stores |
| `category_id` | uuid | nullable, foreign key → categories |
| `title` | string | required |
| `slug` | string | required |
| `description` | string | optional (text) |
| `status` | enum (draft/active/archived) | default :draft |
| `seo_title` | string | optional |
| `seo_description` | string | optional |
| `tags` | {:array, :string} | default [] |
| `published_at` | utc_datetime_usec | nullable |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Identities:** unique `[store_id, slug]`

**Actions:**
- `create` — accepts title, description, category_id, tags, SEO fields. Auto-generates slug.
- `read` — standard read.
- `update` — accepts title, description, category_id, status, tags, SEO fields.
- `activate` — transitions status to `:active`, sets `published_at`. Fails if no variants exist.
- `archive` — transitions status to `:archived`.
- `list_by_category` — filter by category_id.
- `search` — filter by title (ILIKE) or tags (array overlap).

**Validations:**
- Title required, non-empty.
- Slug auto-generated, unique per store.
- Status transitions: draft → active (requires variants), active → archived, draft → archived, archived → draft.
- Cannot activate without at least one variant.
- `category_id` must belong to same store.

**Ash 3.x Implementation Note — `activate` validation:**
The "has at least one variant" check MUST be implemented as a standalone validation module, NOT as an inline anonymous function. Per CLAUDE.md: `Ash.Query.filter` is a macro and does not work inside anonymous functions in Ash DSL `actions do...end` blocks.

```elixir
defmodule Emakola.Catalog.Validations.HasVariants do
  use Ash.Resource.Validation
  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    product_id = Ash.Changeset.get_data(changeset, :id)
    # Check variant count via Ash query
    # Return :ok or {:error, ...}
  end
end
```

**Edge Cases:**
- Activate with zero variants (must fail)
- Status transition from archived → active (must go through draft first)
- Slug collision from identical titles (numeric suffix)
- XSS in title/description (sanitize at input)
- Category deletion impact (nullify or block)
- Product with maximum variants/images (performance)

---

### OptionType

**Table:** `option_types`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required (denormalized from product) |
| `product_id` | uuid | required, foreign key → products |
| `name` | string | required |
| `position` | integer | default 0 |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Identities:** unique `[product_id, name]`

**Actions:**
- `create` — accepts name, position. Auto-populates `store_id` from parent product. Validates max 3 per product.
- `read` — standard read.
- `update` — accepts name, position.
- `destroy` — cascades to option values. Fails if variants reference its values.

**Validations:**
- Name required, non-empty.
- Max 3 option types per product.
- Unique name within product (case-insensitive).

**Edge Cases:**
- 4th option type creation (must reject)
- Delete option type when variants reference its values (block or cascade)
- Empty string name (must reject)
- Duplicate name with different casing (case-insensitive uniqueness)

---

### OptionValue

**Table:** `option_values`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required (denormalized from option type's product) |
| `option_type_id` | uuid | required, foreign key → option_types |
| `value` | string | required |
| `position` | integer | default 0 |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Identities:** unique `[option_type_id, value]`

**Actions:**
- `create` — accepts value, position. Auto-populates `store_id` from parent option type.
- `read` — standard read.
- `update` — accepts value, position.
- `destroy` — fails if variants reference this value.

**Validations:**
- Value required, non-empty, max 100 characters.
- Unique within option type.

**Edge Cases:**
- Delete value referenced by variants (must block)
- Empty/whitespace-only value (must reject)
- Very long value strings (enforce 100 char limit)
- Duplicate with different casing

---

### Variant

**Table:** `variants`

**Database constraint:** `CHECK (stock_quantity >= 0)` — enforced at the database level to prevent negative stock under concurrent access.

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `product_id` | uuid | required, foreign key → products |
| `store_id` | uuid | required (denormalized for SKU uniqueness + multitenancy) |
| `sku` | string | optional |
| `price` | integer | required, > 0 (minor units) |
| `compare_at_price` | integer | nullable, must be > price if present |
| `stock_quantity` | integer | default 0, >= 0 (DB CHECK constraint) |
| `track_inventory` | boolean | default true |
| `weight_grams` | integer | nullable |
| `barcode` | string | nullable |
| `position` | integer | default 0 |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Identities:** unique `[store_id, sku]` (when SKU is present)

**Actions:**
- `create` — accepts price, sku, stock_quantity, compare_at_price, weight, barcode. Auto-populates `store_id` from parent product.
- `read` — standard read.
- `update` — accepts all mutable fields.
- `destroy` — standard destroy.
- `adjust_stock` — accepts integer delta. Uses `Ash.Changeset.atomic_update(:stock_quantity, expr(stock_quantity + ^arg(:delta)))` for atomic DB-level operation. The CHECK constraint prevents negative stock; if the constraint is violated, AshPostgres returns an error.
- `low_stock` — query where `stock_quantity` < given threshold and `track_inventory` is true.

**Validations:**
- Price required, must be > 0.
- `compare_at_price` must be > `price` if present (it's the "original" price).
- `stock_quantity` >= 0 (also enforced by DB CHECK).
- SKU unique within store (when present).
- `store_id` must match parent product's `store_id`.

**Edge Cases:**
- Zero price (must reject)
- Negative price (must reject)
- Negative stock after adjustment (DB CHECK prevents, Ash returns error)
- Concurrent stock adjustments (atomic SQL operation, no Elixir-side race)
- SKU collision across products in same store (must reject)
- `compare_at_price` less than `price` (must reject)
- Variant without option values (valid — single-variant products)
- Very large stock numbers (integer overflow protection)

---

### VariantOptionValue (Join Resource)

**Table:** `variant_option_values`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required (denormalized from variant) |
| `variant_id` | uuid | required, foreign key → variants |
| `option_value_id` | uuid | required, foreign key → option_values |

**Identities:** unique `[variant_id, option_value_id]`

**Validations:**
- Unique combination.
- Option value must belong to an option type that belongs to the same product as the variant.
- `store_id` auto-populated from variant.

**Edge Cases:**
- Cross-product option value assignment (must reject)
- Duplicate combination (must reject)
- Orphan cleanup when variant or option value deleted

---

### Image

**Table:** `images`

**Attributes:**
| Name | Type | Constraints |
|------|------|-------------|
| `id` | uuid | primary key |
| `store_id` | uuid | required (denormalized from product) |
| `product_id` | uuid | required, foreign key → products |
| `variant_id` | uuid | nullable, foreign key → variants |
| `url` | string | required (original S3 URL) |
| `thumbnail_url` | string | nullable (populated by worker) |
| `medium_url` | string | nullable (populated by worker) |
| `alt_text` | string | optional |
| `position` | integer | default 0 |
| `content_type` | string | required |
| `file_size_bytes` | integer | nullable |
| `processing_status` | enum (pending/completed/failed) | default :pending |
| `inserted_at` | utc_datetime_usec | auto |
| `updated_at` | utc_datetime_usec | auto |

**Actions:**
- `create` — accepts url, alt_text, content_type, file_size_bytes, product_id, variant_id. Auto-populates `store_id`.
- `read` — standard read.
- `update` — accepts alt_text, position.
- `mark_processed` — sets thumbnail_url, medium_url, processing_status to :completed.
- `mark_failed` — sets processing_status to :failed.
- `destroy` — deletes record (S3 cleanup via Oban worker).
- `reorder` — update positions for a set of images.

**Validations:**
- URL required.
- `content_type` must be one of: `image/jpeg`, `image/png`, `image/webp` (GIF excluded — antithetical to low-bandwidth optimization goal).
- `variant_id` must belong to same product if present.
- `file_size_bytes` max 10MB (secondary check — primary enforcement at LiveView upload: `allow_upload(:images, max_file_size: 10_000_000, accept: ~w(.jpg .jpeg .png .webp))`).

**Edge Cases:**
- Invalid content type (must reject non-image and GIF MIME types)
- Oversized file (rejected at LiveView upload level, secondary check in resource)
- S3 upload failure (mark as failed, allow retry)
- Corrupt image that can't be processed (mark as failed, keep original)
- Worker idempotency (re-processing same image is safe)
- Variant from different product (must reject)
- Position gaps/duplicates after deletion (reorder action)

---

## Image Processing Pipeline

### Flow

1. Merchant uploads image via LiveView form (`allow_upload` with size/type enforcement).
2. Original saved to S3: `stores/{store_id}/products/{product_id}/originals/{uuid}.{ext}`
3. Image resource created with `processing_status: :pending`.
4. Oban job enqueued: `Emakola.Workers.ImageProcessorWorker`.
5. Worker generates sizes using `image` library (libvips binding):
   - **Thumbnail**: 200x200px, quality 80
   - **Medium**: 600x600px, quality 85
6. Processed images saved to S3: `stores/{store_id}/products/{product_id}/{size}/{uuid}.webp`
7. Worker calls `Image.mark_processed/3` with URLs.
8. On failure, worker calls `Image.mark_failed/1`. Oban retries with backoff.

### Format

WebP for all processed sizes (30-50% smaller than JPEG). Fallback to JPEG if WebP generation fails.

### Infrastructure Requirement

The `image` hex package requires **libvips** as a system dependency:
- **Docker**: Add `apt-get install -y libvips-dev` to Dockerfile (or `apk add vips-dev` for Alpine)
- **CI**: Install libvips in CI runner image
- **Local dev**: `brew install vips` (macOS) or `apt-get install libvips-dev` (Ubuntu)

### S3 Path Structure

```
stores/
  {store_id}/
    products/
      {product_id}/
        originals/
          {uuid}.jpg
        thumbnail/
          {uuid}.webp
        medium/
          {uuid}.webp
```

### Storage Behaviour

```elixir
defmodule Emakola.Storage do
  @callback upload(binary(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  @callback delete(String.t()) :: :ok | {:error, term()}
  @callback presigned_url(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
end
```

Implementations: `Emakola.Storage.S3` (production), `Emakola.Storage.Local` (dev), Mox mock (test).

---

## Testing Strategy

### Unit Tests Per Resource

Each resource gets a dedicated test file testing:
- All attribute validations (required, constraints, types, formats)
- All action behavior (create, read, update, destroy, custom actions)
- Slug auto-generation and uniqueness
- Multi-tenancy isolation (store_id scoping)
- Business rules and invariants
- All edge cases listed per resource above

### Integration Tests

- **Full product lifecycle**: Category → Product → OptionTypes → OptionValues → Variants → Images → Activate → Archive
- **Variant-option matrix**: Create 2 sizes x 3 colors = 6 variants with correct option value linkages
- **Stock adjustment concurrency**: Parallel adjust_stock calls don't produce negative stock (verified via DB CHECK)
- **Product activation gate**: Fails without variants, succeeds with at least one
- **Category tree operations**: Create nested tree, query roots, query children, move subtrees
- **Multi-tenant isolation**: Store A's products invisible to Store B queries — tested on ALL resources including OptionType, OptionValue, Image
- **Cascade behaviors**: Delete product → variants, options, images cleaned up
- **Image processing pipeline**: Upload → Oban job → processed URLs populated

### Edge Case Tests

Per-resource edge cases documented above, plus:
- **Boundary tests**: Max variants per product, max images per product, max category depth
- **Concurrent operations**: Simultaneous stock adjustments, simultaneous product creation with same slug
- **Invalid state transitions**: archived → active (must fail), active → draft with existing orders (future consideration)
- **Data integrity**: Cross-store option value assignment, cross-product variant references
- **Unicode handling**: Product titles and category names in Akan, Hausa, Yoruba characters
- **Empty/whitespace inputs**: All string fields reject blank/whitespace-only values

### Factories (ExMachina)

| Factory | Key Attributes |
|---------|---------------|
| `store_factory` | name, slug, currency |
| `category_factory` | store_id, name, slug |
| `product_factory` | store_id, category, title, slug, status |
| `option_type_factory` | store_id, product_id, name |
| `option_value_factory` | store_id, option_type_id, value |
| `variant_factory` | product_id, store_id, price, sku, stock_quantity |
| `image_factory` | store_id, product_id, url, content_type |
| `product_with_variants_factory` | Composite: product + 1 option type + 2 values + 2 variants |

All factories accept `store_id` override for multi-tenant testing.

### Mocks

- **S3**: `Emakola.Storage` behaviour mocked via Mox in tests.
- **Image processing**: `image` library calls mocked — no actual libvips in test.

### Coverage Target

90%+ on all new Catalog code (resources, workers, storage).

---

## Build Sequence

### Step 1: Clean House (Phase 0)

1. Delete duplicate files (`lib/emakola 2.ex`, `lib/emakola_web 2.ex`)
2. Delete misnamed `store.ex` (contains duplicate Organisation module)
3. Overwrite `store_membership.ex` (currently contains `Membership` module — will be replaced with new `StoreMembership` resource in Step 1.5)
3. Remove FounderPad LiveView pages and their tests
4. Remove FounderPad controllers (CheckoutController, SitemapController)
5. Remove API route scopes and modules (GraphqlSchema, JsonApiRouter) — deps not installed
6. Strip router to essential routes
7. Add `/health` endpoint
8. Replace Phoenix branding in layouts
9. Update `mix.exs` elixir version to `~> 1.18`
10. Verify: `mix compile` + `mix test` + `mix format` + `mix credo`

### Step 1.5: Store Resource (Phase 0 prerequisite)

1. Create `Emakola.Accounts.Store` resource with currency attribute
2. Create `Emakola.Accounts.StoreMembership` resource
3. Register both in `Emakola.Accounts` domain
4. Generate and run migration
5. Create `store_factory` for tests
6. Verify Merchant → Store relationship works

### Step 2: Catalog Foundation (TDD)

1. Add new dependencies to `mix.exs`: `image`, `ex_aws`, `ex_aws_s3`, `sweet_xml`, `slugify`, `dialyxir`. Configure `ex_aws` HTTP client to use Finch.
2. Category resource + comprehensive tests
3. Product resource + comprehensive tests (including `HasVariants` validation module)
4. ExMachina factories for Category, Product

### Step 3: Options & Variants (TDD)

1. OptionType resource + tests
2. OptionValue resource + tests
3. Variant resource + tests (including DB CHECK constraint in migration)
4. VariantOptionValue join resource + tests
5. Factories for all option/variant resources

### Step 4: Images & Processing (TDD)

1. Storage behaviour + S3 implementation + mock
2. Image resource + tests
3. ImageProcessorWorker + tests (with mocked S3 and image processing)
4. Image factory
5. Update Dockerfile with `libvips-dev` installation

### Step 5: Domain Integration Tests

1. Full product lifecycle tests
2. Multi-tenant isolation tests (all resources)
3. Cascade behavior tests
4. Boundary and concurrent operation tests

### Step 6: Merchant Admin UI

> **Gate**: This step requires design prototypes to be created first (using Pencil MCP or Figma). No UI implementation begins without approved visual designs matching the target aesthetic.

1. Create design prototypes for all merchant admin pages
2. Product list/create/edit LiveView
3. Category management LiveView
4. Image upload component with progress
5. Inventory management view

---

## Dependencies

### New Hex Packages

| Package | Purpose |
|---------|---------|
| `image` | libvips-based image processing (resize, format conversion) |
| `ex_aws` | AWS SDK core |
| `ex_aws_s3` | S3 operations (upload, delete, presigned URLs) |
| `sweet_xml` | XML parsing required by ex_aws |
| `slugify` | URL-safe slug generation from Unicode strings (new explicit dependency) |
| `dialyxir` | Static type checking (dev/test only) |

**Note:** `ex_aws` requires an HTTP client adapter. The project already has `finch` as a transitive dependency via Phoenix/Bandit. Configure with: `config :ex_aws, :http_client, ExAws.Request.Finch` and ensure the Finch process is started in `application.ex`.

### Existing (Already in mix.exs)

- Ash 3.x, AshPostgres, AshAuthentication, AshPhoenix
- Oban (for image processing and cleanup workers)
- Phoenix LiveView (for merchant admin)
- TailwindCSS (for styling)
- ExMachina (already in deps, test only)
- Mox (already in deps, test only)

### System Dependencies

| Dependency | Required By | Install |
|------------|-------------|---------|
| libvips | `image` hex package | `brew install vips` (macOS), `apt-get install libvips-dev` (Debian), `apk add vips-dev` (Alpine) |
| PostgreSQL 15+ | AshPostgres | Already configured |

---

## Spec Review Fixes Applied

Issues found and resolved from automated spec review:

1. **Store resource missing** → Added Step 1.5 with full Store + StoreMembership spec
2. **Elixir version mismatch** → Updated mix.exs requirement to `~> 1.18`
3. **Missing deps** → Added `image`, `ex_aws`, `ex_aws_s3`, `slugify`, `dialyxir`; documented libvips system dep
4. **Store.currency unspecified** → Added currency attribute to Store resource spec
5. **OptionType/OptionValue missing store_id** → Added `store_id` to ALL catalog resources
6. **VariantOptionValue missing store_id** → Added `store_id` denormalized from variant
7. **activate validation Ash DSL bug** → Documented standalone `HasVariants` validation module requirement
8. **adjust_stock race condition** → Specified DB CHECK constraint + `atomic_update` approach
9. **GIF content type** → Excluded; documented LiveView upload as primary enforcement point
10. **API routes reference missing deps** → Added to Phase 0 removal list
11. **Step 6 design gate** → Documented design prototype prerequisite; added `dialyxir` to deps
