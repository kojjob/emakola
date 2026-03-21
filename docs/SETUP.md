# Emakola Development Environment Setup

Complete guide to setting up the Emakola development environment.

---

## Prerequisites

### Required Software

| Software | Minimum Version | Recommended |
|---|---|---|
| Elixir | 1.18.0 | Latest 1.18.x |
| Erlang/OTP | 27.0 | Latest 27.x |
| PostgreSQL | 15.0 | 15.x or 16.x |
| Git | 2.30+ | Latest |
| Node.js | 20.0+ | 20 LTS (for esbuild/tailwind if not using standalone CLI) |

### Optional but Recommended

| Software | Purpose |
|---|---|
| asdf or mise | Version management for Elixir/Erlang/Node.js |
| Docker | For running PostgreSQL locally |
| direnv | Automatic environment variable loading |

### Installing with asdf (Recommended)

```bash
# Install asdf plugins
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs

# Install versions
asdf install erlang 27.2
asdf install elixir 1.18.2-otp-27
asdf install nodejs 20.11.0

# Set versions (or use .tool-versions in project root)
asdf local erlang 27.2
asdf local elixir 1.18.2-otp-27
asdf local nodejs 20.11.0
```

### PostgreSQL Setup

**macOS (Homebrew):**
```bash
brew install postgresql@15
brew services start postgresql@15
createuser -s postgres  # if needed
```

**Ubuntu/Debian:**
```bash
sudo apt install postgresql-15 postgresql-client-15
sudo systemctl start postgresql
sudo -u postgres createuser --superuser $USER
```

**Docker:**
```bash
docker run -d \
  --name emakola-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:15-alpine
```

---

## Installation

### 1. Clone the Repository

```bash
git clone git@github.com:username/emakola.git
cd emakola
```

### 2. Install Elixir Dependencies

```bash
mix deps.get
```

### 3. Environment Configuration

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your local settings
# At minimum, set DATABASE_URL if your PostgreSQL isn't on default settings
$EDITOR .env
```

If using `direnv`:
```bash
echo 'dotenv' > .envrc
direnv allow
```

Otherwise, source the env file before running commands:
```bash
source .env
```

### 4. Database Setup

```bash
# Create the development and test databases
mix ecto.create

# Run all migrations
mix ecto.migrate

# Seed with sample data (stores, products, etc.)
mix run priv/repo/seeds.exs
```

The seed script creates:
- A demo store ("Accra Market") with sample products
- A test merchant account (email: `merchant@example.com`, password: `password123456`)
- Sample categories and collections
- Sample shipping zones for Greater Accra

### 5. Asset Setup

```bash
# Install and build frontend assets (TailwindCSS, esbuild)
mix assets.setup
mix assets.build
```

### 6. Verify Installation

```bash
# Run the test suite — everything should pass
mix test

# Start the development server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) to see the storefront.

Visit [http://localhost:4000/admin](http://localhost:4000/admin) to access the merchant dashboard.

---

## Environment Variables

All environment variables are documented in `.env.example`. Here is the full reference:

### Application

| Variable | Required | Description | Example |
|---|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string | `ecto://postgres:postgres@localhost/emakola_dev` |
| `SECRET_KEY_BASE` | Yes | Phoenix secret (generate with `mix phx.gen.secret`) | `aG9sZG15YmVlci...` |
| `PHX_HOST` | No | Hostname for URL generation | `localhost` |
| `PHX_PORT` | No | HTTP port | `4000` |
| `POOL_SIZE` | No | Database connection pool size | `10` |

### Payment Gateways

| Variable | Required | Description | Example |
|---|---|---|---|
| `PAYSTACK_SECRET_KEY` | Yes | Paystack API secret key | `sk_test_xxxxxxxxxxxxx` |
| `PAYSTACK_PUBLIC_KEY` | Yes | Paystack publishable key | `pk_test_xxxxxxxxxxxxx` |
| `HUBTEL_CLIENT_ID` | No | Hubtel API client ID | `xxxxxxxx` |
| `HUBTEL_CLIENT_SECRET` | No | Hubtel API client secret | `xxxxxxxxxxxxxxxx` |

### File Storage (S3-Compatible)

| Variable | Required | Description | Example |
|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | Yes | S3 access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Yes | S3 secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_S3_BUCKET` | Yes | S3 bucket name | `emakola-uploads-dev` |
| `AWS_S3_REGION` | Yes | S3 region | `eu-west-1` |

### Notifications

| Variable | Required | Description | Example |
|---|---|---|---|
| `WHATSAPP_API_TOKEN` | No | WhatsApp Business API token | `EAAxxxxxxx...` |
| `WHATSAPP_PHONE_NUMBER_ID` | No | WhatsApp sender number ID | `1234567890` |
| `SMS_API_KEY` | No | SMS gateway API key | `your-sms-api-key` |
| `SMS_SENDER_ID` | No | SMS sender ID | `Emakola` |

### Background Jobs

| Variable | Required | Description | Example |
|---|---|---|---|
| `OBAN_QUEUE_DEFAULT` | No | Default Oban queue concurrency | `10` |
| `OBAN_QUEUE_NOTIFICATIONS` | No | Notifications queue concurrency | `5` |
| `OBAN_QUEUE_WEBHOOKS` | No | Webhooks queue concurrency | `5` |

---

## Database Details

### Development Database
- **Name**: `emakola_dev`
- **Required extensions**: `uuid-ossp`, `citext`
- Extensions are auto-created by migrations

### Test Database
- **Name**: `emakola_test`
- Sandbox mode enabled — tests run in isolated transactions
- Automatically created and migrated when running `mix test`

### Migrations
```bash
# Generate a new migration
mix ecto.gen.migration add_something

# Run pending migrations
mix ecto.migrate

# Rollback the last migration
mix ecto.rollback

# Reset everything (drop, create, migrate, seed)
mix ecto.reset
```

---

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage report
mix test --cover

# Run specific test file
mix test test/emakola/catalog/product_test.exs

# Run specific test by line number
mix test test/emakola/catalog/product_test.exs:42

# Run only domain tests
mix test test/emakola/

# Run only web tests
mix test test/emakola_web/

# Run integration tests
mix test --tag integration

# Run only failed tests from last run
mix test --failed

# Run tests with verbose output
mix test --trace

# Watch mode (requires mix_test_watch)
mix test.watch
```

### Test Tags
- `@tag :integration` — Full integration tests (payment flows, etc.)
- `@tag :slow` — Tests that take longer than usual
- `@tag :external` — Tests that require external services (skipped in CI by default)

---

## Code Quality

```bash
# Format all Elixir files
mix format

# Check formatting without modifying (for CI)
mix format --check-formatted

# Static analysis with Credo
mix credo --strict

# Type checking with Dialyzer (first run takes a while to build PLT)
mix dialyzer

# Security scanning with Sobelow
mix sobelow --config

# Run all quality checks
mix format --check-formatted && mix credo --strict && mix sobelow
```

---

## Useful Development Commands

```bash
# Start Phoenix server
mix phx.server

# Start server with IEx console
iex -S mix phx.server

# Interactive Elixir console
iex -S mix

# Generate an Ash resource
mix ash.gen.resource Emakola.Catalog Emakola.Catalog.Product

# Generate an Ash domain
mix ash.gen.domain Emakola.Catalog

# Run Ash code generation
mix ash.codegen

# Generate a Phoenix LiveView
mix phx.gen.live Admin Product products name:string price:integer

# Generate a migration
mix ecto.gen.migration create_products

# View all routes
mix phx.routes

# Generate a secret key
mix phx.gen.secret
```

---

## Project Structure

```
emakola/
├── CLAUDE.md                    # Claude Code project instructions
├── README.md                    # Project README
├── mix.exs                      # Project configuration
├── .env.example                 # Environment variable template
├── .gitignore
├── config/
│   ├── config.exs               # Base configuration
│   ├── dev.exs                  # Development config
│   ├── test.exs                 # Test config
│   ├── prod.exs                 # Production config
│   └── runtime.exs              # Runtime config (env vars)
├── lib/
│   ├── emakola/                 # Core domain
│   │   ├── accounts/            # Users, auth, roles
│   │   ├── catalog/             # Products, variants, categories
│   │   ├── customers/           # Store customers
│   │   ├── inventory/           # Stock management
│   │   ├── notifications/       # SMS, WhatsApp, email
│   │   ├── orders/              # Orders, line items, fulfillment
│   │   ├── payments/            # Payment gateways, transactions
│   │   ├── shipping/            # Zones, rates, methods
│   │   └── stores/              # Multi-tenant store config
│   ├── emakola_web/             # Phoenix web layer
│   │   ├── components/          # Shared function components
│   │   ├── controllers/         # Webhook receivers, API
│   │   ├── live/                # LiveView modules
│   │   │   ├── admin/           # Merchant dashboard
│   │   │   └── storefront/      # Customer storefront
│   │   ├── plugs/               # Tenant resolution, auth
│   │   └── router.ex
│   └── emakola_web.ex
├── priv/
│   ├── repo/
│   │   ├── migrations/          # Database migrations
│   │   └── seeds.exs            # Seed data
│   ├── static/                  # Static assets
│   └── gettext/                 # Translations
├── test/
│   ├── emakola/                 # Domain tests
│   ├── emakola_web/             # Web tests
│   ├── support/                 # Factories, helpers, mocks
│   └── test_helper.exs
└── docs/
    ├── SETUP.md                 # This file
    ├── ARCHITECTURE.md          # Architecture decisions
    └── API.md                   # API documentation
```

---

## Troubleshooting

### PostgreSQL Connection Issues
```bash
# Check if PostgreSQL is running
pg_isready

# Check connection with psql
psql -U postgres -h localhost -c "SELECT 1"

# If using Docker, check container
docker ps | grep emakola-postgres
```

### Dependency Issues
```bash
# Clean and reinstall deps
mix deps.clean --all
mix deps.get

# If Hex is outdated
mix local.hex --force
mix local.rebar --force
```

### Asset Build Issues
```bash
# Reinstall asset tools
mix assets.setup

# Manual Tailwind install
mix tailwind.install
```

### Dialyzer PLT Issues
```bash
# Rebuild PLT from scratch (takes 5-10 minutes)
mix dialyzer --plt
```

### Port Already in Use
```bash
# Find and kill process on port 4000
lsof -i :4000 | awk 'NR>1 {print $2}' | xargs kill -9
```
