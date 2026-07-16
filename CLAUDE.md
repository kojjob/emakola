# CLAUDE.md - Emakola Project Instructions

## Project Overview

**Emakola** is a multi-tenant ecommerce platform for West Africa, launching in Ghana first, then expanding to Nigeria. Think Shopify localized for West African merchants: mobile money payments (MTN MoMo, Telecel Cash, AirtelTigo), local payment gateways (Paystack, Hubtel), WhatsApp/SMS order notifications, and storefronts optimized for low-bandwidth mobile devices.

### Stack
- **Language**: Elixir 1.18+ / Erlang OTP 27+
- **Web Framework**: Phoenix 1.8+ with LiveView
- **Domain Framework**: Ash 3.x (resources, domains, authentication, multitenancy)
- **Database**: PostgreSQL 15+ with uuid-ossp
- **Background Jobs**: Oban
- **Styling**: TailwindCSS
- **File Storage**: S3-compatible (AWS S3 or DigitalOcean Spaces)
- **Payments**: Paystack, Hubtel (via Gateway behaviour)
- **Notifications**: WhatsApp Business API, SMS gateway

### Multi-Tenancy
- Ash attribute-based multitenancy using `store_id` on all tenant-scoped resources
- Every tenant-scoped query MUST include tenant context
- Store isolation is critical — never leak data across stores

---

## Development Workflow

### TDD — No Exceptions
1. **Red**: Write a failing test that defines the expected behavior
2. **Green**: Write the minimum code to make the test pass
3. **Refactor**: Clean up while keeping tests green

Every feature, bug fix, and refactor starts with a test.

### Git Flow
```bash
# Feature branch for every task
git checkout -b feature/{description}

# Work in TDD cycles, then:
mix test                    # All tests must pass
mix format                  # Format all code
mix credo --strict          # Static analysis clean

# Commit with conventional commits
git commit -m "feat(catalog): add product variant support"

# Push and create PR
git push origin HEAD
# Create PR targeting develop branch
```

### Branch Naming
- Features: `feature/{description}`
- Bug fixes: `fix/{description}`
- Hotfixes: `hotfix/{description}`
- Never commit directly to `main` or `develop`

### Commit Standards
- Conventional commits: `<type>(<scope>): <summary>`
- Types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `perf`
- Scopes: `catalog`, `orders`, `payments`, `stores`, `auth`, `web`, `jobs`
- Atomic commits — one logical change per commit
- Run `mix test` before every commit — no broken commits

### Pre-Commit Checklist
- [ ] All tests pass (`mix test`)
- [ ] Code formatted (`mix format --check-formatted`)
- [ ] Credo clean (`mix credo --strict`)
- [ ] No debug statements (IO.inspect, dbg) left behind
- [ ] No secrets in code — use environment variables
- [ ] New code has corresponding tests

---

## Code Conventions

### Ash Resources
- Define resources within domain modules:
  - `Emakola.Catalog` — Products, Variants, Categories, Collections
  - `Emakola.Orders` — Orders, LineItems, Fulfillments
  - `Emakola.Payments` — Payments, Refunds, Transactions
  - `Emakola.Stores` — Stores, StoreSettings, Domains
  - `Emakola.Accounts` — Users (merchants), authentication
  - `Emakola.Customers` — Customer accounts per store
  - `Emakola.Inventory` — Stock levels, locations
  - `Emakola.Shipping` — Shipping zones, rates, methods
  - `Emakola.Notifications` — Templates, delivery logs

### Ash DSL Gotchas
- `Ash.Query.filter` is a macro — it does NOT work inside anonymous functions in Ash DSL `actions do...end` blocks
- Fix: Extract to a separate module implementing `Ash.Resource.Actions.Implementation` with `require Ash.Query` at module level
- Always add `require Ash.Query` in any module that uses `Ash.Query.filter`

### Money Handling
- **All monetary amounts stored as integers in minor units** (pesewas for GHS, kobo for NGN)
- 1 GHS = 100 pesewas, 1 NGN = 100 kobo
- Never use floats for money — ever
- Display formatting happens only in the presentation layer
- Use a Money value object or helper module for arithmetic and formatting
- Store currency code alongside amount (e.g., `amount_pesewas: 50000, currency: "GHS"`)

### LiveView Components
- Use function components with `attr` and `slot` declarations
- Use `Phoenix.LiveView.JS` for client-side interactions — avoid raw JavaScript where possible
- Keep LiveView modules focused — extract components into `_components` modules
- Use `assign_async` and `start_async` for expensive operations

### Web Layer
- TailwindCSS for all styling — no custom CSS unless absolutely necessary
- Mobile-first responsive design (most West African users are on mobile)
- Optimize for low bandwidth: lazy load images, minimal JS, compressed assets
- Support for RTL is not needed (English, Akan, Hausa, Yoruba are all LTR)

### Service Modules
- Complex business logic spanning multiple resources goes in service modules
- Example: `Emakola.Orders.CheckoutService`, `Emakola.Payments.ProcessingService`
- Services return `{:ok, result}` or `{:error, reason}` tuples
- Services are the coordination layer — domain logic stays in resources

### Background Jobs (Oban)
- SMS/WhatsApp notifications: `Emakola.Workers.NotificationWorker`
- Payment webhook processing: `Emakola.Workers.WebhookWorker`
- Image processing/upload: `Emakola.Workers.ImageWorker`
- Order status updates: `Emakola.Workers.OrderStatusWorker`
- All workers must be idempotent
- Use unique constraints to prevent duplicate job execution

### PubSub
- Use Phoenix.PubSub for real-time order updates in merchant dashboard
- Topic naming: `"store:{store_id}:orders"`, `"store:{store_id}:inventory"`
- Broadcast on order creation, status change, payment confirmation

---

## Testing

### Requirements
- Minimum 90% test coverage for all new code
- Write tests BEFORE implementation — TDD is mandatory
- Test file naming: `*_test.exs`
- Tests mirror the `lib/` directory structure

### Test Organization
```
test/
├── emakola/                  # Domain tests
│   ├── catalog/              # Catalog resource tests
│   ├── orders/               # Order resource tests
│   ├── payments/             # Payment resource tests
│   └── ...
├── emakola_web/              # Web layer tests
│   ├── live/                 # LiveView tests
│   ├── controllers/          # Controller tests
│   └── ...
├── support/                  # Test helpers, factories, mocks
│   ├── factory.ex            # ExMachina factories
│   ├── fixtures.ex           # Test fixtures
│   └── mocks.ex              # Mox mock definitions
└── test_helper.exs
```

### Mocking Strategy
- Use Mox for external service mocks (Paystack, Hubtel, SMS, WhatsApp)
- Define behaviours for all external integrations
- Never hit real APIs in tests — not even sandbox
- Payment gateways: `Emakola.Payments.Gateway` behaviour
- SMS: `Emakola.Notifications.SMSProvider` behaviour

### LiveView Testing
- Test all merchant admin pages with LiveView test helpers
- Test storefront pages for customer-facing flows
- Test form submissions, live navigation, and flash messages
- Remember: `assert_redirect/2` only accepts binary strings, not regex

### Integration Tests
- Tag with `@tag :integration`
- Test full checkout flows end-to-end
- Test payment callback/webhook processing
- Test multi-tenant data isolation

---

## Key Directories

```
lib/
├── emakola/                   # Core domain (Ash resources, services)
│   ├── accounts/              # User accounts, authentication
│   ├── catalog/               # Products, variants, categories
│   ├── customers/             # Store customer accounts
│   ├── inventory/             # Stock management
│   ├── notifications/         # SMS, WhatsApp, email
│   ├── orders/                # Orders, line items, fulfillment
│   ├── payments/              # Payment processing, gateways
│   ├── shipping/              # Shipping zones, rates
│   └── stores/                # Store config, domains, settings
├── emakola_web/               # Phoenix web layer
│   ├── components/            # Shared UI components
│   ├── live/                  # LiveView modules
│   │   ├── admin/             # Merchant admin dashboard
│   │   └── storefront/        # Customer-facing storefront
│   ├── controllers/           # Non-LiveView controllers (webhooks, API)
│   ├── plugs/                 # Custom plugs (tenant resolution, auth)
│   └── router.ex
test/                          # Tests mirror lib/ structure
priv/
├── repo/migrations/           # Ecto/Ash migrations
├── static/                    # Static assets
└── gettext/                   # Translations (en, ak, ha, yo)
```

---

## Important Patterns

### Payment Gateway Behaviour
```elixir
defmodule Emakola.Payments.Gateway do
  @callback initiate_payment(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_payment(String.t()) :: {:ok, map()} | {:error, term()}
  @callback process_refund(String.t(), integer()) :: {:ok, map()} | {:error, term()}
end
```
Implementations: `Emakola.Payments.Gateways.Paystack`, `Emakola.Payments.Gateways.Hubtel`

### Tenant Resolution
- Storefront: resolve store from subdomain or custom domain via Plug
- Admin: resolve store from authenticated user's store association
- API: resolve store from `X-Store-ID` header or auth token

### Platform Admin Auth
- Platform staff sign in only via `/platform/login` — password then mandatory TOTP (two-step)
- Registration is invite-only (team page sends invites; no public staff signup)
- Sessions are DB-backed (`Emakola.Accounts.UserSession`): 14-day absolute cookie expiry, 24-hour idle timeout
- Bootstrap the first owner: `mix emakola.bootstrap_platform_owner <email>`
- Reset a locked-out admin's TOTP: `mix emakola.reset_platform_totp <email>`
- Staff auth events are recorded in the platform audit log (`Emakola.Accounts.PlatformAudit`)

### Mobile API (Phase 0)
- Merchant bearer auth: `POST /api/v1/auth/sign_in` → 15-min access token + 30-day rotating single-use refresh token (`Emakola.Accounts.ApiTokens`); revocation via the shared tokens table
- Tenant: every JSON:API request requires `X-Store-ID` (validated against StoreMembership); `GET /api/v1/stores` lists the merchant's stores
- Resources via ash_json_api (`EmakolaWeb.ApiRouter`, forwarded at `/api/v1`): orders list/detail/transitions, device_tokens; contract at `/api/v1/open_api` or `mix openapi.spec.json --spec EmakolaWeb.ApiRouter`
- Push: `Emakola.Notifications.PushProvider` behaviour (FcmPush prod / LogPush dev / Mox test, selected via `:push_provider` config); `PushNotificationWorker` fires on order_placed; FCM env vars optional (push disabled without them)
- Full endpoint contract: docs/API.md "Mobile API v1"

### Currency Support
- GHS (Ghana Cedi) — default for Ghana stores
- NGN (Nigerian Naira) — for Nigeria expansion
- USD — for international payments (future)

---

## Environment Variables

Required environment variables (see `.env.example` for full list):

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret key (min 64 bytes) |
| `PHX_HOST` | Production hostname |
| `PHX_PORT` | HTTP port (default 4000) |
| `PAYSTACK_SECRET_KEY` | Paystack API secret key |
| `PAYSTACK_PUBLIC_KEY` | Paystack publishable key |
| `HUBTEL_CLIENT_ID` | Hubtel API client ID |
| `HUBTEL_CLIENT_SECRET` | Hubtel API client secret |
| `AWS_ACCESS_KEY_ID` | S3 access key for file uploads |
| `AWS_SECRET_ACCESS_KEY` | S3 secret key |
| `AWS_S3_BUCKET` | S3 bucket name |
| `AWS_S3_REGION` | S3 region (e.g., eu-west-1) |
| `WHATSAPP_API_TOKEN` | WhatsApp Business API token |
| `WHATSAPP_PHONE_NUMBER_ID` | WhatsApp sender phone number ID |
| `SMS_API_KEY` | SMS gateway API key |
| `SMS_SENDER_ID` | SMS sender ID (e.g., "Emakola") |
| `OBAN_QUEUE_DEFAULT` | Oban default queue concurrency |
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase service account JSON (enables FCM push; omit to use LogPush) |
| `FCM_PROJECT_ID` | Firebase project ID (required when FCM_SERVICE_ACCOUNT_JSON is set) |

---

## Quick Reference

```bash
# Development
mix phx.server                  # Start dev server
iex -S mix                      # Interactive console
mix ash.codegen                 # Generate Ash code
mix ash.gen.resource            # Generate Ash resource
mix ash.gen.domain              # Generate Ash domain

# Database
mix ecto.create                 # Create database
mix ecto.migrate                # Run migrations
mix ecto.rollback               # Rollback last migration
mix ecto.reset                  # Drop, create, migrate, seed

# Testing
mix test                        # Run all tests
mix test --cover                # With coverage report
mix test --tag integration      # Integration tests only
mix test --failed               # Re-run failed tests

# Quality
mix format                      # Format code
mix format --check-formatted    # Check formatting (CI)
mix credo --strict              # Static analysis
mix dialyzer --plt              # Generate/update PLT (slow, run once after deps change)
mix dialyzer                    # Run static analysis
mix sobelow                     # Security scanning
```

### Static analysis (Dialyzer)

The PLT (Persistent Lookup Table) is cached at `priv/plts/dialyzer.plt` and is gitignored — every developer regenerates it locally with `mix dialyzer --plt` after pulling new deps. The first run takes 2–10 minutes; subsequent runs are incremental and fast.

`mix dialyzer` performs success-typing static analysis on the project. False positives are common with Ash macros and Phoenix LiveView generated code. Findings should be triaged on the merits — fix the underlying type issue when possible, and only register a filter in `.dialyzer_ignore.exs` after confirming the warning is a genuine false positive. Every entry in that file is technical debt; keep it short.

---

## Workflow Lessons

### Long-running branches: rebase early, rebase often
A branch that lives more than ~5 days or accumulates more than ~10 commits will hit painful merge conflicts when it finally lands. The longer a branch diverges from `main`, the harder the rejoin gets — especially when both sides touch the same render functions or context modules.

**Rule:** Rebase your feature branch on `main` daily (`git pull --rebase origin main`). If you're working on a long task, land it in stacked sub-PRs every 2-3 days.

### `mix phx.server` + concurrent code edits = race conditions
Running `mix phx.server` in one terminal while editing files in another causes:
- Server holds the `_build` directory lock while compiling
- Hot-reload fires while you're mid-edit, sometimes auto-formatting your changes
- Tests can fail intermittently because the server process is recompiling

**Rule:** When doing focused code work (refactors, large edits), stop `phx.server`. Restart it only when you need to look at the UI.

### Stacked PRs: always merge bottom-up
For a stack like A → B → C → D where each branch's base is the previous one:

- **Right way:** merge A → main first, then B (auto-rebases), then C, then D.
- **Wrong way:** merge C into B first → GitHub auto-cascades all stacked PRs to "MERGED" without anything reaching `main`. You'll need an extra fast-forward PR to land the work.

**Rule:** When merging a stacked PR series, always start with the PR whose base is `main`.

### Browser cache vs Phoenix hot-reload
Phoenix's `live_reload` pushes asset updates, but Chrome aggressively caches CSS/JS on `localhost`. Symptom: "I changed the CSS, why doesn't it apply?"

**Rule:** Open DevTools (Cmd+Option+I) → Network tab → ☑️ **Disable cache** → keep DevTools open while developing.

### CSS-only state toggles don't compose with LiveView
Patterns like `<input type="checkbox"> + <label> + .x:checked ~ .y { ... }` break under LiveView's DOM diffing — the `:checked` state lives in browser memory, not in the rendered HTML, so LV diffs lose it.

**Rule:** For client-side UI state in LiveView, use `Phoenix.LiveView.JS` commands (`JS.toggle_class`, `JS.add_class`, `JS.show`, etc.) instead of CSS-checkbox toggles.

### Custom CSS rules in app.css must live inside `@layer components`
Tailwind v4 uses `@layer theme, base, components, utilities;` for cascade order. Rules outside any `@layer` (i.e. unlayered) **outrank ALL layered rules including utilities**. So `class="sidebar-link p-4"` would have `.sidebar-link` win over Tailwind's `.p-4` if `.sidebar-link` is unlayered.

**Rule:** Wrap custom component-style CSS in `@layer components { ... }`. Then Tailwind utilities reliably override your defaults.

### Atom conversion from user input
`String.to_atom/1` (atom-table DoS) and `String.to_existing_atom/1` (raises on unknown input → 500 error DoS) are both unsafe with user-controlled input.

**Rule:** Use `Emakola.SafeAtom.to_atom_in/3` with an explicit allowlist for form fields, sort keys, and other user-facing inputs. Use `Emakola.SafeAtom.to_atom/2` with a default for cases where the set of valid atoms is too large to enumerate.

