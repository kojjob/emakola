# Emakola — Domain Model (Ash Resources)

## Bounded Contexts

### 1. Accounts (Multi-tenant core)
```
Merchant          — The person/business that owns stores
├── email, password_hash, name, phone
├── has_many :stores
└── has_one :subscription

Store             — A merchant's shop (tenant boundary)
├── name, slug, description, logo_url
├── custom_domain, subdomain
├── currency (:GHS, :NGN, :XOF)
├── timezone, locale
├── belongs_to :merchant
├── has_one :store_config
└── multitenancy: :context (all child resources scoped to store)

StoreConfig       — Store-level settings
├── theme_id, colors (JSONB), fonts
├── checkout_settings (JSONB)
├── notification_preferences (JSONB)
├── social_links (JSONB)
└── belongs_to :store
```

### 2. Catalog (Products & Inventory)
```
Product           — A sellable item
├── title, description, slug
├── status (:draft, :active, :archived)
├── product_type, vendor, tags (array)
├── has_many :variants
├── has_many :images
├── belongs_to :category
└── seo_title, seo_description

Variant           — Product variation (size/color combo)
├── sku, barcode
├── price (integer, minor units)
├── compare_at_price (for sales)
├── cost_price (merchant cost)
├── weight, dimensions
├── inventory_quantity
├── inventory_policy (:deny, :allow_backorder)
├── option_values (JSONB) — e.g., {"size": "M", "color": "Black"}
└── belongs_to :product

Category          — Product categorization
├── name, slug, description, image_url
├── parent_id (self-referential for hierarchy)
├── position (sort order)
└── has_many :products

Image             — Product images
├── url, alt_text, position
├── width, height
└── belongs_to :product
```

### 3. Orders
```
Order             — A customer purchase
├── order_number (auto-generated: EM-XXXX)
├── status (:pending, :confirmed, :processing, :shipped, :delivered, :cancelled)
├── payment_status (:pending, :paid, :partially_refunded, :refunded, :failed)
├── subtotal, shipping_total, tax_total, discount_total, total
├── currency
├── customer_email, customer_phone
├── note (customer note)
├── has_many :line_items
├── has_many :payments
├── has_one :shipping_address
├── has_one :billing_address
├── belongs_to :customer (optional — guest checkout)
└── belongs_to :discount (optional)

LineItem          — Individual item in an order
├── title, variant_title
├── quantity, unit_price, total_price
├── sku
├── belongs_to :order
├── belongs_to :variant
└── belongs_to :product

Payment           — Payment attempt/record
├── gateway (:paystack, :hubtel, :flutterwave, :cod)
├── method (:card, :mtn_momo, :vodafone_cash, :airtel_tigo, :bank_transfer, :cash)
├── status (:pending, :processing, :success, :failed, :refunded)
├── amount, currency
├── gateway_reference (external ID)
├── gateway_response (JSONB)
├── phone_number (for mobile money)
├── paid_at
└── belongs_to :order

Refund            — Order refund
├── amount, reason, note
├── status (:pending, :processed)
├── gateway_reference
├── belongs_to :order
└── belongs_to :payment
```

### 4. Customers
```
Customer          — Store customer (scoped to tenant)
├── email, phone, first_name, last_name
├── accepts_marketing (boolean)
├── order_count, total_spent
├── tags, segment (:new, :regular, :vip, :at_risk)
├── last_order_at
├── has_many :addresses
├── has_many :orders
└── has_one :account (optional login)

Address           — Customer address
├── first_name, last_name
├── address1, address2
├── city, region/state, postal_code
├── country (:GH, :NG, :SN, etc.)
├── phone
├── is_default (boolean)
└── belongs_to :customer
```

### 5. Shipping
```
ShippingZone      — Geographic shipping area
├── name (e.g., "Greater Accra", "Nationwide")
├── regions (array of region codes)
├── has_many :shipping_rates
└── belongs_to :store

ShippingRate       — Rate within a zone
├── name (e.g., "Standard", "Express")
├── price (integer, minor units)
├── min_order_amount (free shipping threshold)
├── estimated_days_min, estimated_days_max
├── carrier (optional)
└── belongs_to :shipping_zone

Fulfillment       — Shipment tracking
├── status (:pending, :picked_up, :in_transit, :delivered)
├── tracking_number
├── carrier
├── shipped_at, delivered_at
├── belongs_to :order
└── has_many :tracking_events (JSONB array)
```

### 6. Marketing
```
Discount          — Discount code or automatic discount
├── code (nil for automatic)
├── type (:percentage, :fixed_amount, :free_shipping, :buy_x_get_y)
├── value (percentage or amount)
├── minimum_purchase_amount
├── usage_limit, usage_count
├── starts_at, ends_at
├── applies_to (:all, :specific_products, :specific_categories)
├── product_ids (array), category_ids (array)
└── status (:active, :expired, :disabled)
```

### 7. Billing (Platform subscriptions)
```
Subscription      — Merchant's platform subscription
├── plan (:free, :growth, :pro, :enterprise)
├── status (:active, :past_due, :cancelled)
├── current_period_start, current_period_end
├── transaction_fee_percentage
├── belongs_to :merchant
└── payment_method (JSONB)

Invoice           — Platform billing invoice
├── amount, currency
├── status (:draft, :sent, :paid, :overdue)
├── period_start, period_end
├── line_items (JSONB)
├── paid_at
└── belongs_to :merchant
```

## Ash Multitenancy Setup

```elixir
# Every resource within a store is automatically scoped
defmodule Emakola.Catalog.Product do
  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer

  multitenancy do
    strategy :attribute
    attribute :store_id
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :description, :string
    attribute :status, :atom, constraints: [one_of: [:draft, :active, :archived]], default: :draft
    # ... more attributes
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store
    belongs_to :category, Emakola.Catalog.Category
    has_many :variants, Emakola.Catalog.Variant
    has_many :images, Emakola.Catalog.Image
  end
end
```
