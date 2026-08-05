# Emakola

Emakola is a multi-tenant commerce platform built with Phoenix LiveView, Ash,
PostgreSQL, and Oban. It provides merchant administration, branded storefronts,
catalogue and inventory management, checkout and payments, fulfilment,
notifications, analytics, and JSON APIs.

## Local development

The supported development stack is Elixir 1.18+, Erlang/OTP 27+, PostgreSQL,
and Node.js 20+. The default development database credentials are
`postgres:postgres` on `localhost`, with database `emakola_dev`.

```bash
mix setup
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000). `mix setup` fetches
dependencies, creates and migrates the database, seeds development data, and
builds the asset bundles.

Phoenix does not automatically load `.env` files. [`.env.example`](.env.example)
is a complete configuration reference; export only the values needed through
your shell, `direnv`, container runtime, or deployment platform. Development
defaults deliberately keep external providers disabled or use inert adapters.

## Verification

```bash
# Unit, integration, controller, and LiveView tests
mix test

# Compile, formatting, Credo, dependency audit, Sobelow, and coverage gate
mix precommit

# Production asset compilation and digest
mix assets.deploy
```

Browser tests live in `e2e/` and use Playwright:

```bash
cd e2e
npm ci
npx playwright install chromium webkit
npm test
```

The CI workflow also runs the application-backed browser suite and a real
Chromium PDF-rendering test. When running tests concurrently in multiple
worktrees, give each process a unique `MIX_TEST_PARTITION` and `MIX_BUILD_PATH`
so database and compiler artifacts do not collide.

## Architecture and safety boundaries

- Ash resources and policies implement domain behaviour and authorization.
- Store-owned data is tenant-scoped. Any administrative read or mutation must
  carry the authenticated actor and current store tenant.
- PostgreSQL is the source of truth. Oban runs durable background work; PubSub
  distributes cache invalidations and rate-limit events across clustered nodes.
- Payment webhooks are authenticated and processed idempotently. Refund and
  fulfilment transitions are reconciled transactionally.
- Production metrics are served on the private metrics listener, not the public
  Phoenix router.
- Use the included `Req` client for outbound HTTP calls.

See [Architecture](docs/ARCHITECTURE.md), [Domain model](docs/DOMAIN_MODEL.md),
[Security](docs/SECURITY.md), and [Testing](docs/TESTING.md) before changing a
cross-domain flow.

## Deployment and integrations

Production configuration is fail-fast for core secrets and providers. Start
with [Deployment](docs/DEPLOYMENT.md) and [Provider setup](docs/PROVIDER_SETUP.md),
then use [Monitoring](docs/MONITORING.md) for the private metrics endpoint and
alerts. API routes and authentication are documented in [API](docs/API.md).

Never commit real credentials or customer data. Keep `.env` files untracked and
rotate a credential immediately if it reaches source control or logs.

## Contribution workflow

Follow [AGENTS.md](AGENTS.md) for project-specific Phoenix, LiveView, Ash, and
UI conventions and [CONTRIBUTING.md](CONTRIBUTING.md) for branch and review
expectations. Run `mix precommit` after the final change and resolve every
failure before opening a pull request.
