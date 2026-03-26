# Emakola Server Capacity Benchmark

> Date: March 25, 2026 | Stack: Elixir/Phoenix LiveView on Fly.io

---

## The Short Answer

On the **current Fly.io setup** (shared-cpu-1x, 512MB RAM, pool size 10):

| User Type | Estimated Concurrent Users | Basis |
|-----------|---------------------------|-------|
| **LiveView connections (active)** | ~150-300 | ~3MB active, hibernates to ~150KB after 15s |
| **LiveView connections (mostly idle)** | ~800-1,500 | Most connections hibernate; 150KB-1.5KB each |
| **Static storefront pages** | ~2,000-5,000 | No WebSocket, just HTTP responses |
| **Hard connection limit** | 1,000 | Set in `fly.toml` (soft: 800) |

**Bottleneck is the 512MB RAM and pool size 10**, not Phoenix itself.

---

## What Phoenix/BEAM Can Actually Do

Phoenix's famous benchmark: **2 million WebSocket connections on a single server** (40 cores, 128GB RAM, ~1.5KB per connection). That's the ceiling of the technology. Emakola won't hit it because:

| Factor | Current Config | Constraint |
|--------|-------------|------------|
| RAM | 512MB | ~350MB available after BEAM + OS overhead |
| CPU | 1 shared core (5ms per 80ms) | Throttled; ~6% of a dedicated core |
| DB pool | 10 connections | Max 10 concurrent DB queries |
| Connection limit | 1,000 hard | Fly.io proxy limit |

---

## Memory Math for Emakola

**LiveView connection lifecycle:**
- Active (page interaction): ~3MB
- Idle (after 15s hibernation): ~150KB
- Fully hibernated WebSocket: ~1.5KB

**Realistic scenario (512MB RAM):**

```
Available RAM:           ~350MB (after BEAM overhead)
BEAM system + Oban:      ~80MB
Remaining for connections: ~270MB

If 20% active, 80% hibernated:
- 100 active x 3MB = 300MB  <-- already over budget
- 50 active x 3MB  = 150MB
  + 200 hibernated x 150KB = 30MB
  = 180MB <-- fits

Realistic capacity: ~50-80 concurrent active LiveViews
                    + ~200-500 hibernated connections
```

---

## Database Pool is the Real Bottleneck

With `POOL_SIZE=10`, only **10 concurrent database queries** can run. Every LiveView page load, every product listing, every checkout hits the DB. At 50+ concurrent active users, expect **DB pool checkout timeouts**.

---

## Current Fly.io Configuration (fly.toml)

| Setting | Value |
|---------|-------|
| VM Size | `shared-cpu-1x` (1 shared CPU) |
| Memory | 512 MB |
| Swap | 256 MB |
| HTTP Hard Limit | 1,000 connections |
| HTTP Soft Limit | 800 connections |
| DB Pool Size | 10 |
| Oban Default Queue | 10 workers |
| Oban Mailers Queue | 20 workers |
| Oban Notifications | 5 workers |
| Health Check | `/health` every 15s |

---

## Scaling Recommendations

### Phase 1: Launch (0-100 merchants, 0-500 daily customers)

Bump resources slightly:

```toml
# fly.toml changes
[vm]
  size = "shared-cpu-2x"    # 2 shared cores
  memory = "1gb"             # 1GB RAM

[env]
  POOL_SIZE = "15"           # More DB connections
```

- **Cost:** ~$7-10/mo on Fly.io
- **Capacity:** ~200-500 concurrent LiveView users

### Phase 2: Growth (100-1,000 merchants, 500-5,000 daily customers)

```toml
[vm]
  size = "performance-1x"   # 1 dedicated core
  memory = "2gb"             # 2GB RAM

[env]
  POOL_SIZE = "25"
```

- **Cost:** ~$30-50/mo
- **Capacity:** ~1,000-2,000 concurrent LiveView users

### Phase 3: Scale (1,000-5,000 merchants)

```toml
[vm]
  size = "performance-2x"   # 2 dedicated cores
  memory = "4gb"

[[services.concurrency]]
  hard_limit = 2500
  soft_limit = 2000

[env]
  POOL_SIZE = "40"
```

- **Cost:** ~$60-100/mo
- **Capacity:** ~5,000-10,000 concurrent users
- **Plus:** Add separate Fly Postgres with PgBouncer connection pooler

### Phase 4: 10K+ merchants

Horizontal scaling — multiple app instances behind Fly.io load balancer with distributed PubSub (already configured via `Emakola.PubSub`). Each node handles 5-10K connections.

---

## Key Numbers for Financial Model

| Merchants | Est. Peak Concurrent Users | Server Spec Needed | Monthly Cost |
|-----------|---------------------------|-------------------|-------------|
| 50 | ~100 | shared-cpu-1x, 512MB | $3-5 |
| 200 | ~400 | shared-cpu-2x, 1GB | $7-10 |
| 1,000 | ~2,000 | performance-1x, 2GB | $30-50 |
| 5,000 | ~8,000 | performance-2x, 4GB | $60-100 |
| 10,000 | ~15,000 | 2x performance-2x, 4GB | $120-200 |
| 50,000 | ~50,000 | 4-6 nodes, 4-8GB each | $400-800 |

**Infrastructure cost per merchant drops dramatically at scale:**
- 50 merchants: ~$0.10/merchant/mo
- 1,000 merchants: ~$0.05/merchant/mo
- 10,000 merchants: ~$0.02/merchant/mo
- 50,000 merchants: ~$0.01/merchant/mo

The business plan estimate of GHS 15/merchant/mo (~$1/merchant) is very conservative — actual costs are 10-50x lower.

---

## What Makes Emakola Especially Efficient

1. **LiveView hibernation** — Merchants aren't staring at dashboards 24/7. Most connections hibernate within 15 seconds, dropping from 3MB to 150KB
2. **Storefront is mostly read-only** — Product pages, category browsing can be cached aggressively
3. **Checkout is short-lived** — 3-5 minute sessions, then connection closes
4. **Oban offloads heavy work** — Payment webhooks, notifications, image processing happen in background workers, not in the LiveView process

---

## Sources

- [The Road to 2 Million WebSocket Connections in Phoenix](https://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections)
- [Phoenix LiveView v1.1.27 Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [Fly.io CPU Performance Docs](https://fly.io/docs/machines/cpu-performance/)
- [Fly.io WebSocket Connection Limits Discussion](https://community.fly.io/t/is-there-a-concurrent-websocket-connections-limit/3229)
- [OOM on Small Phoenix App - Fly.io Forum](https://community.fly.io/t/oom-on-small-elixir-phoenix-application/25850)
- [Phoenix LiveView Optimization Guide](https://dev.to/manhvanvu/phoenix-liveview-optimization-guide-3gkj)
- [Fly.io Scale Machine CPU and RAM](https://fly.io/docs/launch/scale-machine/)
