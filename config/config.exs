# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :emakola,
  env: config_env(),
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :emakola, EmakolaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EmakolaWeb.ErrorHTML, json: EmakolaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Emakola.PubSub,
  live_view: [signing_salt: "MnhgwL4O"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :emakola, Emakola.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  emakola: [
    args:
      ~w(js/app.js js/theme-init.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  emakola: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash Framework
config :emakola,
  ash_domains: [
    Emakola.Accounts,
    Emakola.Billing,
    Emakola.Notifications,
    Emakola.Audit,
    Emakola.FeatureFlags,
    Emakola.Webhooks,
    Emakola.Analytics,
    Emakola.Catalog,
    Emakola.Orders,
    Emakola.Customers,
    Emakola.Payments,
    Emakola.Shipping,
    Emakola.Content,
    Emakola.Pages
  ]

# Token signing secret — loaded from env var; fallback only for dev/test
config :emakola,
  token_signing_secret:
    System.get_env("TOKEN_SIGNING_SECRET", "dev-only-not-for-production-at-least-32-bytes!!")

# Database
config :emakola, Emakola.Repo, migration_primary_key: [name: :id, type: :binary_id]

config :emakola,
  ecto_repos: [Emakola.Repo]

# Oban
config :emakola, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    default: 10,
    mailers: 20,
    billing: 5,
    notifications: 5,
    webhooks: 5,
    images: 3,
    orders: 5
  ],
  repo: Emakola.Repo,
  crontab: [
    {"0 8 * * *", Emakola.Inventory.Workers.LowStockAlertWorker},
    {"0 */6 * * *", Emakola.Cart.CartCleanupWorker}
  ]

# Demo mode
config :emakola, :demo_mode, System.get_env("DEMO_MODE") == "true"

# Hammer rate limiting (ETS backend)
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Paystack client defaults (overridden in runtime.exs for prod)
config :emakola, Emakola.Payments.PaystackClient,
  secret_key: System.get_env("PAYSTACK_SECRET_KEY", "sk_test_placeholder"),
  public_key: System.get_env("PAYSTACK_PUBLIC_KEY", "pk_test_placeholder"),
  base_url: "https://api.paystack.co"

# WhatsApp Business API (Cloud API)
# api_version is overridable via WHATSAPP_API_VERSION env var so we
# can roll forward when Meta deprecates a Graph API version without
# a redeploy. See https://developers.facebook.com/docs/graph-api/changelog
config :emakola, Emakola.Notifications.Channels.WhatsApp,
  api_token: System.get_env("WHATSAPP_API_TOKEN"),
  phone_number_id: System.get_env("WHATSAPP_PHONE_NUMBER_ID"),
  api_version: System.get_env("WHATSAPP_API_VERSION") || "v21.0"

# SMS Gateway
config :emakola, Emakola.Notifications.Channels.SMS,
  api_key: System.get_env("SMS_API_KEY"),
  sender_id: System.get_env("SMS_SENDER_ID") || "Emakola"

# Hubtel client defaults (overridden in runtime.exs for prod)
config :emakola, Emakola.Payments.HubtelClient,
  client_id: System.get_env("HUBTEL_CLIENT_ID"),
  client_secret: System.get_env("HUBTEL_CLIENT_SECRET"),
  base_url: "https://api.hubtel.com"

# Import branding and plans config
import_config "branding.exs"
import_config "plans.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
