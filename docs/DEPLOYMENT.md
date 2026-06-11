# Emakola Deployment Guide

Production deployment guide for the Emakola ecommerce platform on Fly.io.

> **Credential setup:** step-by-step provider configuration (Paystack, Resend, SMS, WhatsApp templates, generated secrets) lives in [PROVIDER_SETUP.md](PROVIDER_SETUP.md). Start the WhatsApp section first — Meta approval takes days.

---

## Infrastructure Overview

```
                         Cloudflare CDN
                              |
                     DDoS protection + caching
                              |
                         Fly.io Edge
                        (jnb region)
                              |
              +---------------+---------------+
              |               |               |
         App Instance    App Instance    App Instance
         (Phoenix)       (Phoenix)       (Phoenix)
              |               |               |
              +-------+-------+
                      |
               Fly Postgres 15+
               (jnb region)
                      |
              Oban (background jobs)

         Tigris/S3 ── image & file storage
```

| Component               | Service                          | Region              |
|-------------------------|----------------------------------|----------------------|
| Application hosting     | Fly.io                           | jnb (Johannesburg)   |
| PostgreSQL database     | Fly Postgres (or Neon/Supabase)  | jnb                  |
| Background jobs         | Oban (in-app, backed by Postgres)| jnb                  |
| Image/file storage      | Tigris (S3-compatible on Fly.io) | auto (global CDN)    |
| CDN & DDoS protection   | Cloudflare                       | Global edge          |
| DNS                     | Cloudflare                       | Global               |
| SSL certificates        | Fly.io (auto) + Cloudflare       | -                    |
| Transactional SMS       | HTTP SMS gateway (SMS_API_URL)   | -                    |
| Payment processing      | Paystack, Hubtel Payments        | -                    |

---

## Prerequisites

- [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/) installed and authenticated
- Docker installed locally (for builds)
- Cloudflare account with domain configured
- Payment gateway sandbox/live credentials

---

## Fly.io Initial Setup

### 1. Launch the Application

```bash
# From the project root
fly launch --name emakola --region jnb --no-deploy

# Create the PostgreSQL database
fly postgres create --name emakola-db --region jnb --vm-size shared-cpu-1x --volume-size 10

# Attach the database (sets DATABASE_URL automatically)
fly postgres attach emakola-db --app emakola

# REQUIRED with Fly Postgres: the attached *.internal database uses Fly's
# private network (already isolated) with an internal CA that is NOT in the
# system trust store — the default DATABASE_SSL=true (verify_peer) would
# fail the TLS handshake during the migration release_command and block the
# very first deploy. Skip ONLY if you use an external database with a
# publicly-trusted certificate (then keep the verify_peer default).
fly secrets set DATABASE_SSL=false --app emakola
```

### 2. Create Tigris Storage Bucket

```bash
fly storage create --name emakola-uploads --region jnb --app emakola
```

This sets the following secrets automatically:
- `BUCKET_NAME`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINT_URL_S3`
- `AWS_REGION`

### 3. Allocate IP Addresses

```bash
fly ips allocate-v4 --shared --app emakola
fly ips allocate-v6 --app emakola
```

---

## Environment Configuration

### Generate Secret Key Base

```bash
mix phx.gen.secret
# Copy the output
```

### Set Production Secrets

All of the following are **required** — `config/runtime.exs` raises at boot
if any is missing (`PHX_HOST`, `PHX_SERVER`, `POOL_SIZE`, `ECTO_IPV6` are
non-secret and already set in `fly.toml [env]`; `DATABASE_URL` comes from
`fly postgres attach`):

```bash
fly secrets set \
  SECRET_KEY_BASE="<mix phx.gen.secret>" \
  TOKEN_SIGNING_SECRET="<mix phx.gen.secret 64>" \
  \
  # Email (Swoosh/Resend — transactional email)
  RESEND_API_KEY="re_xxxxx" \
  \
  # Payment gateway
  PAYSTACK_SECRET_KEY="sk_live_xxxxx" \
  \
  # SMS / WhatsApp — notifications are business-critical; the release
  # raises rather than silently no-op if these are missing
  SMS_API_KEY="xxxxx" \
  SMS_API_URL="https://sms.yourprovider.example/v1/messages" \
  WHATSAPP_API_TOKEN="xxxxx" \
  WHATSAPP_PHONE_NUMBER_ID="xxxxx" \
  \
  --app emakola
```

Optional secrets, set as applicable:

```bash
fly secrets set \
  PAYSTACK_PUBLIC_KEY="pk_live_xxxxx" \
  SMS_SENDER_ID="Emakola" \
  WHATSAPP_API_VERSION="v21.0" \
  \
  # Hubtel payments (optional at launch). NOTE: Hubtel webhooks are
  # validated only by source IP — if HUBTEL_WEBHOOK_ALLOWLIST is empty,
  # /webhooks/hubtel rejects EVERY request (fail closed).
  HUBTEL_CLIENT_ID="xxxxx" \
  HUBTEL_CLIENT_SECRET="xxxxx" \
  HUBTEL_WEBHOOK_ALLOWLIST="203.0.113.5,198.51.100.0/24" \
  \
  # Database TLS opt-out — ONLY for Fly 6PN .internal Postgres
  DATABASE_SSL="false" \
  \
  # S3-compatible storage. `fly storage create` (Tigris) sets BUCKET_NAME,
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL_S3 and
  # AWS_REGION automatically — only set these manually for non-Tigris S3.
  # Missing S3 credentials warn at boot (uploads degrade, app still runs).
  AWS_S3_BUCKET="emakola-uploads" \
  AWS_S3_REGION="auto" \
  AWS_ENDPOINT_URL_S3="https://fly.storage.tigris.dev" \
  AWS_ACCESS_KEY_ID="xxxxx" \
  AWS_SECRET_ACCESS_KEY="xxxxx" \
  \
  --app emakola
```

> **Note**: `DATABASE_URL` is set automatically by `fly postgres attach`. Do not set it manually.

### Database TLS (`DATABASE_SSL`)

The app verifies the database server's TLS certificate by default
(`verify_peer` against the OS trust store, with hostname checking).

- **Fly Postgres over private networking** (`DATABASE_URL` host ends in
  `.internal`): Fly Postgres does not present a publicly verifiable
  certificate, and the 6PN private network is already encrypted (WireGuard).
  Set `DATABASE_SSL=false`:
  ```bash
  fly secrets set DATABASE_SSL=false --app emakola
  ```
- **External database** (Neon, Supabase, RDS, any public endpoint): keep the
  default (`DATABASE_SSL` unset or `true`) so the connection is encrypted
  AND the server identity is verified. Never set it to `false` for a
  database reached over the public internet.

### WhatsApp Notifications

In prod, `:whatsapp_provider` is wired to the real Cloud API channel
(`Emakola.Notifications.Channels.WhatsApp`), which implements the
`send_message/4` provider bridge. Template messages are positional: the
templates registered in the WhatsApp Business Manager console
(`order_placed`, `order_confirmed`, `order_shipped`, `order_delivered`,
`order_cancelled`, `supplier_fulfillment`) must declare their `{{n}}`
placeholders in the parameter order defined in the channel's
`@template_param_order` — adding a new template requires registering it
with Meta AND adding its parameter order there.

### Non-Secret Environment Variables

These go in `fly.toml` under `[env]`:

```toml
[env]
  PHX_HOST = "emakola.com"
  PHX_SERVER = "true"
  ECTO_IPV6 = "true"
  POOL_SIZE = "10"
  LANG = "en_US.UTF-8"
  ERL_AFLAGS = "-proto_dist inet6_tcp"
  DNS_CLUSTER_QUERY = "emakola.internal"
```

---

## Dockerfile

See `/Dockerfile` in the project root. Multi-stage build:

1. **Builder stage**: Elixir 1.18 + Erlang/OTP 27 + Node.js 20
   - Installs hex/rebar
   - Compiles dependencies
   - Builds Tailwind/esbuild assets
   - Creates a Mix release
2. **Runner stage**: Debian Bookworm slim
   - Copies the release
   - Runs as non-root user
   - Exposes port 4000

---

## fly.toml Configuration

See `/fly.toml` in the project root. Key settings:

- Primary region: `jnb` (Johannesburg)
- HTTP service on internal port `4000`
- Health check at `GET /api/health`
- Auto start/suspend with `min_machines_running = 1` (carts are
  Postgres-backed, so stop/suspend and multi-machine are both safe)
- 512MB memory per instance
- `kill_timeout = "60s"` for safe shutdowns

---

## Release Module

Create `lib/emakola/release.ex`:

```elixir
defmodule Emakola.Release do
  @moduledoc """
  Tasks that can be run in production without Mix installed.

  Usage:
    /app/bin/emakola eval "Emakola.Release.migrate()"
    /app/bin/emakola eval "Emakola.Release.seed()"
    /app/bin/emakola eval "Emakola.Release.rollback(Emakola.Repo, 20240101000000)"
  """

  @app :emakola

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          seed_file = Application.app_dir(@app, "priv/repo/seeds.exs")

          if File.exists?(seed_file) do
            Code.eval_file(seed_file)
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
```

---

## Database Migrations

### Run Migrations in Production

```bash
# Via fly ssh
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.migrate()'"

# Or via fly machine run (one-off)
fly machine run . --entrypoint "/app/bin/emakola eval 'Emakola.Release.migrate()'" --app emakola
```

### Safe Migration Practices

1. **Never rename columns directly** -- add new, migrate data, drop old
2. **Never drop columns** in the same deploy that stops reading them
3. **Add indexes concurrently** when possible:
   ```elixir
   create index(:products, [:merchant_id, :status], concurrently: true)
   ```
4. **Use `@disable_ddl_transaction true`** for concurrent index creation
5. **Test migrations against a production-sized dataset** before deploying

### Rollback

```bash
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.rollback(Emakola.Repo, 20240601000000)'"
```

---

## Deployment

### First Deploy

```bash
# Ensure fly.toml and Dockerfile are ready
fly deploy --app emakola

# Run migrations
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.migrate()'"

# Seed initial data (currencies, categories, etc.)
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.seed()'"
```

### Subsequent Deploys

```bash
# Standard deploy (rolling, zero-downtime)
fly deploy --app emakola

# If migrations are needed, run after deploy completes
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.migrate()'"
```

### Deployment with Migrations (Automated)

Add to `rel/overlays/bin/migrate`:
```bash
#!/bin/sh
set -eu
/app/bin/emakola eval "Emakola.Release.migrate()"
```

Then in `fly.toml`:
```toml
[deploy]
  release_command = "/app/bin/migrate"
```

This runs migrations automatically before each deploy.

---

## Zero-Downtime Deployments

Fly.io performs rolling deployments by default:

1. New instances are started with the new release
2. Health checks must pass before old instances are stopped
3. Old instances receive SIGTERM and get a grace period to finish requests
4. Connections drain gracefully

### Ensure Safe Shutdowns

In `config/runtime.exs`:
```elixir
# Give Oban time to finish running jobs on shutdown
config :emakola, Oban,
  shutdown_grace_period: :timer.seconds(15)
```

In `lib/emakola/application.ex`, Phoenix is already configured for graceful shutdown.

---

## SSL and Custom Domains

### Primary Domain

```bash
# Add custom domain
fly certs create emakola.com --app emakola
fly certs create www.emakola.com --app emakola

# Check certificate status
fly certs show emakola.com --app emakola
```

### Cloudflare DNS Configuration

Set DNS records in Cloudflare:

| Type  | Name          | Content                    | Proxy |
|-------|---------------|----------------------------|-------|
| CNAME | @             | emakola.fly.dev            | Yes   |
| CNAME | www           | emakola.fly.dev            | Yes   |

Set Cloudflare SSL mode to **Full (Strict)**.

### Wildcard SSL for Merchant Subdomains

For `*.emakola.com` (e.g., `shopname.emakola.com`):

```bash
fly certs create "*.emakola.com" --app emakola
```

Cloudflare handles wildcard DNS:

| Type  | Name | Content            | Proxy |
|-------|------|--------------------|-------|
| CNAME | *    | emakola.fly.dev    | Yes   |

### Custom Merchant Domains

For merchants who bring their own domain (e.g., `www.merchantshop.com`):

1. Merchant adds a CNAME record pointing to `emakola.fly.dev`
2. Add the certificate on Fly.io:
   ```bash
   fly certs create www.merchantshop.com --app emakola
   ```
3. Application resolves the merchant by hostname in a Phoenix plug:
   ```elixir
   defmodule EmakolaWeb.Plugs.ResolveMerchant do
     def call(conn, _opts) do
       host = conn.host
       merchant = Emakola.Merchants.get_by_domain(host)
       assign(conn, :current_merchant, merchant)
     end
   end
   ```

---

## Scaling

> **Carts are Postgres-backed — horizontal scaling is safe.**
>
> Shopping carts live in the `cart_items` table (`lib/emakola/cart/`), so
> every machine sees every cart and machine stops/suspends lose nothing.
> Scale freely with `fly scale count N` — BEAM clustering is already wired
> (`rel/env.sh.eex` + `DNS_CLUSTER_QUERY` + DNSCluster), so PubSub/LiveView
> updates work across machines too.

### Horizontal Auto-Scaling

Configured in `fly.toml` (`[http_service]` section):
```toml
auto_stop_machines = "suspend"
auto_start_machines = true
min_machines_running = 1
```

### Manual Scaling

```bash
# Scale to 3 instances
fly scale count 3 --app emakola

# Scale memory
fly scale memory 1024 --app emakola

# Scale VM size
fly scale vm shared-cpu-2x --app emakola
```

### Database Scaling

```bash
# Scale Postgres
fly scale memory 1024 --app emakola-db
fly volumes extend vol_xxxxx --size 20 --app emakola-db
```

---

## Monitoring

See `docs/MONITORING.md` for full observability strategy.

Quick commands:

```bash
# View logs
fly logs --app emakola

# SSH into running instance
fly ssh console --app emakola

# Open monitoring dashboard
fly dashboard --app emakola

# Check app status
fly status --app emakola

# Check Postgres status
fly status --app emakola-db
```

---

## Backup Strategy

### PostgreSQL Backups

Fly Postgres provides automatic daily backups with WAL-based point-in-time recovery.

```bash
# List backups
fly postgres backup list --app emakola-db

# Restore to a point in time
fly postgres backup restore --app emakola-db --restore-target-time "2026-03-20T12:00:00Z"
```

### Manual Backup

```bash
# Dump database
fly ssh console --app emakola-db -C "pg_dump -Fc emakola" > emakola_backup.dump

# Restore from dump
fly ssh console --app emakola-db -C "pg_restore -d emakola /path/to/dump"
```

### S3/Tigris Uploads

- Enable versioning on the Tigris bucket for accidental deletion recovery
- Set lifecycle policy to archive old versions after 30 days:
  ```bash
  aws s3api put-bucket-versioning \
    --bucket emakola-uploads \
    --versioning-configuration Status=Enabled \
    --endpoint-url https://fly.storage.tigris.dev
  ```

---

## Rollback Procedure

### Application Rollback

```bash
# List recent deployments
fly releases --app emakola

# Rollback to previous release
fly deploy --image registry.fly.io/emakola:deployment-XXXXX --app emakola
```

### Database Rollback

```bash
# Rollback last migration
fly ssh console -C "/app/bin/emakola eval 'Emakola.Release.rollback(Emakola.Repo, 20240601000000)'"
```

> **Warning**: Only roll back database changes if the previous application version is compatible with the rolled-back schema.

---

## Troubleshooting

### Common Issues

| Issue | Diagnosis | Fix |
|-------|-----------|-----|
| App won't start | `fly logs` | Check SECRET_KEY_BASE and DATABASE_URL |
| Database connection refused | `fly status --app emakola-db` | Ensure ECTO_IPV6=true and ERL_AFLAGS set |
| Migrations fail | Check migration output | SSH in and run manually |
| SSL certificate pending | `fly certs show domain.com` | Ensure DNS is pointed correctly |
| Out of memory | `fly logs` (look for OOM) | `fly scale memory 1024` |
| Oban jobs stuck | Check `oban_jobs` table | Restart app or manually rescue jobs |

### Useful Commands

```bash
# Interactive Elixir shell in production
fly ssh console -C "/app/bin/emakola remote"

# Check database connectivity
fly ssh console -C "/app/bin/emakola eval 'Emakola.Repo.query!(\"SELECT 1\")'"

# Check Oban status
fly ssh console -C "/app/bin/emakola eval 'Oban.check_queue(:default)'"
```
