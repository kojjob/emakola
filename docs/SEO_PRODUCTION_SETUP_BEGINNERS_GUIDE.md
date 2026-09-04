# SEO and AI-search production setup — beginner guide

Last reviewed: 2026-07-29

This is the step-by-step operating guide for launching Makola's SEO,
Google/Bing discovery, shopping feeds, and ChatGPT product-feed application.

Complete the sections in order. Do not move to the next section until the
current section's **Done when** check passes.

## Before starting

This guide assumes:

- The Fly.io app is named `emakola`.
- The main domain is `makola.io`.
- `PHX_HOST = "makola.io"` is already set in `fly.toml`.
- DNS is managed in Namecheap. Cloudflare users should enter the same records
  in Cloudflare DNS and initially set them to **DNS only**.
- `<STORE-SLUG>` means a real store slug, such as `ama-kitchen`. Replace the
  complete placeholder, including the angle brackets.

## 1. Finish domain, DNS, and HTTPS setup

### 1.1 Open Terminal

```bash
cd /Users/kojo/Projects/emakola
fly auth login
fly status --app emakola
```

The Fly app should be found and running.

### 1.2 Check the existing certificates

```bash
fly certs list --app emakola
```

Makola needs certificates for:

```text
makola.io
www.makola.io
*.makola.io
```

The wildcard certificate covers merchant addresses such as
`ama-kitchen.makola.io`.

### 1.3 Add only missing certificates

Run the relevant command for each missing certificate:

```bash
fly certs add makola.io --app emakola
```

```bash
fly certs add www.makola.io --app emakola
```

```bash
fly certs add '*.makola.io' --app emakola
```

Keep the quotes around `*.makola.io`. Fly will print the DNS records it needs.
Always use those current values instead of copying old IP addresses from a
document.

Reference: [Fly custom-domain
instructions](https://fly.io/docs/networking/custom-domain/).

### 1.4 Add the DNS records in Namecheap

1. Sign in to Namecheap.
2. Open **Domain List**.
3. Find `makola.io` and click **Manage**.
4. Open **Advanced DNS**.
5. Click **Add New Record**.

The required records will normally include:

- An `A` record for host `@`, using Fly's IPv4 address.
- An `AAAA` record for host `@`, using Fly's IPv6 address.
- A `CNAME` for host `www`, using the Fly target.
- Wildcard DNS for host `*`, using the values Fly provides.
- An `_acme-challenge` CNAME for the wildcard certificate.

Display the exact required records with:

```bash
fly certs setup makola.io --app emakola
```

```bash
fly certs setup www.makola.io --app emakola
```

```bash
fly certs setup '*.makola.io' --app emakola
```

Set the DNS TTL to **Automatic**.

If using Cloudflare:

- Initially use **DNS only** (grey cloud).
- Set Cloudflare SSL mode to **Full** or **Full (Strict)**.
- Never use **Flexible**, because it can cause redirect loops.

### 1.5 Wait for the certificates

```bash
fly certs check makola.io --app emakola
```

```bash
fly certs check www.makola.io --app emakola
```

```bash
fly certs check '*.makola.io' --app emakola
```

Continue only when all required certificates report ready.

### 1.6 Enable merchant subdomains

Only after the wildcard certificate is ready:

```bash
fly secrets set STORE_SUBDOMAIN_BASE=makola.io --app emakola
```

This restarts the Fly application.

### 1.7 Test the result

Open:

```text
https://makola.io
https://www.makola.io
https://<STORE-SLUG>.makola.io
https://<STORE-SLUG>.makola.io/sitemap.xml
https://<STORE-SLUG>.makola.io/robots.txt
```

Expected:

- `makola.io` loads normally.
- `www.makola.io` redirects to `makola.io`.
- A real store loads from its subdomain.
- The store sitemap displays XML.
- The store robots file displays plain text.

**Done when:** all three certificates are ready and a real merchant store opens
at `https://<STORE-SLUG>.makola.io`.

## 2. Set up Google Search Console and Bing

Use the same Google account that will be used for Google Merchant Center. This
makes Merchant Center verification easier.

### 2.1 Create a Google Search Console property

1. Open [Google Search Console](https://search.google.com/search-console).
2. Sign in.
3. Open the property selector at the top-left.
4. Click **Add property**.
5. Choose **Domain**.
6. Enter only:

```text
makola.io
```

Do not include `https://`, `www`, or a path. A Domain property covers the apex
and merchant subdomains.

Reference: [Google's Domain property
instructions](https://support.google.com/webmasters/answer/34592).

### 2.2 Add Google's verification record

Google will provide a value similar to:

```text
google-site-verification=abc123...
```

In Namecheap:

1. Open **Advanced DNS**.
2. Click **Add New Record**.
3. Choose **TXT Record**.
4. Set host to `@`.
5. Paste Google's complete verification value.
6. Set TTL to **Automatic**.
7. Save.

Return to Search Console and click **Verify**. Do not delete the TXT record
after verification.

### 2.3 Submit the main sitemap

1. Select the `makola.io` property.
2. Open **Sitemaps**.
3. Submit:

```text
https://makola.io/sitemap.xml
```

If the form already shows `https://makola.io/` before the input, enter only:

```text
sitemap.xml
```

Reference: [Google sitemap
instructions](https://support.google.com/webmasters/answer/7451001).

### 2.4 Submit representative store sitemaps

Start with three to five strong stores:

```text
https://ama-kitchen.makola.io/sitemap.xml
https://another-store.makola.io/sitemap.xml
```

Do not submit hundreds manually.

### 2.5 Inspect an important product

1. Open **URL inspection**.
2. Paste a complete product URL.
3. Click **Test live URL**.
4. If the live test succeeds, click **Request indexing**.

Use this for a few important pages, not every product.

### 2.6 Import the site into Bing

1. Open [Bing Webmaster Tools](https://www.bing.com/webmasters/).
2. Sign in.
3. Choose **Import from Google Search Console**.
4. Sign in to the Google account used above.
5. Allow Bing access.
6. Select `makola.io`.
7. Click **Import**.
8. Open Bing's **Sitemaps** section.
9. Confirm `https://makola.io/sitemap.xml` is listed.
10. Submit it manually if it is missing.

Reference: [Bing import
instructions](https://www.bing.com/webmasters/help/add-and-verify-site-12184f8b).

Reports may remain empty for several days while Google and Bing collect data.

**Done when:** Google accepts the main sitemap and Bing lists the imported
website and sitemap.

### 2.7 Connect the Search Console API to Makola

Makola can pull Search Console data itself (`Emakola.Analytics.GscFetcher`,
run daily by `GscSyncWorker`). It ships dark until a service account key is
set. Without it, the fetcher returns nothing and logs nothing.

1. Open [Google Cloud Console](https://console.cloud.google.com/) with the
   same Google account that owns the Search Console property.
2. Create a project (or pick an existing one), then open
   **APIs & Services → Library**, search for **Google Search Console API**,
   and click **Enable**.
3. Open **IAM & Admin → Service Accounts → Create service account**. Name it
   `makola-gsc`. It needs no project roles. Finish.
4. Open the new service account, go to **Keys → Add key → Create new key →
   JSON**. A file downloads. Keep it private; it is a credential.
5. Back in Search Console, open **Settings → Users and permissions → Add
   user**. Paste the service account's email address (it ends in
   `.iam.gserviceaccount.com`). Permission **Full**. Save.
6. Set the key as a Fly secret, from Terminal, on one line:

```bash
fly secrets set -a emakola GSC_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/makola-gsc-*.json)"
```

`GSC_SITE_URL` needs no value: it defaults to `sc-domain:makola.io`, which
is the form a Domain property requires. The URL-prefix form returns 403.

7. Verify after the app restarts:

```bash
fly ssh console -a emakola -C "/app/bin/emakola rpc 'IO.inspect(Emakola.Analytics.GscFetcher.fetch(nil))'"
```

`{:ok, [...]}` with rows means it works. `{:ok, []}` with the secret set means
the service account is not yet a user on the property (step 5), or the
property has no data yet.

## 3. Set up Google Merchant Center

Begin with one high-quality pilot merchant. Do not place every independent
merchant into one ordinary Merchant Center account.

For platform-wide onboarding, Makola will eventually need Google's advanced or
multi-seller account structure.

Reference: [Google multi-seller account
guidance](https://support.google.com/merchants/answer/15108683).

### 3.1 Select a pilot merchant

Choose a store with:

- Real business and contact information.
- At least ten complete products.
- Correct prices and availability.
- Good product images.
- Delivery and return information.
- No prohibited, fake, or questionable products.

Write down:

```text
STORE-SLUG: ama-kitchen
STORE URL: https://ama-kitchen.makola.io
FEED URL: https://makola.io/s/ama-kitchen/feed/products.xml
```

Open the feed URL in a browser first. It should display XML.

### 3.2 Create the Merchant Center business

1. Open [Google Merchant Center](https://merchants.google.com/).
2. Sign in with the Search Console Google account.
3. Create a business.
4. Enter the merchant's real business name.
5. Enter the merchant's actual operating country.
6. Enter the merchant's real contact details.
7. Set the online store URL to:

```text
https://<STORE-SLUG>.makola.io
```

Do not use the platform homepage as the pilot merchant's shop URL.

### 3.3 Verify and claim the store

Merchant Center may verify the store automatically through Search Console.

If verification is requested:

1. Choose the Search Console or existing Google verification method.
2. Confirm the same Google account is being used.
3. Complete **Verify**.
4. Complete **Claim website**.

Reference: [Google website verification
guidance](https://support.google.com/merchants/answer/11586344).

### 3.4 Connect the Makola product feed

1. Open **Settings** in Merchant Center.
2. Open **Data sources**.
3. Under **Product sources**, click **Add product source**.
4. Choose **Add products from a file**.
5. Choose the scheduled URL/file option.
6. Give it a clear name such as `Ama Kitchen — Makola Feed`.
7. Enter:

```text
https://makola.io/s/<STORE-SLUG>/feed/products.xml
```

8. Do not enter a username or password.
9. Choose a daily update.
10. Save.

Reference: [Merchant Center scheduling
instructions](https://support.google.com/merchants/answer/14991445).

### 3.5 Fix product issues

After Google processes the feed:

1. Open **Products**.
2. Open **Needs attention**.
3. Read each issue.
4. Fix the original product inside Makola.
5. Return to **Data sources**.
6. Click **Update** or **Fetch now**.

Do not repeatedly correct feed-supplied values manually in Merchant Center. A
future feed refresh may replace those manual changes.

Common issues include:

- Missing or poor-quality image.
- Missing description.
- Price mismatch between the feed and page.
- Availability mismatch between the feed and page.
- Missing brand or product identifier.
- Missing shipping or return information.

### 3.6 Add the real delivery and return terms

Complete the Merchant Center sections for:

- Shipping regions.
- Shipping costs.
- Delivery estimates.
- Return window.
- Return costs.
- Customer-support details.

Use the merchant's actual policies. Do not add delivery or return promises the
merchant cannot consistently keep.

**Done when:** the pilot store is verified, its feed has processed, and at least
one product is approved.

## 4. Apply for ChatGPT product-feed access

OpenAI now documents product feeds as part of the Agentic Commerce Protocol
(ACP). Product-feed onboarding is available to approved partners.

References:

- [OpenAI merchant application](https://chatgpt.com/merchants)
- [OpenAI commerce setup
  guide](https://developers.openai.com/commerce/guides/get-started)

### 4.1 Check ChatGPT Search crawl access

Open:

```text
https://makola.io/robots.txt
https://makola.io/s/<STORE-SLUG>/robots.txt
```

Confirm the output contains:

```text
User-agent: OAI-SearchBot
Allow: /
```

### 4.2 Prepare the application information

Prepare:

- Company name: Makola
- Website: `https://makola.io`
- Business type: ecommerce platform/marketplace
- Actual countries served
- Approximate merchant count
- Approximate product count
- Technical contact
- Business contact
- One example store
- One example Google-format feed:

```text
https://makola.io/s/<STORE-SLUG>/feed/products.xml
```

Clearly explain that Makola hosts multiple independent merchant stores.

### 4.3 Submit the application

Open [chatgpt.com/merchants](https://chatgpt.com/merchants), complete the form,
and wait for partner approval.

There is no API key or setting that bypasses this approval.

### 4.4 Do not treat the existing XML as an ACP feed

Makola's current `/feed/products.xml` uses the Google Merchant feed format.
OpenAI ACP uses a different schema.

The current feed can demonstrate that Makola already exports catalog data, but
it must not simply be renamed and uploaded as an OpenAI feed.

### 4.5 Continue only after approval

Once approved, send the approval email and technical instructions to the
development team.

OpenAI currently supports:

- A full catalog feed delivered through SFTP.
- API updates during the day.
- API-only delivery for smaller feeds.

For file delivery, OpenAI recommends:

- A complete snapshot at least daily.
- A stable filename that is overwritten on each update.
- Starting validation with approximately 100 products.
- UTF-8 Parquet, compressed JSONL, CSV, or TSV.

Reference: [OpenAI file-feed
requirements](https://developers.openai.com/commerce/specs/file-upload/overview).

**Done when:** the application has been submitted. Wait for approval before
building the ACP exporter.

## 5. Improve merchant and product data

This ongoing work is likely to produce more SEO value than generating large
amounts of generic AI content.

### 5.1 Complete every important product

Open:

```text
https://makola.io/admin/products
```

For each product, check:

- A clear, natural title.
- A factual description.
- One strong main image and useful additional images.
- Accurate image alt text.
- Correct variant price.
- Stable SKU.
- Correct inventory-tracking setting.
- Correct stock quantity.
- Disabled variants when they are unavailable.
- Relevant category and tags.

Good title:

```text
Handwoven Market Basket with Two Handles
```

Bad title:

```text
BEST AMAZING QUALITY BASKET CHEAP
```

Useful description facts include:

- Material or ingredients.
- Dimensions.
- Colour and options.
- Intended use.
- Care instructions.
- Package contents.
- Known origin.
- Compatibility.

Never invent:

- Materials or ingredients.
- Certifications.
- Health or performance benefits.
- Customer stories or reviews.
- Delivery promises.
- Warranty terms.
- Product origin.

### 5.2 Record brands and product identifiers accurately

Record these only when real:

- Brand
- GTIN, UPC, or EAN
- MPN or manufacturer part number

Never create a fake GTIN.

Makola does not yet provide complete dedicated brand/GTIN/MPN catalog fields.
Adding them remains an engineering task.

### 5.3 Complete the merchant's public information

Review:

```text
/admin/settings
/admin/settings/address
/admin/settings/delivery
/admin/content/pages
```

Complete:

- Store description.
- Physical address only when it is a genuine customer-facing location.
- Contact email and telephone.
- About page.
- Contact page.
- Delivery information.
- Return policy.
- Privacy policy.
- Frequently asked questions.

An online-only merchant should not pretend to operate a physical shop.

### 5.4 Publish original merchant content

Useful topics include:

- How to choose the correct size.
- How to care for the product.
- Ingredient explanations.
- Buying guides.
- Product comparisons.
- Recipes.
- Answers to real customer questions.
- The merchant's genuine story and experience.

One genuinely useful guide per month is more valuable than many generic AI
articles.

### 5.5 Review all AI-generated content

The buttons at:

```text
/admin/seo
```

save descriptions and alt text directly.

After using **Generate and save**:

1. Wait for the jobs to finish.
2. Open the changed products.
3. Read every generated description.
4. Remove generic language.
5. Add facts the merchant can verify.
6. Correct mistakes immediately.

### 5.6 Follow a weekly routine

Every week:

1. Check Merchant Center **Needs attention**.
2. Check Search Console **Page indexing**.
3. Check Search Console **Performance**.
4. Check Bing sitemaps and crawl errors.
5. Correct stale prices and stock.
6. Improve five weak product descriptions.
7. Add missing product images.
8. Record visits, add-to-cart actions, and orders by source.

ChatGPT referrals can be identified through:

```text
utm_source=chatgpt.com
```

**Done when:** the pilot merchant has complete and accurate products, no serious
Merchant Center errors, clear delivery/return policies, and at least one useful
original guide.
