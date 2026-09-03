# Makola storefront SEO architecture

This file describes the implemented SEO surface. For the dated audit, rollout
priorities, and current search/AI-search guidance, see
[`SEO_AI_SEARCH_AUDIT_2026-07-29.md`](SEO_AI_SEARCH_AUDIT_2026-07-29.md).

## Canonical URL model

`EmakolaWeb.SEO.Canonical` is the single source of truth for public URLs.

- With `STORE_SUBDOMAIN_BASE=makola.io`, a store is canonical at
  `https://{store}.makola.io`.
- Before subdomains are activated, the canonical falls back to
  `https://{PHX_HOST}/s/{store}`.
- Request hosts never decide canonicals. A path URL, store subdomain, or custom
  domain therefore emits one canonical URL rather than splitting authority.

Public storefront paths:

```text
/                              store home
/products                      product index
/products/{slug}               product detail
/category/{slug}               category
/about                         merchant about page
/contact                       merchant contact page
/faq                           merchant FAQ
/policies                      merchant policies
/blog and /blog/{slug}         articles
/recipes and /recipes/{slug}   recipes
/p/{slug}                      custom page
```

Cart, checkout, authentication, account, wishlist, saved-store, tracking, order
confirmation, onboarding, merchant admin, and platform admin pages emit
`noindex, nofollow`. They remain crawlable where needed so a crawler can read
the directive; blocking a URL in `robots.txt` is not a substitute for `noindex`.

## Page metadata

The root layout renders the assigned:

- title and meta description
- canonical URL
- robots directive
- Open Graph and X/Twitter metadata
- JSON-LD

Merchant `seo_title` and `seo_description` fields are used when present.
Otherwise pages use readable catalog or content fallbacks. Empty collection,
category, blog, recipe, FAQ, and blockless custom pages are `noindex` and are
not listed in sitemaps.

## Structured data

Implemented schema includes:

- `Product` with canonical product and offer URLs, seller, price, currency, and
  inventory-aware availability
- `OnlineStore` identity for online-only merchants and `LocalBusiness` only
  when a merchant has supplied a physical street address
- `Article`
- `Recipe`
- `FAQPage` where valid questions and answers exist
- `BreadcrumbList` with absolute canonical URLs

Structured data must match visible page content. It is not a place to add
claims, reviews, shipping promises, or availability that the application
cannot verify.

## Discovery endpoints

The apex `/sitemap.xml` is a sitemap index: `/sitemap-platform.xml` (marketing
pages, blog, region pages) plus one entry per live shop's sitemap. Submitting
the apex sitemap in Search Console therefore covers every shop.

Each store exposes:

```text
/s/{store}/sitemap.xml
/s/{store}/robots.txt
/s/{store}/feed/products.xml
/s/{store}/llms.txt
```

The equivalent sitemap, robots, and llms endpoints are available at a store
subdomain root when subdomains are active. `/feed/instagram.xml` remains as a
backward-compatible alias for the product feed.

The sitemap contains only active products and nonempty public content, with
recipes routed under `/recipes`, articles under `/blog`, and published custom
pages under `/p`.

The RSS product feed is compatible with the Google Merchant product-feed shape.
It includes only active products with an image and variant. Availability honors
the `available`, `track_inventory`, and `stock_quantity` fields.

`llms.txt` is an experimental convenience summary. It is returned with
`X-Robots-Tag: noindex`, is not a Google ranking mechanism, and does not replace
normal HTML pages, structured data, sitemaps, or product feeds.

## Crawler policy

Public products and content are allowed for standard search crawlers and
AI-search discovery. `OAI-SearchBot` is explicitly allowed for ChatGPT Search.
`GPTBot` is a separate model-training control, and `Google-Extended` is separate
from Google Search. Private download and authentication endpoints remain
disallowed.

## Operational checks

After production DNS and TLS are ready:

1. Set `PHX_HOST` and, after wildcard TLS is working,
   `STORE_SUBDOMAIN_BASE`.
2. Verify the apex property in Google Search Console and Bing Webmaster Tools.
3. Submit the apex sitemap and validate representative store sitemaps.
4. Connect eligible stores' `/feed/products.xml` endpoints to Google Merchant
   Center and monitor feed diagnostics.
5. Test representative Product, Article, Recipe, merchant-identity, and
   breadcrumb pages with Google's tools.
6. Monitor indexed pages, crawl errors, rich-result warnings, referrals, and
   conversions—not only rankings.
