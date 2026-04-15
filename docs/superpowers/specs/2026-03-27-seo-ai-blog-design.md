# SEO, AI Content Generation & Blog System

**Date:** 2026-03-27
**Status:** Approved

---

## Overview

Integrated system combining three capabilities: a multi-tenant blog/CMS for content marketing, AI-powered content generation for merchants who need help writing, and SEO infrastructure (sitemaps, structured data) to make everything discoverable. Each store gets its own blog, recipes, and pages. The Emakola platform also gets a central blog for merchant acquisition.

AI generates drafts. Merchants approve before anything goes live.

---

## 1. Domain Model

New Ash domain: `Emakola.Content`

### Post

Core content resource. Multi-tenant via `store_id` (nil for platform blog).

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `store_id` | UUID, nullable | nil = platform blog |
| `author_id` | UUID | Merchant who created/owns it |
| `type` | atom | `:blog_post`, `:page`, `:recipe`, `:guide` |
| `title` | string, max 255 | Required |
| `slug` | string, max 255 | Auto-generated from title, unique per store+type |
| `body` | text | Markdown/rich text |
| `excerpt` | string, max 500 | Short summary for cards and meta |
| `featured_image_url` | string | Hero image |
| `seo_title` | string, max 255 | Override for meta title |
| `seo_description` | string, max 1000 | Override for meta description |
| `status` | atom | `:draft`, `:ai_draft`, `:published`, `:archived` |
| `published_at` | utc_datetime | When published (can be future-dated) |
| `tags` | list of strings | For categorization and filtering |
| `ai_generated` | boolean, default false | Tracks AI-written content |
| `view_count` | integer, default 0 | Pageview counter |
| timestamps | | inserted_at, updated_at |

**Identity:** `[:store_id, :slug, :type]`

**Actions:** create, update, publish, archive, delete, list_by_store, list_by_type, list_published, get_by_slug, increment_views, search

### MediaAttachment

Rich media linked to posts.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `post_id` | UUID, nullable | Linked post (nil for media library items) |
| `store_id` | UUID | Tenant-scoped |
| `type` | atom | `:image`, `:video`, `:audio` |
| `url` | string | S3 URL |
| `filename` | string | Original filename |
| `alt_text` | string | Accessibility text |
| `caption` | string | Display caption |
| `position` | integer | Ordering within post |
| `ai_alt_text` | string | AI-generated alt text |
| `file_size` | integer | Bytes |
| `content_type` | string | MIME type |
| timestamps | | |

**Actions:** create, update, delete, list_by_post, list_by_store, reorder

### RecipeMeta

Extra structured data for recipe-type posts. Enables Google Recipe rich results.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `post_id` | UUID | One-to-one with Post |
| `prep_time` | integer | Minutes |
| `cook_time` | integer | Minutes |
| `servings` | integer | Number of servings |
| `difficulty` | atom | `:easy`, `:medium`, `:hard` |
| `ingredients` | list of maps | `[%{item: "rice", quantity: "2 cups"}]` |
| `instructions` | list of strings | Ordered steps |
| timestamps | | |

**Actions:** create, update, delete, get_by_post

---

## 2. AI Content Generator

### Behaviour

```elixir
defmodule Emakola.Content.Generator do
  @callback generate_product_description(product, store) :: {:ok, String.t()} | {:error, term()}
  @callback generate_seo_meta(resource, store) :: {:ok, %{title: String.t(), description: String.t()}} | {:error, term()}
  @callback generate_blog_post(topic, store, type) :: {:ok, %{title: String.t(), body: String.t(), excerpt: String.t(), tags: [String.t()]}} | {:error, term()}
  @callback generate_image_alt_text(image_url) :: {:ok, String.t()} | {:error, term()}
  @callback generate_recipe(product, store) :: {:ok, %{body: String.t(), ingredients: [map()], instructions: [String.t()], prep_time: integer(), cook_time: integer(), servings: integer()}} | {:error, term()}
end
```

### Implementation: `Emakola.Content.Generators.Claude`

- Uses Claude API via `Req` HTTP client
- System prompts tailored per content type (product description, blog post, recipe, etc.)
- Includes store context (name, currency, region) in prompts for culturally relevant content
- English only for now
- Configurable via `Application.get_env(:emakola, :content_generator, Emakola.Content.Generators.Claude)`
- Mockable via Mox for testing (define `Emakola.Content.GeneratorMock`)

### Prompt strategy

- **Product descriptions:** Include product title, price, category, variant info. Ask for 2-3 paragraph description highlighting benefits. Tone: conversational, West African market context.
- **SEO meta:** Include product/post title and description. Generate title under 60 chars, description under 155 chars. Focus on search intent.
- **Blog posts:** Include store name, topic, target audience. Generate 600-1000 word post with subheadings, practical advice.
- **Recipes:** Include product name, category, store context. Generate ingredients list, step-by-step instructions, prep/cook times. Format for structured data.
- **Image alt text:** Send image URL to Claude vision. Ask for descriptive, concise alt text under 125 chars.

### Rate limiting

- Max 50 AI generations per store per day
- Tracked via a simple counter in ETS or a `daily_ai_usage` field on Store
- Returns `{:error, :rate_limit_exceeded}` when hit

---

## 3. SEO Infrastructure

### Sitemap generation

- `Emakola.SEO.SitemapWorker` (Oban) -- runs daily + triggered on content publish/update/delete
- Per-store sitemap at `/s/{store_slug}/sitemap.xml`
- Platform sitemap index at `/sitemap.xml` linking all store sitemaps + platform blog
- Includes: store homepage, products (published), categories, blog posts (published), recipes (published), pages (published)
- Excludes: cart, checkout, account, admin, draft content
- Generated as XML string, served by a controller (not static file)
- `SitemapController` with `store_sitemap/2` and `platform_sitemap/2` actions
- Products/posts with `exclude_from_sitemap: true` are omitted

### Structured data (JSON-LD) expansion

Extend existing `EmakolaWeb.Helpers.SEO` module:

- `json_ld_article/2` -- `BlogPosting` schema for blog posts (headline, author, datePublished, image)
- `json_ld_recipe/2` -- `Recipe` schema for recipe posts (ingredients, cookTime, prepTime, recipeInstructions, nutrition, image). This triggers Google Recipe rich results.
- `json_ld_breadcrumb/1` -- already exists, extend to blog/content pages
- `json_ld_faq/1` -- `FAQPage` schema when posts contain Q&A sections
- `json_ld_organization/1` -- improve existing with social links, logo, contact

### Robots.txt

- Dynamic per-store: `GET /s/{store_slug}/robots.txt` served by controller
- Allow all public content, disallow admin/cart/checkout/account
- Include sitemap URL pointing to store's sitemap
- Platform robots.txt updated with correct sitemap index URL

### Canonical URLs

- Every page gets `<link rel="canonical">` (partially implemented already)
- Blog: `/s/{store_slug}/blog/{post_slug}`
- Recipe: `/s/{store_slug}/recipes/{recipe_slug}`
- Page: `/s/{store_slug}/{page_slug}`
- Platform blog: `/blog/{post_slug}`

### Performance

- `loading="lazy"` on all blog images and media
- Responsive images with `srcset` for uploaded media
- Preload critical above-fold images

---

## 4. CRUD Actions Summary

### Post CRUD

| Action | Type | Who | Notes |
|--------|------|-----|-------|
| `create` | create | Merchant/Admin | Sets status to `:draft` |
| `update` | update | Merchant/Admin | Edit all fields |
| `publish` | update | Merchant/Admin | Sets status to `:published`, sets `published_at` |
| `archive` | update | Merchant/Admin | Sets status to `:archived` |
| `destroy` | destroy | Merchant/Admin | Hard delete with confirmation |
| `list_by_store` | read | Internal | All posts for a store |
| `list_published` | read | Storefront | Published posts only, ordered by `published_at` desc |
| `list_by_type` | read | Internal | Filter by type within store |
| `get_by_slug` | read | Storefront | Single post lookup by slug + store |
| `increment_views` | update | Storefront | Atomic increment on page load |
| `search` | read | Admin | Full-text search on title + body |

### MediaAttachment CRUD

| Action | Type | Who | Notes |
|--------|------|-----|-------|
| `create` | create | Merchant/Admin | Upload to S3, store metadata |
| `update` | update | Merchant/Admin | Edit alt text, caption, position |
| `destroy` | destroy | Merchant/Admin | Delete from S3 + database |
| `list_by_post` | read | Internal | Media for a specific post |
| `list_by_store` | read | Admin | Media library view |
| `reorder` | update | Admin | Update positions |

### RecipeMeta CRUD

| Action | Type | Who | Notes |
|--------|------|-----|-------|
| `create` | create | Merchant/Admin | Created alongside recipe post |
| `update` | update | Merchant/Admin | Edit ingredients, instructions, times |
| `destroy` | destroy | Merchant/Admin | Cascade with post deletion |
| `get_by_post` | read | Internal | Load recipe data for a post |

### Sitemap CRUD

| Action | Who | Notes |
|--------|-----|-------|
| Toggle sitemap on/off | Admin | Store setting |
| Manual regenerate | Admin | Triggers SitemapWorker |
| Exclude item | Admin | Flag on product/post |
| Auto-regenerate | System | On content publish/update/delete |

### Product SEO (enhanced existing)

| Action | Who | Notes |
|--------|-----|-------|
| Generate description with AI | Admin | Button on product form |
| Generate SEO meta with AI | Admin | Button on product form |
| Bulk generate SEO | Admin | "Fix all" on SEO dashboard |
| Edit seo_title, seo_description | Admin | Already exists |

---

## 5. Admin UI

### New sidebar items

Under "Content" section:
- Blog Posts
- Recipes
- Pages
- Media Library

Under "SEO" section:
- SEO Dashboard
- Sitemap Settings

### Blog Posts admin (`/admin/content/posts`)

- Table: title, type badge, status badge (draft/ai_draft/published), author, published_at, view_count
- Filters: by type, by status, by tag
- "New Post" + "Generate with AI" buttons
- Bulk actions: publish, archive, delete, generate SEO

### Post editor (`/admin/content/posts/:id/edit`)

- Two-column: editor left (title, body with markdown toolbar, media embeds), settings right (status, publish date, featured image, tags, SEO fields with character counters, AI buttons)
- Media toolbar: insert image/video/audio from Media Library or upload inline
- For recipes: collapsible "Recipe Details" panel (ingredients list with add/remove/reorder, instructions list, prep_time, cook_time, servings, difficulty)
- Preview button: opens storefront view in new tab

### Media Library (`/admin/content/media`)

- Grid of thumbnails, filter by type (image/video/audio)
- Drag-and-drop upload zone, multi-file
- Click to edit alt text, caption
- "Generate alt text" AI button per image
- File size and type shown on each item

### SEO Dashboard (`/admin/seo`)

- Score cards: products missing descriptions, posts without meta tags, images without alt text
- "Fix all with AI" bulk action
- Sitemap status: last generated, URL count, regenerate button
- Quick wins: "These 5 products need descriptions" with one-click generate

---

## 6. Oban Workers

| Worker | Queue | Trigger | Unique | Idempotent |
|--------|-------|---------|--------|------------|
| `ProductSEOWorker` | `ai_content` | Product created without description | `product_id`, 60s | Yes - skips if description exists |
| `ImageAltTextWorker` | `ai_content` | Image uploaded without alt text | `media_id`, 60s | Yes - skips if alt_text exists |
| `SitemapWorker` | `seo` | Content published/updated/deleted + daily cron | `store_id`, 300s | Yes - full regeneration |
| `BulkSEOWorker` | `ai_content` | Admin clicks "Fix all" | `store_id`, 60s | Yes - queues individual jobs |
| `BlogGeneratorWorker` | `ai_content` | Admin clicks "Generate with AI" | `{store_id, topic}`, 30s | Yes - creates draft if not exists |

All workers in `ai_content` queue respect the 50/day rate limit per store.

---

## 7. Storefront Routes

### Per-store content (public, no auth)

```
GET /s/:store_slug/blog                    -- BlogListLive (published posts)
GET /s/:store_slug/blog/:post_slug         -- BlogPostLive (single post)
GET /s/:store_slug/recipes                 -- RecipeListLive (published recipes)
GET /s/:store_slug/recipes/:recipe_slug    -- RecipeLive (single recipe + structured data)
GET /s/:store_slug/:page_slug              -- PageLive (static pages: about, shipping-policy, etc.)
```

### Platform blog

```
GET /blog                                  -- PlatformBlogLive
GET /blog/:post_slug                       -- PlatformPostLive
```

### SEO endpoints (controller, not LiveView)

```
GET /sitemap.xml                           -- SitemapController.platform_index
GET /s/:store_slug/sitemap.xml             -- SitemapController.store_sitemap
GET /s/:store_slug/robots.txt              -- SitemapController.store_robots
```

### Admin routes (authenticated)

```
GET /admin/content/posts                   -- PostLive.Index
GET /admin/content/posts/new               -- PostLive.Form (create)
GET /admin/content/posts/:id/edit          -- PostLive.Form (edit)
GET /admin/content/recipes                 -- PostLive.Index (type: :recipe)
GET /admin/content/pages                   -- PostLive.Index (type: :page)
GET /admin/content/media                   -- MediaLive.Index
GET /admin/seo                             -- SEODashboardLive
GET /admin/seo/sitemap                     -- SitemapSettingsLive
```

---

## 8. Testing Strategy

- **Mox mock** for `Emakola.Content.Generator` behaviour -- never call Claude in tests
- Unit tests for each Ash resource (Post, MediaAttachment, RecipeMeta)
- Unit tests for sitemap XML generation
- Unit tests for JSON-LD structured data (Recipe, Article schemas)
- LiveView tests for admin CRUD (create, edit, publish, delete posts)
- LiveView tests for storefront blog/recipe pages
- Integration test for full flow: create product -> AI generates description -> merchant reviews -> publishes
- Worker tests for all 5 Oban workers (with Mox generator)

---

## 9. Configuration

```elixir
# config/config.exs
config :emakola,
  content_generator: Emakola.Content.Generators.Claude,
  ai_rate_limit_per_day: 50

# config/runtime.exs
config :emakola,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")

# config/test.exs
config :emakola,
  content_generator: Emakola.Content.GeneratorMock
```

---

## 10. Out of Scope (future)

- Multi-language content (Pidgin, Akan, Hausa, Yoruba)
- Content scheduling (future-dated publish)
- Content analytics (beyond view_count)
- Social media auto-posting
- A/B testing for AI-generated content
- Custom page builder / drag-and-drop editor
- Comments on blog posts
