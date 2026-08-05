# Emakola monitoring and observability

This document describes what the repository actually ships. Dashboard and
alert-provider setup is operational work outside this repository; recommended
alerts are explicitly labelled below.

## Shipped stack

| Layer | Implementation | Status |
| --- | --- | --- |
| Health | `GET /api/health` on the public Phoenix service | Shipped |
| Metrics | Prometheus 0.0.4 exposition on a private Bandit listener | Shipped |
| Scraping | Fly `[metrics]`, port `9091`, path `/metrics` | Configured |
| Request telemetry | `[:phoenix, :endpoint, :stop]` counters in bounded ETS keys | Shipped |
| Error reporting | Sentry logger handler when `SENTRY_DSN` is configured | Shipped |
| Logs | Elixir Logger with `request_id` metadata | Shipped |
| Dashboards/alerts | Fly/Grafana/PagerDuty/Better Stack | Not provisioned here |

The public HTTP service exposes port `4000`. Metrics use a separate listener on
`METRICS_PORT` (default `9091` in production), so `/metrics` is not a public
storefront route. Fly scrapes that listener directly from inside the machine.

## Health check

`GET /api/health` performs `SELECT 1` against the primary database:

- `200 {"status":"ok"}` when the database is reachable.
- `503 {"status":"error","message":"database unreachable"}` otherwise.

Fly calls it every 15 seconds with a five-second timeout. This is a readiness
signal, not a complete dependency audit: payment, messaging, storage, and search
providers are intentionally not called from the health request.

## Exported metrics

The exporter emits bounded operational labels only. It never labels by store,
merchant, customer, request path, email, phone, token, or payload.

| Metric | Type | Meaning |
| --- | --- | --- |
| `emakola_up` | gauge | Metrics process is running |
| `emakola_database_up` | gauge | Primary database query succeeded |
| `emakola_vm_memory_bytes{kind}` | gauge | BEAM memory by fixed VM category |
| `emakola_vm_process_count` | gauge | Current BEAM process count |
| `emakola_vm_process_limit` | gauge | Configured BEAM process limit |
| `emakola_vm_run_queue` | gauge | Scheduler run queue |
| `emakola_cluster_nodes` | gauge | This node plus connected nodes |
| `emakola_http_requests_total{status_class}` | counter | Completed requests by `1xx`–`5xx`/`unknown` |
| `emakola_http_request_duration_seconds_sum` | counter | Cumulative endpoint duration |
| `emakola_http_request_duration_seconds_count` | counter | Requests in the duration aggregate |
| `emakola_oban_metrics_up` | gauge | Oban aggregation query succeeded |
| `emakola_oban_jobs{queue,state}` | gauge | Incomplete jobs by bounded queue/state |

The duration pair supports an average. It does not claim to provide a p95; add a
histogram exporter before configuring percentile alerts.

## Configuration

Production defaults to:

```text
METRICS_PORT=9091
SENTRY_DSN=<optional Sentry project DSN>
SENTRY_RELEASE=<optional release identifier>
```

`fly.toml` must use the same metrics port and `/metrics` path. Do not add the
metrics port to `http_service`; it is intentionally private.

## Recommended alert policy (not provisioned by this repository)

- Critical: `emakola_up == 0` or `emakola_database_up == 0` for two scrapes.
- Critical: public health check fails from two regions for five minutes.
- High: 5xx share exceeds 5% for five minutes with meaningful request volume.
- High: `emakola_oban_metrics_up == 0` or incomplete jobs grow continuously for
  15 minutes.
- High: VM memory exceeds 85% of the Fly machine limit for ten minutes.
- Medium: run queue remains above the online scheduler count for ten minutes.
- Medium: `emakola_cluster_nodes` differs from the intended machine count.

Payment success, callback delay, and notification delivery rates are important
business alerts but are not exported by the current endpoint. Do not create
dashboards that imply those signals exist until their domain telemetry ships.

## Incident triage

### Database unavailable

1. Confirm `/api/health` and `emakola_database_up` agree.
2. Check Fly Postgres reachability, connection count, locks, and recent deploys.
3. Stop retry storms or non-essential workers before increasing pool size.
4. Restore health, then inspect failed/retryable Oban jobs.

### High error rate

1. Inspect Sentry groups and correlate the first occurrence with deploy time.
2. Compare 5xx growth with VM memory, run queue, database, and Oban signals.
3. Determine whether the failure is global or isolated to one provider flow.
4. Roll back only when the deploy correlation is established; otherwise degrade
   the failing external feature and preserve checkout/account access.

### Oban backlog

1. Identify the queue/state labels that are growing.
2. Inspect retry reasons without logging job payloads or credentials.
3. Verify the downstream provider before increasing concurrency.
4. Drain idempotent jobs first and monitor database pool pressure.

## Verification

The repository verifies exporter rendering, database/Oban collection, bounded
HTTP counters, content type, and the private Plug's 404 behavior in:

- `test/emakola/metrics_test.exs`
- `test/emakola/metrics/endpoint_test.exs`

CI compiles the dedicated Bandit listener and exercises the exporter. Before a
deploy, validate `fly.toml` with Fly's CLI; after deployment, confirm the Fly
metrics target is healthy before treating the exporter as an alert source.
