# Emakola — Feature Flags

## Library
Using [FunWithFlags](https://github.com/tompave/fun_with_flags) — Elixir feature flag library backed by PostgreSQL.

```elixir
# Check flag
if FunWithFlags.enabled?(:whatsapp_notifications, for: store) do
  send_whatsapp(...)
end
```

## Flag Categories

### Release Flags (temporary — remove after full rollout)
| Flag | Description | Status |
|------|-------------|--------|
| `:new_checkout_flow` | Redesigned single-page checkout | Off |
| `:product_reviews` | Customer review system | Off |
| `:enhanced_analytics` | New dashboard charts | Off |
| `:discount_codes` | Promotion/coupon system | Off |

### Ops Flags (permanent — emergency kill switches)
| Flag | Description | Default |
|------|-------------|---------|
| `:paystack_payments` | Paystack gateway | On |
| `:hubtel_payments` | Hubtel mobile money | On |
| `:sms_notifications` | SMS sending | On |
| `:whatsapp_notifications` | WhatsApp sending | On |
| `:image_uploads` | S3 image uploads | On |
| `:guest_checkout` | Allow checkout without account | On |

### Market Flags (per-country rollout)
| Flag | Description | Default |
|------|-------------|---------|
| `:market_ghana` | Ghana features enabled | On |
| `:market_nigeria` | Nigeria features enabled | Off |
| `:market_francophone` | French West Africa | Off |
| `:momo_mtn` | MTN MoMo payment method | On (Ghana) |
| `:momo_vodafone` | Vodafone Cash | On (Ghana) |
| `:momo_airteltigo` | AirtelTigo Money | On (Ghana) |

### Experiment Flags (A/B testing)
| Flag | Description |
|------|-------------|
| `:checkout_single_page` | Single vs multi-step checkout |
| `:pricing_display_variant` | Price format testing |
| `:onboarding_flow_v2` | New merchant onboarding |

## Flag Lifecycle
1. **Create** — disabled by default, merged to main
2. **Internal test** — enable for team accounts
3. **Beta rollout** — enable for 10% of stores
4. **Full rollout** — enable for all
5. **Cleanup** — remove flag checks, delete flag (release flags only)
