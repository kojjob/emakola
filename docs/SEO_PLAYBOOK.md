# SEO Playbook — Plain-English How-Tos

Step-by-step instructions for the SEO tasks that can't be done in code — the
on/off switches, the marketing/outreach work, and the custom-domains decision.
No jargon; where a command is needed it's copy-paste ready. Replace `emakola`
with your real Fly app name if different.

For the full beginner-friendly production checklist covering DNS/TLS, Google
Search Console, Bing, Merchant Center, ChatGPT product feeds, and catalog
quality, see **`docs/SEO_PRODUCTION_SETUP_BEGINNERS_GUIDE.md`**.

> The SEO features are all **built and shipped "dark"** — they sit quietly doing
> nothing until you flip their switch. Nothing below can break the live site;
> each step only turns something *on*.

---

## Part 1 — The On/Off Switches

### 1A. Turn on AI-assisted catalog writing

This lets merchants generate missing product descriptions and image alt text,
and prepare blog drafts. Product descriptions and alt text generated from
`/admin/seo` are saved directly to the catalog. Merchants must review the result
after each batch and replace generic language with concrete facts about the
actual product. The prompt is constrained not to invent product claims, but it
cannot verify the source data.

Usage is hard-capped at 50 generations per shop per day. Check current Anthropic
pricing and expected catalog volume before setting a budget; do not rely on an
old fixed monthly estimate.

1. Go to **console.anthropic.com** → sign in → **Settings → API Keys → Create Key**.
2. Copy the key (starts with `sk-ant-…`).
3. Put it on the server as a secret:
   ```
   fly secrets set ANTHROPIC_API_KEY=sk-ant-your-key-here --app emakola
   ```
4. Done. Fly restarts the app automatically. To check: log in as a merchant,
   visit **/admin/seo**, and click **"Generate and save"** — jobs queue and fill
   in missing fields.
5. Review the changed products and images. Add details the merchant can verify:
   materials, dimensions, ingredients, origin, compatibility, care instructions,
   and what makes this specific item useful. Never add unsupported guarantees,
   certifications, delivery promises, reviews, or “best” claims.

To turn it back **off**: `fly secrets unset ANTHROPIC_API_KEY --app emakola`.

---

### 1B. Turn on Search Console data (do later, once the site is ranking)

This pulls "searches you almost rank for" from Google so you know what content to
write. Only worth doing **after** the site is live on makola.io and getting
search traffic.

1. **Verify the site in Google Search Console:** go to
   **search.google.com/search-console** → Add property → enter `makola.io` →
   verify (the easiest way is the **DNS TXT record** method — Google gives you a
   `TXT` value to add at your domain registrar).
2. **Make a Google service account:**
   - Go to **console.cloud.google.com** → create a project (or reuse one) →
     **APIs & Services → Library** → enable **"Google Search Console API"**.
   - **APIs & Services → Credentials → Create credentials → Service account.**
   - Open the service account → **Keys → Add key → JSON** → download the file.
3. **Give it access:** copy the service account's email (looks like
   `name@project.iam.gserviceaccount.com`). Back in Search Console →
   **Settings → Users and permissions → Add user** → paste that email →
   permission **Full**.
4. **Hand the JSON to the dev team** to wire up (one small code task — see
   `docs/SEO_ROADMAP_FOLLOWUPS.md` §4: connect Goth + set `:gsc_credentials`).
   Until that's wired, the fetcher stays dark and harmless.

---

### 1C. The makola.io cutover (the big one — needs DNS + certificates)

This is the master switch that turns on the canonical domain, the `emakola.com →
makola.io` redirects, and branded subdomains. It's an infrastructure job — full
mechanics live in `docs/DEPLOYMENT.md` and `docs/PROVIDER_SETUP.md`. The SEO part
is just the env vars to set **once DNS + TLS are ready**:

1. **Point makola.io at the app** and issue its certificate:
   ```
   fly certs add makola.io --app emakola
   fly certs add www.makola.io --app emakola
   ```
   Then add the DNS records Fly shows you, at your registrar (Namecheap).
2. **Issue the wildcard cert for subdomains** (so `anyshop.makola.io` works).
   This needs a DNS-01 challenge — see `docs/DEPLOYMENT.md`. Without it, skip
   step 4 below.
3. **Set the apex + redirect secrets:**
   ```
   fly secrets set PHX_HOST=makola.io --app emakola
   ```
   (The app already knows to 301-redirect `emakola.com`, `www.emakola.com`, and
   `emakola.fly.dev` to makola.io once `PHX_HOST` is makola.io — that list is
   pre-wired.)
4. **Turn on branded subdomains** (only after step 2's wildcard cert exists):
   ```
   fly secrets set STORE_SUBDOMAIN_BASE=makola.io --app emakola
   ```
5. Move outbound email to the new domain (set `MAIL_FROM_DOMAIN=makola.io` and
   re-verify it in Resend).

After this, every shop's links, sitemap, and canonical tags use makola.io, and
merchants can claim `theirshop.makola.io` from **/admin/settings/address**.

---

## Part 2 — Backlinks, WhatsApp & Social (marketing, not code)

These build the site's reputation so Google ranks it higher. They're people
tasks — anyone on the team can do them. Do a few each week.

### 2A. Make every WhatsApp share a mini-advert (already works — just check)

Every shop and product page already produces a rich preview when shared.

1. Open any shop link on your phone, copy it, paste it into a WhatsApp chat.
2. You should see a **card with the shop's name, a line of text, and an image**.
3. If the image is missing, the merchant just needs to upload a **shop logo or
   cover photo** in their settings — then the preview fills in.
4. **Tell merchants:** "Share your shop link on your WhatsApp status — it shows a
   proper preview, like a free advert."

### 2B. Give merchants a social-bio script

Ask every merchant to put their shop link where their customers already are:

- **Instagram:** Edit Profile → Website → paste their shop link.
- **Facebook Page:** About → Website.
- **WhatsApp Business:** Settings → Business tools → "Short link" / catalog, and
  add the shop link to their profile/about.

Copy-paste message to send merchants:
> "Add your Makola shop link to your Instagram bio, Facebook page, and WhatsApp
> Business profile. It's free, and every customer who clicks lands straight on
> your shop."

### 2C. Submit Makola to free directories (do once)

Create a free listing for **makola.io** on Ghana/Africa business directories.
Each listing is a backlink that helps ranking. For each:
1. Search "[directory name] add business".
2. Create a listing: business name **Makola**, website **makola.io**, category
   "E-commerce / Online Marketplace", short description, logo.

Good starting list: GhanaYello, Ghana Business Web, BusinessGhana, Ghana Trade,
Yelp/Google Business Profile, and any Ghana startup/tech directories you know.

### 2D. Local press & blogger outreach

1. Make a short list of Ghana tech/business blogs and journalists.
2. Send a 3-line pitch: what Makola is (online shops for local sellers, mobile
   money built in), why it matters (helps small traders sell online), and a link.
3. Offer them the platform blog post / explainer as a ready-made story.

---

## Part 3 — Custom Domains (`yourshop.com`) — Pick One, Then I Build It

Some merchants will want their own domain (e.g. `kentekingdom.com`) instead of
`kentekingdom.makola.io`. The code that *routes* a custom domain to the right
shop is **already built**. What's left is **how the domain gets its HTTPS
certificate** — and that's a business decision because the three options differ
in cost and effort. Here's each in plain terms.

### Option A — Registrar redirect (free, simplest, "brand only")

The merchant's domain just **bounces** visitors to their Makola shop. Their
branded address never actually shows the shop — it's a doorway.

- **How it works:** the merchant sets up "URL forwarding" at their domain
  registrar (Namecheap, GoDaddy, etc.) pointing `kentekingdom.com` →
  `makola.io/s/kente-kingdom`. The registrar handles the certificate.
- **We do:** nothing — no code, no cost.
- **Cost:** $0.
- **Trade-off:** the address bar shows makola.io after the redirect, not their
  domain. Fine for sellers who just want to print one address on a flyer.
- **Merchant steps:** registrar dashboard → Domain → "Redirect / URL Forwarding"
  → forward to `https://makola.io/s/their-slug` (permanent / 301).

### Option B — Fly certificate per domain (free, manual, good for the first few)

The shop **actually loads on** `kentekingdom.com` with a green padlock.

- **How it works:** the merchant points their domain at our app; we run one
  command per domain and Fly gets a free Let's Encrypt certificate.
- **We do (per domain):**
  ```
  fly certs add kentekingdom.com --app emakola
  ```
  then give the merchant the DNS record to add at their registrar.
- **Cost:** $0, but it's **manual for each domain** — fine for the first 5–20,
  tedious at hundreds.
- **Best for:** the early paid customers, before there are many.

### Option C — Cloudflare for SaaS (small fee, fully automatic, for scale)

Same result as B (the shop loads on their domain), but certificates are issued
**automatically** for unlimited domains.

- **How it works:** Cloudflare sits in front and handles TLS for every custom
  hostname; merchants just point their domain at a Cloudflare target.
- **Cost:** about **$0.10 per domain per month**.
- **Best for:** once there are dozens/hundreds of custom domains and doing them
  by hand is too much.

### My recommendation

Start with **Option A or B** (both free) for the first merchants, and switch to
**Option C** only when custom domains become popular enough that manual work
hurts. You can mix them.

**Once you pick, tell me which** and I'll build the rest: the "add your own
domain" panel in the merchant admin, the verification flow, and turning the
`custom_domain_support` flag on. (The routing/redirect logic is already done.)
