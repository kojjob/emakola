# SEO and AI-search audit — 2026-07-29

## Executive finding

Makola already had a stronger technical SEO foundation than a typical
multi-tenant commerce application: server-rendered LiveView pages, canonical URL
helpers, dynamic sitemaps, structured data, merchant content pages, and a
product feed.

This audit fixed the highest-impact correctness gaps. The largest remaining
upside is now operational and editorial: publish complete product facts, earn
merchant and product mentions, activate webmaster and merchant tools, and
measure discovery through to sales. There is no separate “AI SEO” schema or
shortcut that replaces those fundamentals.

## What this audit changed

### Indexing and crawl controls

- Added a shared `NoIndex` hook and applied it to customer auth, cart, checkout,
  account, downloads, wishlist, saved stores, tracking, confirmation,
  onboarding, merchant auth/admin, and platform admin surfaces.
- Stopped blocking transactional HTML pages whose `noindex` directive crawlers
  need to read. Sensitive download and auth endpoints remain disallowed.
- Added an explicit `OAI-SearchBot` policy for ChatGPT Search and corrected
  comments that conflated search discovery with `GPTBot` or `Google-Extended`.
- Marked `llms.txt` responses `noindex`.

### Canonicals, metadata, and structured data

- Activated merchant SEO titles on product, article, and recipe detail pages.
- Added complete metadata and canonicals to merchant about, contact, FAQ,
  policies, and custom pages.
- Identified online-only merchants as `OnlineStore`; `LocalBusiness` is now used
  only when a merchant supplies a physical street address, and currency is no
  longer treated as proof of country.
- Made empty product/content hubs and empty category/FAQ/custom pages
  non-indexable.
- Fixed Product offer availability for inventory that is intentionally
  untracked.
- Added canonical product and offer URLs plus seller data to Product JSON-LD.
- Replaced relative breadcrumb URLs with absolute canonical URLs.

### Sitemaps and commerce feeds

- Removed empty hubs and categories from store sitemaps.
- Fixed recipe URLs so they no longer appear under `/blog`.
- Added nonempty published custom pages and avoided duplicate home content.
- Added `/feed/products.xml` while retaining `/feed/instagram.xml` as an alias.
- Made feed links canonical, corrected untracked-inventory availability, and
  excluded items missing the minimum image/variant data.

### AI-generated content safeguards

- Product-description prompts now use only supplied title, notes, and tags and
  explicitly prohibit invented attributes, claims, delivery terms, returns, or
  warranties.
- Sparse source data produces short copy instead of padded generic text.
- Blog prompts are explicitly human-review drafts and use placeholders where
  first-hand merchant experience is required.
- The SEO dashboard now truthfully says descriptions and alt text are saved
  directly and must be reviewed afterward.

## Current guidance that shapes the strategy

Google says its normal SEO fundamentals apply to AI Overviews and AI Mode: make
pages crawlable, indexable, internally linked, useful, and consistent with
visible structured data. It says no special AI schema or machine-readable AI
file is required. Google also says `llms.txt` is not used by its generative AI
features. See [Google's generative AI optimization
guide](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
and [AI features and your
website](https://developers.google.com/search/docs/appearance/ai-features).

For commerce, Google recommends using both Product structured data and a
Merchant Center feed because the combination maximizes eligibility and helps it
understand inventory. See [Product structured
data](https://developers.google.com/search/docs/appearance/structured-data/product)
and [merchant listing structured
data](https://developers.google.com/search/docs/appearance/structured-data/merchant-listing).

Google defines the address in `LocalBusiness` markup as the physical location
of that business and recommends it for physical stores. Schema.org separately
defines `OnlineStore` for ecommerce sites. See [Google's LocalBusiness
documentation](https://developers.google.com/search/docs/appearance/structured-data/local-business)
and [Schema.org OnlineStore](https://schema.org/OnlineStore).

Google documents that a `noindex` directive only works when the crawler can
access the page. See [robots meta tag
rules](https://developers.google.com/search/docs/crawling-indexing/robots-meta-tag).

OpenAI distinguishes `OAI-SearchBot`, which controls eligibility for ChatGPT
Search discovery, from `GPTBot`, which controls potential model training.
ChatGPT search referrals include `utm_source=chatgpt.com`. See OpenAI's
[publisher and developer
FAQ](https://help.openai.com/en/articles/12627856-publishers-and-developers-faq)
and [ChatGPT Search
guide](https://help.openai.com/en/articles/9237897-chatgpt-search).

OpenAI's shopping guidance emphasizes price, availability, quality, and whether
the seller is the maker or primary seller. OpenAI also offers a separate path
for merchants and commerce platforms to provide direct product feeds. Makola's
Google-format XML feed should not be presented as an OpenAI feed unless OpenAI
accepts and validates it through that program. See [Shopping with ChatGPT
Search](https://help.openai.com/en/articles/11128490-shopping-with-chatgpt-search).

## Recommended rollout

### P0 — production activation

1. Complete apex and wildcard DNS/TLS before setting `PHX_HOST=makola.io` and
   `STORE_SUBDOMAIN_BASE=makola.io`.
2. Verify Makola in Google Search Console and Bing Webmaster Tools. Submit the
   platform sitemap and validate representative store sitemaps.
3. Confirm the CDN/WAF permits published `OAI-SearchBot` traffic and does not
   challenge legitimate search crawlers.
4. Connect eligible merchant feeds to Google Merchant Center and monitor
   rejected items, price mismatches, image failures, and stale availability.
5. Apply to OpenAI's merchant/product-feed program as the commerce platform;
   treat acceptance and required feed format as a separate integration.

### P1 — improve the underlying commerce data

1. Add structured catalog fields for brand and standard identifiers such as
   GTIN/MPN where merchants have them. Do not manufacture identifiers.
2. Model shipping regions, costs, delivery estimates, and return policies so
   they can be shown visibly and represented consistently in feeds and
   structured data.
3. Improve image quality, alt text, and variant completeness. Product-feed
   eligibility currently requires at least one image and one variant.
4. Build merchant editing/review into the AI bulk workflow before expanding
   automated generation. The current worker saves directly by design.
5. Publish first-hand merchant material: buying advice, care instructions,
   origin stories, comparisons, sizing, compatibility, and answers to real
   customer questions. Thin paraphrases of catalog titles add little value.
6. Encourage accurate Google Business Profiles and reputable local/industry
   mentions for merchants with a physical or service-area presence.

### P2 — measure discovery and outcomes

- Search Console queries, indexed pages, crawl errors, merchant-listing issues,
  and Google's [generative-AI performance
  reporting](https://developers.google.com/search/blog/2026/06/gen-ai-performance-reports)
  where available
- Bing Webmaster diagnostics and, later, IndexNow if faster update notification
  becomes worth the integration
- referrals carrying `utm_source=chatgpt.com`
- product feed approvals, clicks, and price/availability mismatches
- landing-page engagement, add-to-cart, checkout, and sales by source

Rank tracking alone is not enough. The goal is qualified visits and completed
orders from pages whose facts remain accurate.

## Guardrails

- Do not claim that `llms.txt` improves Google rankings or guarantees citation.
- Do not add “AI schema”; use the relevant Schema.org type that matches visible
  content.
- Do not block a page in `robots.txt` when the intended control is `noindex`.
- Do not publish fabricated experience, reviews, certifications, scarcity,
  comparisons, delivery promises, or product specifications.
- Do not mark unavailable items in stock merely to preserve feed coverage.
- Treat `GPTBot`, `Google-Extended`, and other model-training controls separately
  from ordinary search-index eligibility.

## Optional later integration

Bing's [IndexNow](https://www.bing.com/webmasters/help/indexnow-0z209wby) can
notify participating search engines when product URLs change. It is a useful
optimization after launch monitoring shows that normal sitemap discovery is too
slow; it is not required for the initial rollout.
