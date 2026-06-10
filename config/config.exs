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
    Emakola.Marketing,
    Emakola.Customers,
    Emakola.Payments,
    Emakola.Shipping,
    Emakola.Suppliers,
    Emakola.Stores,
    Emakola.Content,
    Emakola.Pages,
    Emakola.Fulfillment
  ]

# Token signing secret is set per environment: dev.exs/test.exs use a
# fixed dev-only value; prod requires TOKEN_SIGNING_SECRET (runtime.exs).

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
    orders: 5,
    whatsapp_catalog: 3
  ],
  repo: Emakola.Repo,
  plugins: [
    # Prune completed/cancelled/discarded jobs after 7 days — without this
    # the oban_jobs table grows forever.
    {Oban.Plugins.Pruner, max_age: 604_800},
    # Rescue jobs orphaned by node crashes/deploys back to available.
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 8 * * *", Emakola.Inventory.Workers.LowStockAlertWorker},
       {"0 */6 * * *", Emakola.Cart.CartCleanupWorker}
     ]}
  ]

# Demo mode
config :emakola, :demo_mode, System.get_env("DEMO_MODE") == "true"

# Paystack client — non-secret structure only. Credentials are set per
# environment: dev.exs (placeholders), test.exs, runtime.exs (prod).
config :emakola, Emakola.Payments.PaystackClient, base_url: "https://api.paystack.co"

# SMS/WhatsApp channel credentials are runtime concerns — configured in
# runtime.exs for prod. Dev/test default to Log providers / Mox mocks.

# Hubtel client — non-secret structure only. Credentials are set per
# environment: dev.exs (env passthrough), test.exs (flat keys), runtime.exs (prod).
config :emakola, Emakola.Payments.HubtelClient, base_url: "https://api.hubtel.com"

# Import branding and plans config
import_config "branding.exs"
import_config "plans.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
