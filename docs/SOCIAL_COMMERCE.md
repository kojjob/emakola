# Emakola — Social Commerce Integration

## Problem

West African merchants live on social media — Instagram, TikTok, WhatsApp, Facebook, and Twitter/X are their primary sales channels. But they can't link a proper checkout to these platforms. They post products, get DMs, negotiate prices manually, and coordinate payment via MoMo screenshots. This is broken.

## Solution

Emakola connects merchant stores to social media platforms so customers can discover products on social and complete purchases on the merchant's Emakola store — with proper checkout, payment, and tracking.

## Supported Platforms

### Tier 1 — Launch Priority (Phase 2)
| Platform | Why | Integration Type |
|----------|-----|-----------------|
| **Instagram** | #1 product discovery platform in Ghana/Nigeria | Product catalog sync, link in bio, story/post product tags |
| **TikTok** | Fastest growing, massive Gen Z/millennial reach | TikTok Shop link, product links in bio, video product tags |
| **WhatsApp** | Primary communication, WhatsApp Catalog | WhatsApp Business Catalog sync, product sharing |

### Tier 2 — Growth (Phase 3)
| Platform | Why | Integration Type |
|----------|-----|-----------------|
| **Facebook** | Still massive in West Africa, especially 30+ age group | Facebook Shop sync, Marketplace integration |
| **Twitter/X** | Brand awareness, customer service | Product card links, shop link in bio |
| **Pinterest** | Visual discovery for fashion/home | Product pins, catalog sync |

### Tier 3 — Future (Phase 4)
| Platform | Why | Integration Type |
|----------|-----|-----------------|
| **YouTube** | Product reviews, tutorials | Product links in descriptions, YouTube Shopping |
| **Snapchat** | Growing in youth market | Product links, AR try-on (future) |

## How Each Integration Works

### Instagram Integration

**Setup (Merchant Admin → Settings → Social):**
1. Merchant connects Instagram Business account via OAuth
2. Products auto-sync to Instagram Catalog
3. Merchant tags products in posts/stories from Instagram app

**Customer Flow:**
```
Customer sees product on Instagram
  → Taps product tag
  → Sees price + "View on Store" link
  → Opens merchant's Emakola storefront
  → Adds to cart → Checkout with MoMo
  → Gets WhatsApp confirmation
```

**What Syncs:**
- Product name, description, images, price (GH₵)
- Inventory status (in stock / out of stock)
- Product URL (links back to Emakola store)
- Category mapping

**Auto-Updates:**
- Price changes → Instagram catalog updates within 1 hour
- Out of stock → product hidden on Instagram automatically
- New product (Active status) → added to catalog automatically

### TikTok Integration

**Setup:**
1. Merchant connects TikTok Business account
2. Products sync to TikTok product catalog
3. Merchant adds product links to videos and bio

**Customer Flow:**
```
Customer watches TikTok video
  → Sees product link / "Shop Now" button
  → Taps → Opens merchant's Emakola store
  → Product page with "Add to Bag"
  → Checkout with MoMo/Card/COD
```

**TikTok-Specific Features:**
- **Link in Bio**: Emakola generates a smart link page (mini-store) showing featured products
- **Video Product Tags**: Merchant tags products in TikTok videos
- **TikTok Pixel**: Track conversions from TikTok ads to Emakola purchases
- **Trending Products**: Dashboard shows which products get most TikTok traffic

### WhatsApp Business Catalog

**Setup:**
1. Merchant connects WhatsApp Business account
2. Products sync to WhatsApp Business Catalog
3. Customers browse catalog inside WhatsApp

**Customer Flow:**
```
Customer opens merchant's WhatsApp
  → Taps "Catalog" button
  → Browses products with images + prices
  → Taps product → "View on Website"
  → Opens Emakola store → Checkout
```

**WhatsApp-Specific:**
- Products auto-sync (name, image, price, description)
- Share product link in chat → rich preview with image + price
- "Order via WhatsApp" button on store sends pre-filled message

### Facebook Shop

**Setup:**
1. Connect Facebook Page via OAuth
2. Products sync to Facebook Commerce catalog
3. Facebook Shop tab appears on Page

**Customer Flow:**
```
Customer visits Facebook Page
  → Taps "Shop" tab
  → Browses products
  → "View on Website" → Emakola store
  → Checkout
```

## Smart Link Page (Link in Bio)

A branded mini-store page for social media bios:

**URL**: `emakola.com/@amaracollection`

```
┌─────────────────────────────┐
│     [Circle Avatar]          │
│   Amara Collection           │
│   Handcrafted fashion        │
│   from Accra 🇬🇭              │
│                              │
│ ┌──────────┐ ┌──────────┐   │
│ │ Product  │ │ Product  │   │
│ │ Image    │ │ Image    │   │
│ │ Name     │ │ Name     │   │
│ │ GH₵ 280  │ │ GH₵ 120  │   │
│ └──────────┘ └──────────┘   │
│ ┌──────────┐ ┌──────────┐   │
│ │ Product  │ │ Product  │   │
│ │ Image    │ │ Image    │   │
│ │ GH₵ 85   │ │ GH₵ 65   │   │
│ └──────────┘ └──────────┘   │
│                              │
│    [Shop Full Collection]    │
│                              │
│  📱 WhatsApp  📷 Instagram   │
│  🎵 TikTok    🐦 Twitter     │
│                              │
│     Powered by emakola       │
└─────────────────────────────┘
```

**Features:**
- Mobile-optimized (90%+ of bio link traffic is mobile)
- Featured products grid (merchant selects which to show)
- "Shop Full Collection" button → full Emakola store
- Social media links
- Customizable with store colors
- Analytics: click tracking per product, traffic source

## Merchant Admin — Social Commerce Dashboard

### Settings → Social Media page

**Connected Accounts Section:**
```
┌─────────────────────────────────────┐
│ CONNECTED ACCOUNTS                   │
│                                      │
│ Instagram    @amaracollection        │
│ ● Connected  14,200 followers        │
│ Products synced: 8/8 ✓              │
│ [Disconnect]                         │
│                                      │
│ TikTok       @amaracollection        │
│ ● Connected  8,400 followers         │
│ Products synced: 8/8 ✓              │
│ [Disconnect]                         │
│                                      │
│ WhatsApp     +233 24 123 4567        │
│ ● Connected  Catalog: 8 products     │
│ [Disconnect]                         │
│                                      │
│ Facebook     Amara Collection Page   │
│ ○ Not connected                      │
│ [Connect Facebook]                   │
│                                      │
│ Twitter/X    Not connected           │
│ [Connect Twitter]                    │
└─────────────────────────────────────┘
```

**Social Analytics Section:**
```
TRAFFIC FROM SOCIAL (Last 30 Days)
┌──────────────────────────────┐
│ Instagram    1,247 visits  45% │
│ TikTok        784 visits  28% │
│ WhatsApp      416 visits  15% │
│ Facebook      167 visits   6% │
│ Twitter        89 visits   3% │
│ Other          84 visits   3% │
│                               │
│ Total: 2,787 social visits    │
│ Conversion: 4.2% (117 orders) │
│ Revenue: GH₵ 16,380           │
└──────────────────────────────┘
```

**Product Sync Settings:**
- Auto-sync new products: ON/OFF
- Sync frequency: Real-time / Hourly / Daily
- Default catalog: sync all Active products / selected products only
- Price display: include delivery fee or product only

### Link in Bio Editor
- Preview of smart link page
- Drag-and-drop product order
- Featured products selector (max 8)
- Custom header text
- Social links configuration
- Copy link button: `emakola.com/@amaracollection`
- QR code generator (for print marketing)

## Technical Implementation

### Product Catalog Sync Architecture
```elixir
defmodule Emakola.Social.CatalogSync do
  @moduledoc "Syncs product catalog to connected social platforms"

  # Triggered by Oban job when product is created/updated/deleted
  def sync_product(product, platform) do
    case platform do
      :instagram -> sync_to_instagram(product)
      :tiktok -> sync_to_tiktok(product)
      :whatsapp -> sync_to_whatsapp(product)
      :facebook -> sync_to_facebook(product)
    end
  end

  # Batch sync on initial connection
  def full_sync(store, platform) do
    store
    |> list_active_products()
    |> Enum.each(&sync_product(&1, platform))
  end
end
```

### Sync Events (Oban Workers)
```elixir
# When product is created/updated:
Emakola.Social.Workers.SyncProduct.new(%{
  product_id: product.id,
  action: :upsert,
  platforms: [:instagram, :tiktok, :whatsapp]  # all connected
})
|> Oban.insert()

# When product goes out of stock:
Emakola.Social.Workers.SyncProduct.new(%{
  product_id: product.id,
  action: :hide,  # hide from catalogs, don't delete
  platforms: [:instagram, :tiktok, :whatsapp]
})
|> Oban.insert()
```

### Platform OAuth Tokens
```elixir
# Stored encrypted per store
defmodule Emakola.Social.Connection do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    attribute :platform, :atom  # :instagram, :tiktok, :whatsapp, :facebook, :twitter
    attribute :access_token, :string  # encrypted
    attribute :refresh_token, :string  # encrypted
    attribute :platform_user_id, :string
    attribute :platform_username, :string
    attribute :follower_count, :integer
    attribute :connected_at, :utc_datetime
    attribute :last_sync_at, :utc_datetime
    attribute :sync_status, :atom  # :synced, :syncing, :error
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store
  end
end
```

### UTM Tracking
All links from social platforms include UTM parameters for attribution:
```
https://amaracollection.emakola.com/products/kente-wrap-dress
  ?utm_source=instagram
  &utm_medium=product_tag
  &utm_campaign=spring_2026
```

Tracked in analytics: which platform, which post/video, which product → conversion.

## Phased Rollout

### Phase 2 — Social Basics
- [ ] Instagram catalog sync (via Meta Commerce API)
- [ ] WhatsApp Business Catalog sync
- [ ] Smart Link page (emakola.com/@storename)
- [ ] Social traffic tracking (UTM-based)
- [ ] Social media links on storefront

### Phase 3 — TikTok + Advanced
- [ ] TikTok product catalog sync
- [ ] TikTok Pixel integration
- [ ] Facebook Shop sync
- [ ] Social analytics dashboard
- [ ] QR code generator for link page

### Phase 4 — Full Social Commerce
- [ ] Instagram Shopping checkout (in-app)
- [ ] TikTok Shop integration (if available in Ghana)
- [ ] Cross-platform content scheduler
- [ ] AI-generated product descriptions for social
- [ ] Influencer collaboration tools
- [ ] Social proof widgets (Instagram feed on store)

## Key Metrics

| Metric | Definition | Target |
|--------|-----------|--------|
| Social traffic share | % of store visits from social | > 60% |
| Social conversion rate | Orders from social visits | > 3% |
| Catalog sync latency | Time for product update to appear | < 1 hour |
| Link page CTR | Clicks from bio link to store | > 25% |
| Connected accounts | Avg platforms per merchant | > 2 |
