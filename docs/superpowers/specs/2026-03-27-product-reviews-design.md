# Product Reviews & Ratings Design

## Overview

Verified-purchase product reviews with star ratings. Customers who have received a delivered order containing the product can leave one review per product. Reviews auto-publish immediately. Merchants can hide inappropriate reviews from admin.

## Review Resource: `Emakola.Catalog.Review`

### Attributes
- `id` -- UUID primary key
- `store_id` -- UUID, required (multi-tenant)
- `product_id` -- UUID, required
- `customer_id` -- UUID, required
- `order_id` -- UUID, required (the delivered order that qualifies the review)
- `rating` -- integer, 1-5, required
- `title` -- string, max 100 chars, optional
- `body` -- string, max 2000 chars, required
- `status` -- atom, `:published` (default) or `:hidden`
- `verified_purchase` -- boolean, default true (always true, enforced at creation)
- `inserted_at`, `updated_at` -- timestamps

### Relationships
- `belongs_to :product, Emakola.Catalog.Product`
- `belongs_to :customer, Emakola.Customers.Customer`
- `belongs_to :store, Emakola.Accounts.Store`
- `belongs_to :order, Emakola.Orders.Order`

### Identity
- Unique constraint: `[:store_id, :product_id, :customer_id]` -- one review per customer per product per store

### Actions
- `:create` -- accepts rating, title, body, product_id, customer_id, order_id, store_id. Sets verified_purchase=true, status=:published.
- `:read` -- default
- `:hide` -- update action, sets status to :hidden
- `:unhide` -- update action, sets status to :published
- `list_by_product` -- read action filtered by product_id and status=:published, sorted by inserted_at desc
- `list_by_store` -- read action filtered by store_id, sorted by inserted_at desc (for admin, includes hidden)

### Policies
- Reads: open (published reviews are public)
- Creates: internal/system only (controller validates eligibility)
- Updates (hide/unhide): merchant with store access

## Eligibility Check

A customer can review a product if ALL of these are true:
1. Customer has a session (logged in via storefront)
2. Customer has at least one Order with status `:delivered` that contains a LineItem with a variant belonging to the product
3. Customer has NOT already reviewed this product (no existing Review with same customer_id + product_id)

This check is a function: `Emakola.Catalog.Review.eligible?(store_id, product_id, customer_id)` that returns `{:ok, order_id}` or `{:error, :not_eligible | :already_reviewed}`.

## Product Aggregates

Add to `Emakola.Catalog.Product`:
- `avg_rating` -- average of `review.rating` where `review.status == :published`
- `review_count` -- count of reviews where `review.status == :published`
- `has_many :reviews, Emakola.Catalog.Review`

## Migration

New `reviews` table:
- `id` UUID primary key
- `store_id` UUID NOT NULL references stores
- `product_id` UUID NOT NULL references products
- `customer_id` UUID NOT NULL references customers
- `order_id` UUID NOT NULL references orders
- `rating` integer NOT NULL
- `title` varchar(100)
- `body` varchar(2000) NOT NULL
- `status` varchar(20) NOT NULL DEFAULT 'published'
- `verified_purchase` boolean NOT NULL DEFAULT true
- `inserted_at`, `updated_at` timestamps
- UNIQUE INDEX on (store_id, product_id, customer_id)
- INDEX on (product_id, status) for listing queries
- INDEX on (store_id) for admin queries

## Storefront UI

### Review Components (`EmakolaWeb.ReviewComponents`)

Shared across all themes. Rendered inside product detail pages.

**`review_summary/1`** -- Shows average rating + count near the price area
- "4.2 out of 5 (12 reviews)" with filled/empty star icons
- Links to reviews section anchor

**`review_section/1`** -- Full reviews section below product details
- Header: "Customer Reviews" with avg rating + count
- Review form (if eligible): star selector, title input, body textarea, submit button
- "You purchased this product" badge
- Message if not eligible: "Purchase this product to leave a review" or "You've already reviewed this product"
- Reviews list: each review shows star rating, customer first name + last initial, relative time ("2 days ago"), title (bold), body text
- Empty state: "No reviews yet. Be the first to share your experience!"

**`star_rating/1`** -- Reusable star display (filled/half/empty stars)

**`star_selector/1`** -- Interactive clickable stars for the form (phx-click)

### Integration with Themes
Each theme's `product_detail.ex` adds `<ReviewComponents.review_section ... />` after the product info section. This is a single component call that handles everything.

### LiveView Events
- `submit_review` -- validates and creates the review
- `rate` with `phx-value-rating={n}` -- sets star rating in form state

## Admin UI

### Review Management (`EmakolaWeb.Admin.ReviewLive`)

Route: `/admin/reviews`

- Table: Product name, Customer name, Rating (stars), Title, Date, Status badge
- Filter by status: All, Published, Hidden
- Search by product name or customer name
- "Hide" / "Show" action button per review
- Link to view the product on storefront

## Testing Strategy

### Unit Tests
- Review creation with valid data succeeds
- Review creation fails without delivered order (not eligible)
- Review creation fails if already reviewed (duplicate)
- Rating must be 1-5
- Body is required, max 2000 chars
- Eligibility check returns correct order_id when eligible
- Eligibility check returns error when not eligible
- Hide/unhide toggle works
- Product avg_rating and review_count aggregates are correct
- Aggregates only count published reviews (not hidden)

### LiveView Tests
- Review section renders on product detail
- Eligible customer sees review form
- Non-eligible customer sees "purchase to review" message
- Submitting review creates it and updates the list
- Admin review list shows all reviews
- Admin can hide/unhide reviews

### Multi-tenant
- Reviews scoped to store_id
- Customer in store A cannot see reviews from store B
