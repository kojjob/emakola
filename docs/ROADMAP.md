# Emakola — Product Roadmap

## Phase 1: MVP (Ghana Launch)
**Goal**: Merchants can create a store, add products, and accept payments from Ghanaian customers.

### Milestone 1.1 — Foundation
- [ ] Phoenix app scaffold with Ash multitenancy
- [ ] Merchant registration & authentication
- [ ] Store creation with subdomain ({slug}.emakola.com)
- [ ] Store settings (name, logo, description, currency GHS)
- [ ] TDD test infrastructure

### Milestone 1.2 — Product Management
- [ ] Product CRUD (name, description, price, images)
- [ ] Product variants (size, color, material)
- [ ] Category management
- [ ] Inventory tracking (stock levels, low-stock alerts)
- [ ] Image upload with CDN delivery (S3 + Cloudflare)

### Milestone 1.3 — Storefront
- [ ] Mobile-first storefront template (based on Atelier prototypes)
- [ ] Product listing with filters (category, price, sort)
- [ ] Product detail page
- [ ] Search functionality
- [ ] SEO fundamentals (meta tags, structured data)

### Milestone 1.4 — Cart & Checkout
- [ ] Shopping cart (add, update qty, remove)
- [ ] Guest checkout (no account required)
- [ ] Customer accounts (optional)
- [ ] Address management
- [ ] Checkout flow (contact → shipping → payment)

### Milestone 1.5 — Payments (Ghana)
- [ ] Paystack integration (cards)
- [ ] MTN Mobile Money integration
- [ ] Vodafone Cash integration
- [ ] AirtelTigo Money integration
- [ ] Cash on delivery option
- [ ] Payment webhook handling
- [ ] Order confirmation

### Milestone 1.6 — Order Management
- [ ] Order list & detail (merchant admin)
- [ ] Order status workflow (pending → confirmed → shipped → delivered)
- [ ] SMS order notifications (via Hubtel)
- [ ] Basic email receipts
- [ ] Refund processing

### Milestone 1.7 — Merchant Dashboard
- [ ] Revenue overview (today, week, month)
- [ ] Order count & status breakdown
- [ ] Top products
- [ ] Recent orders table
- [ ] Basic analytics (visitors, conversion rate)

### Milestone 1.8 — PWA (Progressive Web App)
- [ ] Web app manifest (name, icons, theme color)
- [ ] Service worker for offline storefront caching
- [ ] "Add to Home Screen" prompt for merchants and customers
- [ ] Offline product browsing (cached catalog)
- [ ] App-like experience without Play Store

---

## Phase 2: Growth (Ghana)
**Goal**: Full-featured platform competitive with any ecommerce solution in Ghana.

### Milestone 2.1 — WhatsApp Integration
- [ ] WhatsApp Business API integration
- [ ] Order confirmation via WhatsApp
- [ ] Shipping update notifications
- [ ] Abandoned cart recovery messages
- [ ] Customer support chat

### Milestone 2.2 — Marketing Tools
- [ ] Discount codes & coupons
- [ ] Automatic discounts (buy X get Y, % off)
- [ ] Campaign management
- [ ] Abandoned cart recovery (WhatsApp + SMS)

### Milestone 2.3 — Shipping & Logistics
- [ ] Shipping zones & rates configuration
- [ ] Local courier integration (Korier, Ghana Post)
- [ ] Order tracking with live updates
- [ ] Pickup option (for local merchants)
- [ ] Delivery fee calculator

### Milestone 2.4 — Customer Experience
- [ ] Customer accounts & order history
- [ ] Wishlist / saved items
- [ ] Product reviews & ratings
- [ ] Recently viewed products
- [ ] Personalized recommendations (basic)

### Milestone 2.5 — Advanced Storefront
- [ ] Multiple theme templates (3-5 options)
- [ ] Theme customization (colors, fonts, layout)
- [ ] Custom pages (About, Contact, FAQ)
- [ ] Blog/content management
- [ ] Instagram catalog sync

### Milestone 2.6 — Platform Billing
- [ ] Subscription plans (Free, Growth, Pro)
- [ ] Transaction fee collection
- [ ] Usage-based billing
- [ ] Invoice generation
- [ ] Payment method management

---

## Phase 3: Nigeria Expansion
**Goal**: Launch in Nigeria with localized payments, logistics, and compliance.

- [ ] NGN currency support
- [ ] Nigerian payment gateways (Paystack NG, Flutterwave)
- [ ] Nigerian mobile money (OPay, PalmPay)
- [ ] Nigerian logistics (GIG, Kwik, Kobo360)
- [ ] Nigeria-specific regulatory compliance
- [ ] Localized onboarding & support
- [ ] Naira pricing for platform subscriptions

---

## Phase 4: Platform & Scale
**Goal**: Become the ecommerce infrastructure for West Africa.

- [ ] REST + GraphQL API (auto-generated from Ash)
- [ ] App/plugin marketplace
- [ ] Custom theme builder (drag-and-drop)
- [ ] Francophone West Africa (XOF — Senegal, Ivory Coast, Cameroon)
- [ ] Multi-language support (English, French, Hausa, Twi, Yoruba)
- [ ] Advanced analytics & AI recommendations
- [ ] B2B / wholesale features
- [ ] Multi-vendor marketplace mode
- [ ] POS integration for physical stores
