import Config

# Database
config :emakola, Emakola.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "emakola_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Oban: manual mode for assert_enqueued/refute_enqueued in tests
config :emakola, Oban, testing: :manual

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

# Hubtel test credentials
config :emakola, :hubtel_client_id, "test_client_id"
config :emakola, :hubtel_client_secret, "test_client_secret"
config :emakola, :hubtel_base_url, "https://api.hubtel.com"

# Paystack test credentials
config :emakola, :paystack_secret_key, "sk_test_default_secret"
config :emakola, :paystack_public_key, "pk_test_default_public"
