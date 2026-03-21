# Emakola API Documentation

## Overview

Emakola exposes three API layers:

1. **Ash-generated JSON:API** - Auto-generated CRUD endpoints from Ash resources
2. **Custom REST endpoints** - Webhooks, storefront-specific routes
3. **Phoenix Channels (WebSocket)** - Real-time order updates, inventory sync

All API responses use JSON. The base URL pattern is:

- Production: `https://api.emakola.com/api/v1`
- Staging: `https://staging-api.emakola.com/api/v1`
- Store-specific: `https://{store}.emakola.com/api/v1`

---

## Authentication

### Merchant Admin (Bearer Token)

Merchants authenticate via Ash Authentication, receiving a JWT on login.

```
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "merchant@example.com",
  "password": "secure_password"
}

Response:
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": "2026-04-21T00:00:00Z",
    "merchant_id": "uuid",
    "store_slug": "kwame-fashion"
  }
}
```

Include the token in subsequent requests:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

Token refresh:

```
POST /api/v1/auth/refresh
Authorization: Bearer {current_token}
```

### Storefront (Session or API Token)

- **Browser sessions**: Standard Phoenix session cookies (LiveView storefronts)
- **Headless/mobile**: Optional API token for custom storefront builds

```
GET /api/v1/products
X-Store-Token: {store_api_token}
```

### Webhook Signature Verification

All inbound webhooks are verified using HMAC-SHA512 signatures.

```elixir
# Paystack verification
signature = :crypto.mac(:hmac, :sha512, paystack_secret_key, raw_body)
|> Base.encode16(case: :lower)

if Plug.Crypto.secure_compare(signature, request_signature) do
  :ok
else
  {:error, :invalid_signature}
end
```

---

## Public Storefront API (Phase 4)

These endpoints are publicly accessible, scoped to a store by subdomain or `X-Store-Slug` header.

### Products

#### List Products

```
GET /api/v1/products
```

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `page_size` | integer | 20 | Items per page (max 50) |
| `category` | string | - | Filter by category slug |
| `search` | string | - | Full-text search on name/description |
| `min_price` | integer | - | Minimum price in pesewas/kobo |
| `max_price` | integer | - | Maximum price in pesewas/kobo |
| `sort` | string | `newest` | Sort: `newest`, `price_asc`, `price_desc`, `popular` |
| `in_stock` | boolean | - | Filter to in-stock only |

**Response:**

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Ankara Print Dress",
      "slug": "ankara-print-dress",
      "description": "Beautiful hand-crafted Ankara print dress...",
      "price": 15000,
      "currency": "GHS",
      "compare_at_price": 20000,
      "images": [
        {
          "url": "https://cdn.emakola.com/stores/kwame-fashion/products/ankara-dress-1.webp",
          "alt": "Ankara Print Dress - Front View",
          "position": 1
        }
      ],
      "category": {
        "id": "uuid",
        "name": "Dresses",
        "slug": "dresses"
      },
      "variants": [
        {
          "id": "uuid",
          "name": "Medium / Blue",
          "sku": "APD-M-BLU",
          "price": 15000,
          "stock_quantity": 12,
          "in_stock": true
        }
      ],
      "in_stock": true,
      "average_rating": 4.5,
      "review_count": 23,
      "created_at": "2026-03-15T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 20,
    "total_count": 247,
    "total_pages": 13
  }
}
```

#### Get Product Detail

```
GET /api/v1/products/:id_or_slug
```

Returns the full product including all variants, images, reviews summary, and related products.

### Categories

#### List Categories

```
GET /api/v1/categories
```

Returns a flat or nested category tree for the store.

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Clothing",
      "slug": "clothing",
      "product_count": 45,
      "image_url": "https://cdn.emakola.com/...",
      "children": [
        {
          "id": "uuid",
          "name": "Dresses",
          "slug": "dresses",
          "product_count": 18
        }
      ]
    }
  ]
}
```

### Cart

#### Create or Update Cart

```
POST /api/v1/cart
Content-Type: application/json

{
  "items": [
    {
      "variant_id": "uuid",
      "quantity": 2
    }
  ]
}
```

**Response:**

```json
{
  "data": {
    "id": "uuid",
    "token": "cart_abc123",
    "items": [
      {
        "variant_id": "uuid",
        "product_name": "Ankara Print Dress",
        "variant_name": "Medium / Blue",
        "quantity": 2,
        "unit_price": 15000,
        "line_total": 30000
      }
    ],
    "subtotal": 30000,
    "currency": "GHS",
    "item_count": 2
  }
}
```

Cart is identified by a `cart_token` cookie (browser) or returned token (API).

### Checkout

#### Initiate Checkout

```
POST /api/v1/checkout
Content-Type: application/json

{
  "cart_token": "cart_abc123",
  "customer": {
    "name": "Ama Mensah",
    "phone": "+233241234567",
    "email": "ama@example.com"
  },
  "shipping_address": {
    "line_1": "15 Oxford Street",
    "line_2": "Osu",
    "city": "Accra",
    "region": "Greater Accra",
    "country": "GH"
  },
  "payment_method": "mobile_money",
  "mobile_money_provider": "mtn",
  "shipping_method": "standard"
}
```

**Payment Methods:**

| Method | Code | Countries |
|--------|------|-----------|
| MTN Mobile Money | `mobile_money` + `mtn` | Ghana |
| Vodafone Cash | `mobile_money` + `vodafone` | Ghana |
| AirtelTigo Money | `mobile_money` + `airteltigo` | Ghana |
| Card (Visa/Mastercard) | `card` | All |
| Bank Transfer | `bank_transfer` | Nigeria |
| Opay | `opay` | Nigeria |

**Response:**

```json
{
  "data": {
    "order_id": "uuid",
    "order_number": "EM-2026-00147",
    "status": "pending_payment",
    "payment": {
      "provider": "paystack",
      "authorization_url": "https://checkout.paystack.com/abc123",
      "reference": "EMK_txn_abc123",
      "ussd_code": "*170*1*1*MERCHANT_CODE*AMOUNT#"
    },
    "total": 32500,
    "currency": "GHS"
  }
}
```

### Orders

#### Get Order Status

```
GET /api/v1/orders/:order_number?token=order_access_token
```

No authentication required, but requires the order access token (sent via SMS/WhatsApp).

```json
{
  "data": {
    "order_number": "EM-2026-00147",
    "status": "shipped",
    "status_history": [
      { "status": "pending_payment", "at": "2026-03-20T14:00:00Z" },
      { "status": "confirmed", "at": "2026-03-20T14:02:00Z" },
      { "status": "processing", "at": "2026-03-20T15:30:00Z" },
      { "status": "shipped", "at": "2026-03-21T09:00:00Z" }
    ],
    "tracking_number": "GHP1234567890",
    "estimated_delivery": "2026-03-23",
    "items": [...],
    "total": 32500,
    "currency": "GHS"
  }
}
```

---

## Merchant Admin API (Phase 4)

All endpoints require `Authorization: Bearer {token}`. Resources are automatically scoped to the authenticated merchant's store.

### Products

```
GET    /api/v1/admin/products              — List merchant's products
POST   /api/v1/admin/products              — Create product
GET    /api/v1/admin/products/:id          — Get product detail
PATCH  /api/v1/admin/products/:id          — Update product
DELETE /api/v1/admin/products/:id          — Soft-delete product
POST   /api/v1/admin/products/:id/images   — Upload product images
```

#### Create Product

```
POST /api/v1/admin/products
Content-Type: application/json
Authorization: Bearer {token}

{
  "product": {
    "name": "Kente Cloth Bag",
    "description": "Handwoven Kente cloth crossbody bag from Bonwire...",
    "category_id": "uuid",
    "price": 8500,
    "compare_at_price": 12000,
    "currency": "GHS",
    "sku": "KCB-001",
    "stock_quantity": 30,
    "weight_grams": 350,
    "tags": ["kente", "handmade", "bags"],
    "variants": [
      {
        "name": "Red/Gold",
        "sku": "KCB-001-RG",
        "price": 8500,
        "stock_quantity": 15
      },
      {
        "name": "Blue/Silver",
        "sku": "KCB-001-BS",
        "price": 9000,
        "stock_quantity": 15
      }
    ]
  }
}
```

### Orders

```
GET    /api/v1/admin/orders                — List orders (filterable)
GET    /api/v1/admin/orders/:id            — Order detail
PATCH  /api/v1/admin/orders/:id            — Update order status
POST   /api/v1/admin/orders/:id/refund     — Initiate refund
```

**Order Status Transitions:**

```
pending_payment → confirmed → processing → shipped → delivered
                                                   → returned
              → cancelled (from pending_payment or confirmed)
```

#### Update Order Status

```
PATCH /api/v1/admin/orders/:id
Content-Type: application/json
Authorization: Bearer {token}

{
  "order": {
    "status": "shipped",
    "tracking_number": "GHP1234567890",
    "shipping_provider": "ghana_post",
    "note": "Shipped via Ghana Post EMS"
  }
}
```

### Analytics

```
GET /api/v1/admin/analytics
```

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `period` | string | `30d` | Time period: `7d`, `30d`, `90d`, `12m`, `custom` |
| `start_date` | date | - | For custom period |
| `end_date` | date | - | For custom period |

**Response:**

```json
{
  "data": {
    "period": "30d",
    "revenue": {
      "total": 4500000,
      "currency": "GHS",
      "change_percent": 12.5
    },
    "orders": {
      "total": 187,
      "change_percent": 8.3,
      "average_value": 24064
    },
    "customers": {
      "total": 142,
      "new": 38,
      "returning": 104
    },
    "top_products": [
      {
        "product_id": "uuid",
        "name": "Ankara Print Dress",
        "units_sold": 45,
        "revenue": 675000
      }
    ],
    "payment_methods": {
      "mobile_money": { "count": 134, "amount": 3200000 },
      "card": { "count": 53, "amount": 1300000 }
    },
    "conversion_rate": 3.2
  }
}
```

---

## Webhook Endpoints

### Paystack Callbacks

```
POST /webhooks/paystack
```

Paystack sends events for payment status changes. Verified via `X-Paystack-Signature` header.

**Handled Events:**

| Event | Action |
|-------|--------|
| `charge.success` | Confirm order, send receipt via WhatsApp/SMS |
| `charge.failed` | Mark payment failed, notify customer |
| `transfer.success` | Mark merchant payout complete |
| `transfer.failed` | Alert merchant, retry payout |
| `refund.processed` | Update order, notify customer |

**Payload Example:**

```json
{
  "event": "charge.success",
  "data": {
    "reference": "EMK_txn_abc123",
    "amount": 3250000,
    "currency": "GHS",
    "channel": "mobile_money",
    "metadata": {
      "order_id": "uuid",
      "store_id": "uuid"
    }
  }
}
```

### Hubtel Callbacks

```
POST /webhooks/hubtel
```

Hubtel sends callbacks for mobile money transactions in Ghana.

**Handled Events:**

| Status | Action |
|--------|--------|
| `Success` | Confirm order, send receipt |
| `Failed` | Mark payment failed, prompt retry |
| `Pending` | Keep order in pending state |

### Flutterwave Callbacks

```
POST /webhooks/flutterwave
```

Flutterwave handles payments primarily for the Nigerian market.

**Handled Events:**

| Event | Action |
|-------|--------|
| `charge.completed` | Confirm order |
| `transfer.completed` | Mark payout complete |

---

## Rate Limiting

Rate limits are enforced per IP for public endpoints and per API token for authenticated endpoints.

| Endpoint Category | Limit | Window | Scope |
|-------------------|-------|--------|-------|
| Auth (login/register) | 5 requests | 15 min | Per IP |
| Storefront API | 100 requests | 1 min | Per IP |
| Admin API | 200 requests | 1 min | Per token |
| Webhooks | 1000 requests | 1 min | Per provider IP |
| Image uploads | 20 requests | 1 min | Per token |

**Rate Limit Headers:**

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1679414400
```

**Rate Limit Exceeded Response (429):**

```json
{
  "errors": [
    {
      "code": "RATE_LIMIT_EXCEEDED",
      "message": "Too many requests. Please retry after 45 seconds.",
      "retry_after": 45
    }
  ]
}
```

---

## Error Handling

### Error Response Format

All errors follow a consistent format:

```json
{
  "errors": [
    {
      "code": "VALIDATION_ERROR",
      "field": "email",
      "message": "is required"
    }
  ]
}
```

### Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | `BAD_REQUEST` | Malformed request body |
| 401 | `UNAUTHORIZED` | Missing or invalid auth token |
| 403 | `FORBIDDEN` | Insufficient permissions |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `CONFLICT` | Resource conflict (e.g., duplicate SKU) |
| 422 | `VALIDATION_ERROR` | Input validation failed |
| 429 | `RATE_LIMIT_EXCEEDED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Server error (logged, alerted) |
| 503 | `SERVICE_UNAVAILABLE` | Maintenance or overload |

### Validation Errors

Validation errors include the field name and a human-readable message:

```json
{
  "errors": [
    { "code": "VALIDATION_ERROR", "field": "phone", "message": "must be a valid Ghana or Nigeria phone number" },
    { "code": "VALIDATION_ERROR", "field": "price", "message": "must be greater than 0" }
  ]
}
```

---

## Pagination

All list endpoints use offset-based pagination:

```json
{
  "data": [...],
  "meta": {
    "page": 1,
    "page_size": 20,
    "total_count": 247,
    "total_pages": 13
  },
  "links": {
    "self": "/api/v1/products?page=1&page_size=20",
    "next": "/api/v1/products?page=2&page_size=20",
    "prev": null,
    "first": "/api/v1/products?page=1&page_size=20",
    "last": "/api/v1/products?page=13&page_size=20"
  }
}
```

---

## Currencies

All monetary values are stored and returned in the **smallest unit** of the currency (pesewas for GHS, kobo for NGN).

| Currency | Code | Smallest Unit | Example |
|----------|------|---------------|---------|
| Ghana Cedi | GHS | pesewas | 15000 = GH₵150.00 |
| Nigerian Naira | NGN | kobo | 250000 = ₦2,500.00 |

---

## Implementation Notes

### Ash JSON:API Auto-Generation

Most CRUD endpoints are auto-generated from Ash resource definitions:

```elixir
defmodule EmakolaWeb.Api.Router do
  use AshJsonApi.Router,
    domains: [Emakola.Catalog, Emakola.Orders, Emakola.Accounts],
    open_api: "/api/v1/openapi"
end
```

### Custom Endpoints

Webhook routes and analytics endpoints are standard Phoenix controllers:

```elixir
scope "/webhooks", EmakolaWeb.Webhooks do
  pipe_through [:webhook_auth]

  post "/paystack", PaystackController, :handle
  post "/hubtel", HubtelController, :handle
  post "/flutterwave", FlutterwaveController, :handle
end
```

### Real-Time (Phoenix Channels)

Merchants receive real-time order notifications via WebSocket:

```javascript
// Merchant dashboard
let channel = socket.channel(`store:${storeId}`, {})
channel.on("new_order", (order) => { /* update dashboard */ })
channel.on("payment_received", (payment) => { /* show notification */ })
channel.on("low_stock", (product) => { /* alert merchant */ })
```

Customers can track order status in real-time:

```javascript
// Order tracking page
let channel = socket.channel(`order:${orderNumber}`, { token: accessToken })
channel.on("status_update", (update) => { /* update tracking UI */ })
```
