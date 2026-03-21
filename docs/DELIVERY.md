# Emakola — Delivery & Rider Marketplace

## Problem

Delivery in Ghana is fragmented — individual motorbike riders with no central dispatch, no tracking, no standardized pricing. Merchants currently coordinate deliveries manually via WhatsApp phone calls with 2-3 riders they know personally. Customers have no visibility into when their order will arrive.

## Solution: Rider Marketplace

Emakola connects merchants with independent riders. We don't employ riders — we provide matching, communication, and tracking infrastructure. Think "Uber for ecommerce deliveries" but built on WhatsApp.

## Three Actors

- **Merchant**: Requests rider from order detail page in admin
- **Rider**: Receives and accepts requests via WhatsApp, updates delivery status
- **Customer**: Gets SMS/WhatsApp updates on delivery progress

## Delivery Flow

```
1. Customer places order on storefront
2. Merchant confirms order, clicks "Request Rider" in admin
3. Emakola finds available riders in the area
4. Rider gets WhatsApp message: "New delivery! Pickup: [address], Drop: [address], Fee: GH₵ X. Accept?"
5. Rider taps Accept
6. Merchant sees "Rider assigned: Kofi, ETA 15 min to pickup"
7. Rider picks up → taps "Picked up" in WhatsApp
8. Customer gets SMS: "Your order is on the way! Rider: Kofi"
9. Rider delivers → taps "Delivered" in WhatsApp
10. Customer gets SMS: "Your order has arrived!"
11. Customer rates rider (1-5 stars via SMS link)
```

## Rider Onboarding

### Signup (via WhatsApp)
1. Rider sends message to Emakola WhatsApp number
2. Chatbot collects: Name, phone, coverage area (e.g., "Accra Central")
3. Rider uploads: Ghana Card photo, motorcycle photo
4. Manual approval (initially), automated with ID verification later
5. Rider receives unique code, added to dispatch pool

### Rider Profile
```
Name: Kofi Asante
Phone: +233 24 XXX XXXX
Area: Osu, Labone, East Legon, Cantonments
Vehicle: Honda CG 125 (Red)
Rating: 4.8 ★ (142 deliveries)
Status: Available
Joined: March 2026
```

### Requirements
- Valid Ghana Card (government ID)
- Registered motorcycle
- Active MTN/Vodafone number (for MoMo payouts)
- Smartphone with WhatsApp
- Pass background check (future phase)

## Delivery Fee Structure

### Zone-Based Pricing (Accra defaults — merchant can customize)
| Zone | Distance | Fee Range |
|------|----------|-----------|
| Same area | < 3km | GH₵ 10-15 |
| Cross-city | 3-10km | GH₵ 15-25 |
| Long distance | 10-25km | GH₵ 25-40 |
| Inter-city | 25km+ | GH₵ 40+ (custom quote) |

### Revenue Split
- **Rider receives**: 90% of delivery fee
- **Emakola commission**: 10% of delivery fee
- **Payout**: Daily settlement to rider's MoMo account

### Merchant Options
- **Use Emakola riders**: Request from marketplace, fee added to customer checkout
- **Use own rider**: Merchant handles delivery, sets flat fee
- **Customer pickup**: No delivery fee, merchant provides pickup location
- **Free delivery**: Merchant absorbs cost (marketing tool, above order threshold)

## Rider Communication (WhatsApp)

### Delivery Request Message
```
🛍 New Delivery Request!

Pickup: 15 Oxford Street, Osu
Drop-off: 42 Jungle Road, East Legon
Distance: ~6km
Fee: GH₵ 18

Package: 1 item (small box)
Notes: Call customer on arrival

Reply:
1️⃣ Accept
2️⃣ Decline
```

### Status Update Messages
```
Rider replies:
"1" or "Accept" → Accepted, merchant notified
"Picked up" → Status updated, customer notified
"Delivered" → Status updated, customer notified, payout queued

Auto-prompts:
After 30 min of no pickup update → "Have you picked up order #EM-4821?"
After 60 min of no delivery update → "Status update for order #EM-4821?"
```

## Customer Notifications

### Standard (All Plans) — SMS Status Updates
```
[Order Confirmed]
Your order from {store} has been confirmed! A rider will pick it up soon.
Order: #{number} | Total: GH₵{amount}

[Rider Assigned]
Rider {name} is heading to pick up your order. ETA: {time} min.
Questions? Call {rider_phone}

[On The Way]
Your order is on the way! Rider: {name} ({phone})
Estimated arrival: {time}

[Delivered]
Your order has been delivered!
Rate your delivery: {rating_link}
```

### Pro Plan — Live GPS Tracking
- Customer receives tracking link in SMS/WhatsApp
- Opens lightweight web page (no app install)
- Shows: map with rider location, ETA, rider info
- Rider's phone sends GPS coordinates every 30 seconds via the tracking page
- Page auto-refreshes, works on 3G

### GPS Tracking Implementation
```
Rider opens tracking link (from WhatsApp) →
  Browser requests location permission →
  JavaScript sends GPS to Emakola API every 30s →
  Customer's tracking page polls API every 10s →
  Map updates with rider position

Tech: Simple HTML page with Leaflet.js + OpenStreetMap (free, no Google Maps API needed)
```

## Merchant Admin Integration

### Order Detail — Delivery Section
```
┌─────────────────────────────────────┐
│ DELIVERY                            │
│                                     │
│ Method: Emakola Rider               │
│ Status: On the way                  │
│ Rider: Kofi Asante ★ 4.8           │
│ Phone: +233 24 XXX XXXX            │
│                                     │
│ Pickup: 15 Oxford St, Osu           │
│ Drop: 42 Jungle Rd, East Legon      │
│ Fee: GH₵ 18                         │
│                                     │
│ Timeline:                           │
│ ✓ 2:15 PM — Requested              │
│ ✓ 2:16 PM — Rider accepted         │
│ ✓ 2:28 PM — Picked up              │
│ ● 2:45 PM — On the way             │
│ ○ ~3:10 PM — Estimated delivery     │
│                                     │
│ [Contact Rider]  [Report Issue]     │
└─────────────────────────────────────┘
```

### Delivery Settings Page
- Toggle: Enable Emakola Riders (on/off)
- Default pickup address
- Delivery zones and custom pricing
- Free delivery threshold (e.g., free over GH₵ 200)
- Rider preferences (preferred riders list)

## Rating System

### Customer Rates Rider
- After delivery, customer gets SMS: "Rate your delivery: {link}"
- 1-5 stars + optional comment
- Displayed on rider profile

### Rating Thresholds
| Rating | Action |
|--------|--------|
| 4.5+ ★ | Priority dispatch, badge on profile |
| 3.5-4.5 ★ | Normal operation |
| 3.0-3.5 ★ | Warning notification to rider |
| Below 3.0 ★ | Suspended (after 20+ deliveries) |

### Merchant Rates Rider
- Separate rating for professionalism, timeliness
- Affects rider's priority for that merchant's future orders

## Safety & Trust

### Verification
- Ghana Card verified during onboarding
- Phone number verified via OTP
- Vehicle photo on file

### Delivery Confirmation
- Rider takes photo of delivered package (optional, encouraged)
- OR customer confirms via SMS: "Reply YES to confirm delivery"
- Disputes resolved through Emakola support

### Cash on Delivery Handling
- Rider collects payment from customer
- Rider settles with Emakola via MoMo
- Emakola settles with merchant (minus commission)
- Daily settlement cycle
- Trust score: riders with good history get higher COD limits

## Phased Rollout

### MVP (Phase 1)
- Rider onboarding via WhatsApp (manual approval)
- Delivery request from merchant admin
- WhatsApp-based dispatch (accept/decline)
- SMS status updates to customer (4 stages)
- Basic rating system
- Zone-based pricing (Accra only)
- MoMo daily payout to riders

### Growth (Phase 2)
- Auto-dispatch algorithm (nearest available rider)
- Live GPS tracking for Pro plan
- Rider earnings dashboard (WhatsApp-based weekly summary)
- Multi-city: Kumasi, Tema, Takoradi
- Delivery time estimates based on historical data

### Scale (Phase 3)
- Rider PWA for full feature access
- Route optimization (multiple deliveries)
- Scheduled deliveries (merchant sets pickup windows)
- Inter-city delivery network
- Rider insurance/protection program
- Nigeria expansion with local rider pools

## Key Metrics

| Metric | Target |
|--------|--------|
| Rider acceptance rate | > 80% |
| Average pickup time | < 20 min |
| Average delivery time | < 45 min (same city) |
| Customer satisfaction | > 4.5 ★ |
| Delivery success rate | > 98% |
| Rider payout time | < 24 hours |
