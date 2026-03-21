# Emakola — Monitoring & Observability

## Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| APM | Phoenix Telemetry + PromEx | Metrics collection |
| Logging | Logger + JSON formatter | Structured logging |
| Alerting | Fly.io Metrics + PagerDuty | Incident detection |
| Uptime | BetterStack (formerly BetterUptime) | External monitoring |
| Error Tracking | Sentry | Exception tracking |

## Health Check Endpoint

```elixir
# GET /health → 200 OK
defmodule EmakolaWeb.HealthController do
  use EmakolaWeb, :controller

  def show(conn, _params) do
    checks = %{
      database: check_database(),
      oban: check_oban(),
      storage: check_s3()
    }

    status = if Enum.all?(Map.values(checks)), do: :ok, else: :service_unavailable

    json(conn, %{
      status: if(status == :ok, "healthy", "degraded"),
      version: Application.spec(:emakola, :vsn) |> to_string(),
      timestamp: DateTime.utc_now(),
      checks: checks
    })
  end
end
```

## Key Metrics

### Application Metrics
| Metric | Type | Alert Threshold |
|--------|------|----------------|
| HTTP request duration (P95) | Histogram | > 2s warning, > 5s critical |
| HTTP error rate (5xx) | Counter | > 1% warning, > 5% critical |
| LiveView WebSocket connections | Gauge | — |
| LiveView crash rate | Counter | > 0.5% critical |
| Active sessions | Gauge | — |

### Business Metrics
| Metric | Type | Alert Threshold |
|--------|------|----------------|
| Orders created per hour | Counter | < 50% of baseline → warning |
| Payment success rate | Gauge | < 95% warning, < 90% critical |
| Payment gateway latency | Histogram | > 10s critical |
| Mobile money callback delay | Histogram | > 60s warning |
| Merchant signups per day | Counter | — |
| Storefront page load time | Histogram | > 3s on 3G → warning |

### Infrastructure Metrics
| Metric | Type | Alert Threshold |
|--------|------|----------------|
| CPU utilization | Gauge | > 80% warning, > 95% critical |
| Memory utilization | Gauge | > 85% warning, > 95% critical |
| DB connection pool usage | Gauge | > 80% critical |
| Oban job queue depth | Gauge | > 1000 warning |
| Oban job failure rate | Counter | > 5% critical |
| Disk usage | Gauge | > 80% warning |

## Logging Strategy

### Structured JSON Logging
```elixir
# config/prod.exs
config :logger, :console,
  format: {Jason.Formatter, :format},
  metadata: [:request_id, :store_id, :merchant_id, :order_id]
```

### Log Levels
| Level | Use For | Example |
|-------|---------|---------|
| `:debug` | Dev-only detail | SQL queries, assigns |
| `:info` | Business events | Order created, payment received, merchant signup |
| `:warning` | Recoverable issues | Payment retry, slow query, rate limit hit |
| `:error` | Failures | Payment failed, webhook error, service timeout |

### Critical Events to Log
```elixir
# Always log these with full context:
Logger.info("order_created", %{order_id: id, store_id: store_id, total: total, currency: currency})
Logger.info("payment_received", %{order_id: id, gateway: :paystack, method: :mtn_momo, amount: amount})
Logger.info("payment_failed", %{order_id: id, gateway: :hubtel, error: reason})
Logger.info("merchant_signup", %{merchant_id: id, email: masked_email, plan: :free})
Logger.warning("payment_retry", %{order_id: id, attempt: 2, gateway: :paystack})
Logger.error("webhook_error", %{gateway: :paystack, error: reason, payload_hash: hash})
```

### PII Handling
```elixir
# NEVER log: full phone numbers, emails, passwords, card numbers, MoMo PINs
# ALWAYS mask: phone → +233****4567, email → a***@example.com
defp mask_phone("+233" <> rest), do: "+233****" <> String.slice(rest, -4, 4)
defp mask_email(email) do
  [name, domain] = String.split(email, "@")
  String.first(name) <> "***@" <> domain
end
```

## Alerting Rules

### P1 — Critical (immediate response)
- Payment gateway completely down (0% success for 5 min)
- Database unreachable
- Application crash loop (> 3 restarts in 5 min)
- All SMS/WhatsApp delivery failing

### P2 — High (respond within 1 hour)
- Payment success rate < 90%
- Error rate > 5%
- Oban queue depth > 5000
- Response time P95 > 5s

### P3 — Medium (respond within 24 hours)
- Payment success rate < 95%
- Oban job failure rate > 5%
- Storage usage > 80%
- Memory usage sustained > 85%

### P4 — Low (next business day)
- Slow queries > 1s
- Non-critical background job failures
- Rate limiting triggered frequently

## Incident Response

### On-Call Rotation
- Primary: responds to P1/P2 within 15min
- Secondary: backup, handles P3

### Runbook: Payment Gateway Down
1. Check gateway status page (status.paystack.com / hubtel.com/status)
2. Check if specific to us or global outage
3. If our issue: check webhook endpoint, verify secrets, check rate limits
4. If gateway issue: enable feature flag to show "card payments temporarily unavailable"
5. Route to alternative gateway if available
6. Notify affected merchants via SMS
7. Post-incident: document timeline, root cause, prevention

### Runbook: High Error Rate
1. Check Sentry for error grouping
2. Identify: is it one store or all stores?
3. Check recent deployments (rollback if correlated)
4. Check database health (connections, locks, slow queries)
5. Check external service health (payment gateways, SMS providers)
6. Mitigate → Fix → Document
