# Emakola — Storefront SEO Strategy

## Architecture Advantage
LiveView is server-rendered by default — all content is crawlable without JavaScript. This is a major SEO advantage over SPA frameworks.

## URL Structure
```
{store}.emakola.com/                        → Homepage
{store}.emakola.com/products                → All products
{store}.emakola.com/products/{slug}         → Product detail
{store}.emakola.com/collections/{slug}      → Category page
{store}.emakola.com/cart                    → Cart (noindex)
{store}.emakola.com/checkout                → Checkout (noindex)
{store}.emakola.com/pages/{slug}            → Custom pages (About, FAQ)
{store}.emakola.com/blog/{slug}             → Blog posts (Phase 2)
```

## Meta Tags (per page)
```heex
<.head>
  <title><%= @page_title %> | <%= @store.name %></title>
  <meta name="description" content={@meta_description} />
  <link rel="canonical" href={@canonical_url} />

  <!-- Open Graph -->
  <meta property="og:title" content={@page_title} />
  <meta property="og:description" content={@meta_description} />
  <meta property="og:image" content={@og_image} />
  <meta property="og:type" content={@og_type} />
  <meta property="og:url" content={@canonical_url} />

  <!-- Product specific -->
  <%= if @product do %>
    <meta property="product:price:amount" content={format_price(@product.price)} />
    <meta property="product:price:currency" content={to_string(@store.currency)} />
  <% end %>
</.head>
```

## Structured Data (JSON-LD)

### Product Pages
```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Kente Cloth Dress",
  "image": ["https://cdn.emakola.com/..."],
  "description": "Handwoven authentic kente cloth dress",
  "brand": { "@type": "Brand", "name": "Accra Fashion Hub" },
  "offers": {
    "@type": "Offer",
    "price": "150.00",
    "priceCurrency": "GHS",
    "availability": "https://schema.org/InStock",
    "url": "https://accra-fashion.emakola.com/products/kente-cloth-dress"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.8",
    "reviewCount": "124"
  }
}
```

### Organization (Homepage)
```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Accra Fashion Hub",
  "url": "https://accra-fashion.emakola.com",
  "logo": "https://cdn.emakola.com/.../logo.png",
  "contactPoint": { "@type": "ContactPoint", "telephone": "+233...", "contactType": "customer service" }
}
```

## XML Sitemap
Auto-generated per store at `{store}.emakola.com/sitemap.xml`:
- Updated on product create/update/delete via Oban job
- Includes: homepage, products, categories, custom pages
- Excludes: cart, checkout, account pages

## Performance Targets (Core Web Vitals)
| Metric | Target | How |
|--------|--------|-----|
| LCP | < 2.5s | Optimized images (WebP + srcset), CDN, preload critical fonts |
| FID/INP | < 100ms | LiveView = minimal JS, server handles interactions |
| CLS | < 0.1 | Explicit image dimensions, font-display: swap, skeleton loaders |

## Image Optimization
```elixir
# On upload, generate multiple sizes via Oban worker:
# thumbnail: 150x150 (product cards)
# medium: 600x600 (product detail)
# large: 1200x1200 (zoom)
# Format: WebP with JPEG fallback
# CDN: Cloudflare with immutable cache headers
```
