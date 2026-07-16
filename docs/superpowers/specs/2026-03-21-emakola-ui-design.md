# Emakola — UI/UX Design Specification

**Date**: 2026-03-21
**Status**: Approved
**Author**: Kojo + Claude

---

## Context

Emakola is a Shopify-like ecommerce platform for West Africa, launching in Ghana first. Target merchants are Instagram/WhatsApp sellers with < 20 products who need a proper online store. The platform must feel professional and trustworthy while working on 3G connections. This spec defines the visual identity, UX patterns, and design system for both the merchant admin and customer-facing storefront.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform personality | **Clean & Professional** | Platform disappears, merchant's brand is the star |
| Admin color application | **Green Sidebar Accent** | Dark emerald nav anchor, clean white content area |
| Default storefront theme | **Story-Led** | Matches Instagram merchants selling through storytelling |
| Checkout flow | **Payment Method First** | Familiar MoMo/Telecel logos build trust before form input |
| Admin mobile strategy | **Hybrid** | Mobile for quick actions (orders/notifications), desktop for full management |
| Storefront visual style | **Instagram-Native** | Circle avatar, story categories, card products — patterns users know |

---

## 1. Merchant Admin (Desktop)

### Layout
- **Dark emerald sidebar** (#064E3B) — left, 260px wide, icon + label navigation
- **White content area** — #FFFFFF surface, #F8FAFC card backgrounds
- **Top bar** — search, notifications bell, date range, merchant avatar
- Sidebar collapses to icon-only (56px) on smaller screens

### Sidebar Navigation
```
[Logo: Emakola icon]
─────────────────────
MAIN
  Dashboard        (active: white text, left border #059669)
  Products
  Orders           (badge: pending count)
  Customers
─────────────────────
MARKETING
  Discounts        (Phase 2)
  Campaigns        (Phase 2)
─────────────────────
ANALYTICS
  Reports
  Revenue
─────────────────────
  Settings
  [Merchant avatar + name]
```

### Color Usage in Admin
- **#059669** (Emakola Green): logo, primary action buttons ("Add Product", "Save"), positive trend indicators (+12.5%), active sidebar item, success toasts
- **#064E3B** (Dark Emerald): sidebar background, hover states on sidebar
- **#0F172A** (Near Black): headings, large numbers (revenue, order count)
- **#475569** (Slate): body text, descriptions
- **#94A3B8** (Muted): labels, placeholders, timestamps
- **#E2E8F0** (Border): card borders, dividers, input borders
- **#CA8A04** (Gold): warnings, attention states
- **#F43F5E** (Coral): errors, destructive actions, negative trends

### Key Admin Pages
1. **Dashboard**: KPI cards (revenue, orders, customers, conversion), revenue line chart, recent orders table, top products, activity feed
2. **Products**: grid/list toggle, filters (category, status, stock), bulk actions, image-first product cards
3. **Orders**: filter bar (status, date, payment), orders table with status badges, bulk status update
4. **Customers**: customer table with segment badges (VIP, Regular, New, At Risk), order history
5. **Settings**: store info form, notification toggles, team members, payment configuration, shipping zones

---

## 2. Merchant Admin (Mobile — Quick Actions)

### Purpose
Lightweight companion for on-the-go order management. NOT a full admin.

### Mobile Screens
- **Bottom tab bar**: Home, Orders, Notifications
- **Home tab**: Today's revenue, today's orders, quick stats
- **Orders tab**: Order list with swipe-to-update-status, tap for detail
- **Notifications tab**: New orders, low stock alerts, payment confirmations

### What's NOT on Mobile
- Product management (adding, editing, images)
- Store settings and configuration
- Analytics and reports (beyond basic daily stats)
- Customer management
- Marketing tools

### Push Notifications
- New order placed → tap opens order detail
- Payment received (MoMo confirmed) → tap opens order
- Low stock alert → shows product name and count
- New customer signup → informational

---

## 3. Storefront (Default Theme — "Instagram-Native")

### Structure
```
┌─────────────────────────────┐
│ [○ Avatar] Store Name       │  ← Circle avatar + name + status
│            ● Open now   BAG │
├─────────────────────────────┤
│ (○ New) (○ Dresses) (○ Bags)│  ← Story-style category circles
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │     FEATURED PRODUCT    │ │  ← Hero card: image + description
│ │     IMAGE               │ │
│ │  Kente Wrap Dress       │ │
│ │  Handwoven in Bonwire   │ │
│ │  GH₵ 280    [Add to Bag]│ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ SHOP ALL                    │
│ ┌──────┐ ┌──────┐          │  ← 2-col product grid
│ │ img  │ │ img  │          │
│ │ Name │ │ Name │          │
│ │ GH₵  │ │ GH₵  │          │
│ └──────┘ └──────┘          │
├─────────────────────────────┤
│ ABOUT                       │  ← Merchant's story
│ "We are a small business..."│
├─────────────────────────────┤
│ [WhatsApp Chat Button]  ○   │  ← Floating bottom-right
└─────────────────────────────┘
```

### Storefront Customization (Merchant Controls)
- **Primary color**: merchant picks during store setup (overrides button colors, active states)
- **Logo/Avatar**: upload circle image or use initials
- **Store name and tagline**
- **Category names and images** (story circles)
- **Featured product selection**
- **About text and image**
- **WhatsApp number** (for chat button)
- **Social links** (Instagram, Twitter/X)

### Storefront Pages
1. **Home**: avatar + categories + featured product + product grid + about
2. **Product Detail**: large image(s), description, variant selector, "Add to Bag", share button, WhatsApp inquiry link
3. **Cart**: item list, quantity controls, order summary, "Checkout" button
4. **Checkout**: payment-first flow (see below)
5. **Order Confirmation**: order number, SMS/WhatsApp notification confirmation, "Track via WhatsApp" link

---

## 4. Checkout Flow (Payment-First)

### Step 1: Choose Payment Method
```
┌─────────────────────────────┐
│ HOW WOULD YOU LIKE TO PAY?  │
│                             │
│ ┌─────────────────────────┐ │
│ │ [MTN] MTN Mobile Money  │ │  ← Big branded cards
│ │       Pay with MoMo     │ │     Active: green border + check
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ [VOD] Telecel Cash     │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ [💳] Card Payment       │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ [🏠] Cash on Delivery   │ │
│ └─────────────────────────┘ │
│                             │
│ [Continue → Enter Details]  │
└─────────────────────────────┘
```

### Step 2: Contact + Delivery
- Phone number (required — used for SMS updates)
- Full name
- Delivery address (region dropdown for Ghana)
- Optional: email for receipt

### Step 3: Confirm & Pay
- Order summary (items, quantities, prices)
- Delivery fee
- Total

**Per payment method:**
- **MTN MoMo**: Branded MTN yellow UI, phone number input, "Confirm — You'll get a prompt on your phone", waiting state with spinner
- **Telecel Cash**: Branded Telecel red UI, same flow as MoMo
- **Card**: Redirect to Paystack hosted checkout page (PCI compliant)
- **Cash on Delivery**: Confirm order, show "Pay GH₵ X when your order arrives"

### Trust Signals (throughout checkout)
- Lock icon + "Secure checkout" text
- Payment provider logos
- Store name + logo visible at all times
- Clear "You'll get a prompt" messaging for MoMo (reduces anxiety)
- SMS confirmation message displayed: "You'll receive an SMS to +233..."

---

## 5. Design Tokens

### Colors
```css
/* Admin */
--admin-sidebar-bg: #064E3B;
--admin-sidebar-hover: #065F46;
--admin-sidebar-active-text: #FFFFFF;
--admin-sidebar-active-border: #059669;
--admin-sidebar-text: rgba(255, 255, 255, 0.6);
--admin-sidebar-icon: rgba(255, 255, 255, 0.4);

/* Brand */
--primary: #059669;
--primary-dark: #064E3B;
--primary-light: #D1FAE5;

/* Surfaces */
--surface: #FFFFFF;
--background: #F8FAFC;
--background-warm: #FAFAF9;

/* Text */
--text-primary: #0F172A;
--text-secondary: #475569;
--text-muted: #94A3B8;

/* Borders */
--border: #E2E8F0;
--border-light: #F1F5F9;

/* Semantic */
--success: #059669;
--warning: #CA8A04;
--error: #F43F5E;
--info: #3B82F6;

/* Payment Method Brands */
--mtn-yellow: #FFC107;
--vodafone-red: #E60000;
--airteltigo-blue: #1E40AF;
```

### Typography
```css
--font-ui: 'Inter', system-ui, sans-serif;
--font-mono: 'JetBrains Mono', monospace;

/* Scale */
--text-xs: 0.75rem;    /* 12px — labels, badges */
--text-sm: 0.875rem;   /* 14px — body, descriptions */
--text-base: 1rem;     /* 16px — default body */
--text-lg: 1.125rem;   /* 18px — section headings */
--text-xl: 1.25rem;    /* 20px — page headings */
--text-2xl: 1.5rem;    /* 24px — KPI numbers */
--text-3xl: 1.875rem;  /* 30px — hero text */
```

### Spacing & Radius
```css
--radius-sm: 8px;      /* inputs, small cards */
--radius-md: 12px;     /* cards, buttons */
--radius-lg: 16px;     /* modals, large cards */
--radius-xl: 20px;     /* hero sections, featured cards */
--radius-full: 9999px; /* pills, avatars, story circles */
```

### Performance Budget
```
Storefront page weight (3G target):
  HTML: < 30KB
  CSS (Tailwind): < 50KB (purged)
  JS (LiveView): < 30KB
  Images: lazy loaded, WebP, srcset
  Total first paint: < 150KB
  Target: < 3s load on 3G (300kbps)

Admin page weight (4G target):
  Same HTML/CSS/JS constraints
  Target: < 2s load on 4G
```

---

## 6. Component Library (Key Components)

### Shared (Admin + Storefront)
- Button: primary (green), secondary (outline), destructive (red), ghost
- Input: text, select, textarea — consistent border-slate-200, rounded-md, focus:ring-green
- Badge: status (success/warning/error/info), category, count
- Toast: success (green), error (red), info (blue) — top-right, auto-dismiss 5s
- Modal: centered, backdrop blur, responsive max-width
- Loading: skeleton screens (not spinners) for content, spinner for actions

### Admin-Specific
- KPI Card: icon, label, value (mono font), trend badge
- Data Table: sortable headers, row hover, status badges, pagination
- Sidebar Link: icon + label + optional badge, active state with green border
- Chart: SVG line/area charts, donut charts — hand-crafted, no library dependencies

### Storefront-Specific
- Product Card: image (aspect-4/3), name, price, "Add to Bag"
- Story Circle: avatar circle with colored ring, label below
- Featured Product Card: large image, title, description, price, CTA
- Cart Item: thumbnail, name, variant, qty stepper, price, remove
- Payment Method Card: provider logo, name, description, selectable with green border
- WhatsApp FAB: floating action button, bottom-right, green (#25D366)

---

## 7. Accessibility Requirements

- WCAG 2.1 AA minimum (AAA for text contrast)
- All images: alt text
- All inputs: associated labels
- All interactive elements: focus-visible:ring-2
- Touch targets: minimum 44x44px
- Color is never the only indicator
- prefers-reduced-motion: disable animations
- Screen reader: proper heading hierarchy, ARIA labels on icon-only buttons
- Keyboard: full tab navigation, Enter/Space activation

---

## 8. Files to Create

### Prototypes (new, Emakola-branded)
1. `design/prototypes/emakola-admin-dashboard.html` — Merchant admin dashboard
2. `design/prototypes/emakola-admin-orders.html` — Orders management
3. `design/prototypes/emakola-admin-products.html` — Product management
4. `design/prototypes/emakola-storefront-home.html` — Instagram-native store homepage
5. `design/prototypes/emakola-storefront-product.html` — Product detail page
6. `design/prototypes/emakola-checkout.html` — Payment-first checkout flow
7. `design/prototypes/emakola-admin-mobile.html` — Mobile quick-actions view

### Design System
8. `design/design-system/emakola/MASTER.md` — Updated with final tokens and patterns
