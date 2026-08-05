# Development setup

This guide is the canonical local-development setup. Production releases and
external providers are covered by [Deployment](DEPLOYMENT.md) and
[Provider setup](PROVIDER_SETUP.md).

## Prerequisites

| Software | Supported baseline |
|---|---|
| Elixir | 1.18+ |
| Erlang/OTP | 27+ |
| PostgreSQL | 15+ |
| Node.js | 20+ |

The default development and test configuration expects PostgreSQL at
`localhost:5432` with user/password `postgres`/`postgres`. The databases are
named `emakola_dev` and `emakola_test`.

## Install and run

```bash
mix setup
mix phx.server
```

`mix setup` fetches dependencies, creates and migrates the database, runs
`priv/repo/seeds.exs`, installs asset tooling, and builds assets. The web app is
available at [http://localhost:4000](http://localhost:4000).

If your PostgreSQL credentials differ, update your local, uncommitted
development configuration or start a compatible local database. `DATABASE_URL`
is consumed by the production runtime configuration, not by `config/dev.exs`.

## Environment overrides

Phoenix does not load `.env` automatically. [`.env.example`](../.env.example)
lists every runtime setting and explains which values are required. Export
optional development integrations through your shell or use a tool such as
`direnv`; do not commit the populated file.

Development works without production provider credentials:

- uploads use local filesystem storage;
- email and notification delivery use development adapters;
- Paystack uses inert placeholder keys unless test keys are exported;
- OAuth providers remain hidden until their complete credential set is present;
- ChromicPDF starts on demand.

## Database commands

```bash
mix ecto.migrate
mix ecto.gen.migration descriptive_name_using_underscores
mix run priv/repo/seeds.exs
```

Use `mix ecto.reset` only when intentionally replacing your own local database.
It is destructive.

## Tests and quality gates

```bash
# Creates/migrates the test database, then runs ExUnit
mix test

# Run a focused file while debugging
mix test test/path/to/example_test.exs

# The required final gate
mix precommit
```

`mix precommit` compiles with warnings as errors, checks formatting, runs Credo,
audits dependencies, runs Sobelow, and executes tests with the configured
coverage threshold.

For concurrent worktrees, isolate compiler output and database names:

```bash
MIX_BUILD_PATH=/tmp/emakola-build-feature \
MIX_TEST_PARTITION=feature \
mix test test/path/to/example_test.exs
```

## Browser tests

The Playwright project is separate from the application assets:

```bash
cd e2e
npm ci
npx playwright install chromium webkit
npm test
```

The browser suite expects an application server and seeded database; the CI
workflow is the executable reference for ports and environment values.

## Troubleshooting

- Database connection failures: confirm PostgreSQL is running on port 5432 and
  the local credentials match `config/dev.exs` or `config/test.exs`.
- Asset failures: run `mix assets.setup`, then `mix assets.build`.
- A stale test database: run `mix ecto.migrate` under `MIX_ENV=test` before
  considering a reset.
- PDF failures: set `CHROME_EXECUTABLE` to an installed Chromium/Chrome binary
  and run the tagged PDF test described in [Testing](TESTING.md).
