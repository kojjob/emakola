# Makola Server Capacity Benchmark

> Measured 2026-09-06. Replaces the March 2026 estimates in this file, which were wrong in the direction that matters.

## The short answer

One production machine as it was on the night of the test (Fly `shared-cpu-1x`, 512MB RAM, 256MB swap, `POOL_SIZE=10`) was **memory-bound at roughly 100 live storefront visitors**, and when that line is crossed the OOM killer restarts the whole app: every shopper, every merchant, every Oban job at once. The cause turned out to be garbage kept by idle connection processes, not the pages themselves, and it is fixed on `feature/socket-memory-sweeper`; production was also moved to 1GB the same night.

| What | Measured ceiling on the current machine |
|---|---|
| Concurrent live storefront visitors (page open, socket connected) | **~100 on production today** (60 to 110 depending on swap); 161 to 253 in a fresh 512MB container with unused swap |
| Storefront dead renders (crawlers, first paint, no socket) | ~75 to 80 req/s on production (Aug 5), CPU-bound; 189 req/s in the local 1-CPU container |
| Landing page dead renders | 283 req/s on production (Aug 5); 1,290 req/s locally, where the 10-connection DB pool started queueing |
| Memory per live storefront visitor | **0.93MB**, and LiveView hibernation does not reduce it |
| Fixed cost of the running app, no visitors | BEAM 311MB on production (423MB RSS). Production sits at 58MB RAM free and 46MB swap free **at idle** |

Latency is excellent right up to the wall: with 100 concurrent shoppers browsing, dead renders were p95 36ms, socket joins p95 31ms, click events p95 2ms. The app does not slow down gracefully. It is fast, then it is gone.

## What the March document got wrong

The March estimate assumed 3MB per active LiveView dropping to 150KB after hibernation, giving "150 to 300 active" and "800 to 1,500 idle" connections. Measured: 0.93MB per connection whether it is 2 seconds old or 94 seconds old. The storefront home LiveView keeps everything it rendered in its process heap (eight products with variants, categories and photos, testimonials, review photos, content pages, coupons, delivery zones), and hibernation compacts that heap but cannot drop it. The March document also called the DB pool "the real bottleneck". It is not: across 333,000 storefront queries the pool queue averaged 1ms with zero waits over 50ms.

## Method

- **Local stack, production-shaped.** The production Dockerfile built locally and run at 1 CPU / 512MB / 256MB swap, Postgres at 256MB, `POOL_SIZE=10`, seeded with the standard three-store dataset. Load from k6 v2.1 with a hand-written LiveView client (dead render over HTTP, then `phx_join` over WebSocket, heartbeats, click and form events).
- **Calibration against production.** The Aug 5 production ladder (HTTP dead renders at 25/75/150 concurrent) was replayed locally. One Fly `shared-cpu-1x` delivers about **0.4 of the local core** on storefront renders (75 to 80 req/s vs 189). Memory footprints matched within 3MB (BEAM 311MB prod vs 310 to 320MB local), so memory numbers transfer directly and CPU numbers should be divided by about 2.5.
- **Read-only production confirm** on 2026-09-06, capped at 75 concurrent HTTP and 30 held sockets, no writes:

  | Production run | Result |
  |---|---|
  | `/` landing, 25 then 75 concurrent, 30s each | 573 req/s, med 64ms, p95 177ms, 0 failures |
  | `/savero` storefront, 25 then 75 concurrent | 89.7 req/s, med 515ms, **p95 908ms**, 0 failures (Aug 5: p95 869ms at 75) |
  | 30 live sockets held 40s on `/savero` | dead render p95 49ms, join p95 57ms; **MemAvailable fell 58MB to 32MB**, 0.87MB per visitor |
  | Second Fly machine | stayed stopped throughout; one machine served all of it |
- Vitals sampled every 2s from the app's own Prometheus endpoint (BEAM memory by category, process count, run queue), `docker stats`, `pg_stat_activity`, and an Ecto telemetry probe for pool queue time.

## Ladder results

### 1. HTTP dead renders (the Aug 5 replica)

| Target | Local 1 CPU, 25/75/150 concurrent, 40s each | Production Aug 5 |
|---|---|---|
| `/` landing | 1,290 req/s, med 56ms, p95 120ms, 0 failures; CPU 100%; pool queue avg 14ms, 15,500 queries waited >50ms | 283 req/s at 150 conc, p95 84ms |
| `/s/kente-kingdom` storefront | 189 req/s, med 366ms, p95 805ms, 0 failures; CPU 100%; 13 DB queries per render, pool queue avg 1ms | 70 to 80 req/s knee; p95 869ms at 75 conc; 1.58s and 2.5% failures at 150 |

Reading: dead renders are pure CPU. The storefront page costs about 13 queries plus a heavy render, roughly 7x the landing page. The landing page is cheap enough that it was the only test where the 10-connection pool became a queue.

### 2. Live visitors held open (the real ceiling)

| Run | Result |
|---|---|
| Fast ramp (8 visitors/s), 512MB, swap idle | OOM-killed at **161** held sockets after 16s. BEAM 320MB to 471MB. |
| Slow ramp (2 visitors/s), 512MB + 256MB swap | OOM-killed at **253** held sockets after ~100s. Container RSS pinned at 512MB from 30s onward (swapping). Slope 0.93MB per socket, flat from 17s to 94s: hibernation gave nothing back. |
| Process count | 2.7 BEAM processes per visitor (channel, LiveView, transport). |

Production has 58MB RAM plus 46MB swap free at idle. At 0.93MB each that is **60 to 110 live visitors**, and the machine is already swapping before the first one arrives.

### 3. Shoppers browsing (home, product list, product detail, clicks)

| Concurrent shoppers | Outcome |
|---|---|
| 50 | Stable. BEAM 365 to 380MB, CPU 12 to 24%, container swapping. Dead render p95 36ms, join p95 31ms, events p95 2ms. |
| 100 | Stable. BEAM 430 to 443MB, CPU 25 to 30%. Same latencies. |
| 200 | **OOM-killed 10 seconds into the ramp.** |

CPU never passed 30%. Real shoppers cost memory, not CPU.

### 4. Buyers checking out (add to cart, three checkout steps, cash-on-delivery order, confirmation)

1,238 real orders were written in 3.5 minutes with zero failures.

| Concurrent buyers | CPU | BEAM peak | Orders/min | Latency |
|---|---|---|---|---|
| 10 | 12% | 329MB | ~120 | dead render p95 72ms, socket join p95 82ms, place_order p95 51ms (whole run) |
| 25 | 33% | 347MB | ~270 | |
| 50 | 55% | 378MB | **492** | pool queue avg 0.15ms, no timeouts |

Checkout is the one path that is CPU-shaped rather than memory-shaped: a buyer holds a socket for seconds, not minutes, so 50 concurrent buyers only cost ~60MB. Divided by the 2.5x CPU factor, one production machine should clear roughly **200 orders per minute** at about 20 concurrent buyers before CPU saturates, which is far beyond any traffic Makola will see this year. The order write path (order, line items, Oban jobs, PubSub) is not a scaling concern.

### 5. Merchants in the admin (dashboard and orders page held open)

| Merchants online | BEAM | Outcome |
|---|---|---|
| 10 | 356 to 371MB (+50MB) | Stable. CPU 3 to 5%. Dead render p95 34ms, join p95 41ms. |
| 25 | 414 to 459MB (+130MB) | Stable but swapping hard. CPU under 10%. |
| 50 | | **OOM-killed as the stage began.** |

**About 5MB per merchant session**, five times a storefront visitor. The dashboard and orders LiveViews load the store's orders, metrics and catalogue into the process and keep them there. CPU is irrelevant here (under 10% throughout). On production's ~100MB of headroom, that is **15 to 20 merchants in the admin at the same time**, and a merchant who leaves the dashboard open in a tab holds their 5MB until the socket drops.

### 6. Mobile API (sign in once, poll orders)

Each phone signs in once, then polls `GET /api/v1/orders` every 2s.

| Phones | CPU (peak at sign-in burst) | BEAM peak | req/s | Outcome |
|---|---|---|---|---|
| 25 | 24% (78%) | 320MB | 12 | stable |
| 75 | 46% (105%) | 341MB | 35 | stable |
| 150 | 73% (102%) | 367MB | 66 | stable; med 45ms, p95 191ms, **p99 4.7s** |

Zero failures across 6,307 requests. The p99 is the sign-in bursts: bcrypt costs ~200ms of CPU per password, so one machine verifies about five passwords a second and everything else queues behind a burst. The 15-minute access token keeps sign-ins rare, which is the right design; a synchronized login storm is the only API shape that hurts. (A first run of this ladder showed 73% failures; that was the harness, not the app: forwarded IPs in a private range are treated as proxy hops, so every virtual phone shared one 10-per-minute sign-in bucket.)

### 7. What moves the ceiling

**Half the CPU.** The storefront dead-render ladder at 0.5 CPU: 89.4 req/s, med 784ms, p95 1.71s, 0 failures, CPU 51% of the host core. Throughput scaled exactly with CPU (189 to 89 req/s), and **89.4 req/s at half a core is production's 89.7 req/s tonight**. One Fly `shared-cpu-1x` is half a lab core on this workload; the pool queue rose to 2.2ms average with 2,715 queries waiting over 50ms as renders slowed, still not the constraint.

**Double the memory.** The same held-visitor ramp on a 1GB container (256MB swap): still a straight line at 0.925MB per visitor, OOM-killed at 184s with **about 750 visitors connected** (BEAM 1,013MB). Against 161 to 253 on 512MB, that is three to four times the visitor ceiling.

The rule that falls out of both runs: **live visitors ≈ (RAM − 310MB fixed − ~60MB OS) ÷ 0.93MB**. 512MB gives ~95 on production's real numbers, 1GB gives ~700, 2GB gives ~1,750. For merchants in the admin, divide by 5MB instead: ~130 on 1GB.

## Where the memory goes (measured inside the processes)

- **Fixed: ~310MB BEAM before the first visitor.** Code alone is 117MB (Ash generates large modules), ETS 9MB, and the allocators hold ~130MB of carriers. Identical on production and locally.
- **Per visitor: 0.93MB, and almost none of it is the LiveView.** Inspecting live processes on the bench stack: a hibernated storefront `StoreLive` is **58KB** (products 34KB), `ProductDetailLive` 53KB. The weight is in Bandit's connection processes: the **WebSocket transport idles at 250 to 650KB** and a **keep-alive HTTP/1 handler at 300 to 670KB**. Both do one burst of work (decode the session, JSON-encode the first render), then sit idle, and the BEAM only collects a process when that process allocates, so the burst's garbage stays for the life of the connection. One forced `:erlang.garbage_collect/1` took every transport to **under 8KB**.
- **Per merchant: the 5MB is the same effect, larger.** The dashboard's first render is bigger, and the test held each admin page for 15s, inside LiveView's 15-second hibernation window, so the LiveView heaps (258 to 675KB) had not compacted either. The dashboard refreshes every 5 minutes, so a real merchant's tab does hibernate.

## The fix (branch `feature/socket-memory-sweeper`)

1. **`EmakolaWeb.IdleConnectionSweeper`**: a supervised process that, every 30s, garbage-collects any idle Bandit connection process whose heap is above 64KB. Bandit and WebSock offer no way to hibernate a WebSocket transport, so the sweep is the lever. Tested (5 tests): collects a bloated idle Bandit process, ignores other processes and small heaps, runs on its interval, fails loudly if Bandit renames its handler.
2. **`http_1_options: [gc_every_n_keepalive_requests: 1]`** on the endpoint: Bandit collects a keep-alive HTTP handler after every response instead of every fifth. The Fly proxy holds long-lived connections to the app, so each pooled connection otherwise carries up to five renders of garbage.
3. **`fly.toml` `memory = "1gb"`**, and both production machines were scaled to 1GB live at 02:44 BST (`fly scale memory 1024`, reversible with `512`).

**After-fix measurement (same image build, 1 CPU / 512MB):** Same harness, same 1 CPU / 512MB / 256MB swap container, three builds of the fix:

| Run | Original image | Sweeper every 30s + Bandit GC | Sweeper every 10s | + per-join hook (final) |
|---|---|---|---|---|
| Held visitors before OOM kill (ramp 3.75 to 5 arrivals/s) | 161 to 253 | ~400 | ~490 | ~465 (ramp-rate bound: in-flight garbage dominates a fast ramp; steady state is what matters) |
| Steady state, 150 visitors held, all swept | 0.93MB each | | **0.24MB each** (BEAM +36MB; each WS transport 26KB) | |
| Shoppers browsing (3 pages each) | 100 ok, 200 killed | 100 ok, 200 killed | | **200 ok** (444 to 461MB), 300 killed with CPU already at 90% |
| Merchants in admin (page every 15s) | 25 ok, 50 killed | 50 ok, 100 killed | 50 ok, 100 killed | **100 ok** (449 to 453MB, 0 failures) |
| Storefront dead renders (CPU) | 189 req/s, peak 368MB | 183 req/s, peak 344MB | | |

Two things fell out of the after-runs. First, the timer alone does not handle **churn**: a shopper moving page to page repeats the join burst on every navigation, so at 200 shoppers browsing (~27 joins a second) the garbage arrives faster than a 10-second sweep clears it. That is what `EmakolaWeb.Hooks.CollectTransport` is for: every LiveView collects its own transport 1.5s after a connected mount, and the sweeper stays as the backstop. Second, the admin test is a worst case by construction: it changes page every 15 seconds, exactly LiveView's hibernation delay, so the dashboard process (258 to 675KB fresh) never compacts. A merchant who stays on a page hibernates and costs far less.

The residual 0.24MB per idle visitor is 100KB of process heap (a 58KB LiveView plus a 26KB transport plus the channel bookkeeping) and about 130KB of reference-counted binaries whose owner was not pinned down tonight. Open question, noted for later; it is no longer what decides the machine size.


## What is done and what is left

Done tonight: production app machines are 1GB; the sweeper and Bandit GC setting are on the branch with tests; `fly.toml` carries the 1GB so the next deploy does not shrink the machines back.

Left, in order:

1. **Merge and deploy the branch.** Until it ships, production is on 1GB with the old per-visitor cost: roughly 700 live visitors instead of 100. After it ships the ceiling moves to the CPU number.
2. **Re-run the production confirm after deploy** (`prod_confirm.sh` in the bench harness, read-only) and check `free -m` over `fly ssh`: swap use should stay near zero with visitors on the site.
3. **Then revisit `soft_limit`.** 100 connections was right for a memory-bound 512MB machine. Once the ceiling is CPU, the knee is the 75 to 90 req/s of storefront dead renders, and the proxy should wake the second machine on request rate, not held sockets.
4. **Leave the DB pool alone.** `POOL_SIZE=10` was never the constraint. Production Postgres is a 1GB machine with 640MB available.
5. **Sign-in bursts on the API** are the one CPU shape that hurt (bcrypt, ~200ms each, ~5 per second per machine). Not a problem at today's scale; note it before any "everyone log in now" moment.
6. **Rebuild the capacity table in the financial model** from 310MB fixed plus the measured per-visitor cost after the fix, not the March figures.

## Files

Harness (throwaway, not committed): `scratchpad/bench/` in this session. `lv.js` is the k6 LiveView client; `ladder_http.js`, `ws_hold.js`, `journey_browse.js`, `journey_checkout.js`, `admin.js`, `api.js` are the scenarios; `compose.yml` is the production-shaped stack; `results/` holds every k6 summary, vitals CSV, and Ecto probe reading.
