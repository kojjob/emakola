import Config

# Database
config :emakola, Emakola.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "emakola_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # Generous queue/ownership windows: dashboard + checkout tests fan many
  # Task-based queries onto one shared sandbox connection; DBConnection's
  # default ~100ms queue window drops waiters under parallel suite load.
  queue_target: 5_000,
  queue_interval: 5_000,
  ownership_timeout: 120_000,
  timeout: 60_000

# Oban: manual mode for assert_enqueued/refute_enqueued in tests
config :emakola, Oban, testing: :manual

# AshAuthentication token signing secret — test-only value
config :emakola,
  token_signing_secret: "dev-only-not-for-production-at-least-32-bytes!!"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :emakola, EmakolaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/SfRLXTZcRbLKBro322kKvAkTKdW9hYWqe0hC3q4S0fj7P+6ziaajSPq5dq1I/hu",
  server: false

# In test we don't send emails
config :emakola, Emakola.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Suppress Ash missed notification warnings in test (expected inside Repo.transaction)
config :ash, :missed_notifications, :ignore

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# HTTP client: use mock in tests
config :emakola, :http_client, Emakola.HTTPClientMock

# AI content generator: mock in tests — never call the real Claude API.
config :emakola, :content_generator, Emakola.Content.GeneratorMock

# AI provider: mock the whole LLM provider in tests (Emakola.AI.generate/3).
# Provider wire-format tests call Emakola.AI.Providers.Anthropic directly.
config :emakola, :ai_provider, Emakola.AI.ProviderMock

# Hubtel test credentials
config :emakola, :hubtel_client_id, "test_client_id"
config :emakola, :hubtel_client_secret, "test_client_secret"
config :emakola, :hubtel_base_url, "https://api.hubtel.com"

# Paystack test credentials
config :emakola, :paystack_secret_key, "sk_test_default_secret"
config :emakola, :paystack_public_key, "pk_test_default_public"

# Payment gateway: use mock in tests (always returns success)
config :emakola, :payment_gateway, Emakola.Payments.Gateways.Mock

# Paystack client: use Mox mock in tests
config :emakola, :paystack_client, Emakola.Payments.PaystackClientMock

# Hubtel client: use Mox mock in tests
config :emakola, :hubtel_client, Emakola.Payments.HubtelClientMock

# PaystackClient module config (used by the real client, overridden by mock)
config :emakola, Emakola.Payments.PaystackClient,
  secret_key: "sk_test_default_secret",
  base_url: "https://api.paystack.co"

# Notification providers: use Mox mocks in tests
config :emakola, :sms_provider, Emakola.SMSProviderMock
config :emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock
config :emakola, :push_provider, Emakola.PushProviderMock

# Phone (WhatsApp/SMS) OTP auth enabled in tests.
config :emakola, :phone_auth_enabled, true

# Storage adapter: route through Mox so individual tests can expect/stub
# the specific calls they care about. Tests that don't set expectations
# get a failure from verify_on_exit! — which is what we want.
config :emakola, :storage, Emakola.StorageMock

# Disable rate limiting globally in tests to avoid flaky 429s in auth/page
# tests. Tests that specifically exercise the rate limiter (see
# rate_limiter_test.exs, security_test.exs) re-enable it per-test via
# Application.put_env/3 in their setup block.
config :emakola, :disable_rate_limit, true
config :emakola, disable_rate_limiter: true

# Hubtel webhook allowlist: disabled by default in tests so existing webhook
# integration tests continue to work without knowing about IP enforcement.
# Tests that specifically exercise the plug override this per-test.
config :emakola, :hubtel_webhook_allowlist, []
config :emakola, :hubtel_webhook_allowlist_disabled, true

# ChromicPDF spawns a headless Chrome session pool at application boot unless
# told to work on demand. `config/runtime.exs` sets `on_demand: true`, but only
# inside its `config_env() == :prod` block — so in test `application.ex` started
# ChromicPDF with `[]`, eagerly launching Chrome workers that then timed out and
# retried for the life of the run. That flooded output with
# "Timeout in Channel.run_protocol/3" and turned a ~2 minute suite into ~40
# minutes, which was enough resource starvation to make unrelated LiveView tests
# flake.
#
# Safe to defer: `test_helper.exs` excludes the :pdf tag, so no ordinary test
# renders a PDF. CI opts into that tag and supplies its Playwright-managed
# Chromium path explicitly.
if chrome_executable = System.get_env("CHROME_EXECUTABLE") do
  config :emakola, ChromicPDF,
    on_demand: true,
    chrome_executable: chrome_executable,
    no_sandbox: System.get_env("CHROME_NO_SANDBOX") == "true",
    session_pool: [checkout_timeout: 30_000]
else
  config :emakola, ChromicPDF,
    on_demand: true,
    session_pool: [checkout_timeout: 30_000]
end
