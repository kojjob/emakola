# Emakola — MVP Specification (Phase 1)

## Scope

The MVP enables a Ghanaian merchant to:
1. Sign up and create a store
2. Add products with images and variants
3. Have a working mobile-first storefront
4. Accept payments (cards + mobile money)
5. Manage orders with SMS notifications
6. See basic analytics

**Out of scope for MVP**: WhatsApp integration, shipping integration, discount codes, themes, customer accounts, blog, multi-language, Nigeria.

## User Stories

### Merchant Registration
```
As a merchant,
I want to sign up with my email and phone number
So that I can create my online store

Acceptance Criteria:
- Sign up with email, password, phone, business name
- Email verification
- Phone verification via SMS (OTP)
- Redirect to store setup wizard after verification
```

### Store Creation
```
As a merchant,
I want to set up my store with a name and subdomain
So that customers can find my shop online

Acceptance Criteria:
- Choose store name and subdomain ({slug}.emakola.com)
- Upload store logo
- Set store description
- Select currency (GHS default)
- Select business category
- Store is live immediately after setup
```

### Product Management
```
As a merchant,
I want to add, edit, and organize my products
So that customers can browse and buy them

Acceptance Criteria:
- Create product with title, description, price, images
- Add variants (size, color) with individual prices and stock
- Organize into categories
- Set product status (draft/active/archived)
- Upload multiple images with drag-and-drop
- Set inventory quantities with low-stock threshold
```

### Storefront
```
As a customer,
I want to browse products on a merchant's store
So that I can find and buy what I need

Acceptance Criteria:
- Mobile-first responsive design
- Product listing with grid view
- Filter by category
- Sort by price, newest
- Product detail with images, variants, add to cart
- Search products by name
- Page loads < 3s on 3G
```

### Cart & Checkout
```
As a customer,
I want to add items to my cart and checkout
So that I can complete my purchase

Acceptance Criteria:
- Add to cart, update quantity, remove
- Cart persists across pages (LiveView assigns or session)
- Guest checkout (no account required)
- Enter shipping address (Ghana regions)
- Select payment method
- Review order before payment
- Mobile-optimized checkout (single column, large touch targets)
```

### Payment Processing
```
As a customer,
I want to pay with my preferred method
So that I can complete my order

Acceptance Criteria:
- Pay with credit/debit card (via Paystack)
- Pay with MTN Mobile Money
- Pay with Vodafone Cash
- Pay with AirtelTigo Money
- Select Cash on Delivery
- Mobile money: show "Waiting for payment" screen with polling
- Redirect to order confirmation on success
- Handle payment failures gracefully
```

### Order Management
```
As a merchant,
I want to view and manage orders
So that I can fulfill customer purchases

Acceptance Criteria:
- Order list with status filters
- Order detail with items, customer info, payment info
- Update order status (confirmed → processing → shipped → delivered)
- Mark COD orders as paid when delivered
- Send SMS notification on status change
- View payment details and gateway reference
```

### Dashboard
```
As a merchant,
I want to see how my store is performing
So that I can make informed decisions

Acceptance Criteria:
- Today's revenue, orders, visitors
- Revenue chart (last 30 days)
- Recent orders list
- Top products by revenue
- Low stock alerts
```

## Technical Requirements

### Performance
- Storefront pages: < 3s load on 3G connection
- Admin pages: < 2s load on 4G connection
- LiveView WebSocket reconnection: < 5s
- Image optimization: WebP, lazy loading, srcset

### Security
- HTTPS everywhere
- CSRF protection (Phoenix default)
- Strong parameters (Ash input validation)
- Rate limiting on authentication endpoints
- PCI compliance via Paystack (we never touch card data)
- Webhook signature verification

### Testing
- Minimum 90% test coverage
- TDD for all business logic
- Integration tests for payment flows (mocked)
- LiveView tests for critical user journeys
- Load testing for 100 concurrent checkouts

### Infrastructure
- PostgreSQL with connection pooling
- S3-compatible storage for images
- CDN for static assets and images
- Background job processing (Oban) for:
  - SMS sending
  - Payment webhook processing
  - Image processing/resizing
  - Low-stock alert checking
  - Analytics event processing
