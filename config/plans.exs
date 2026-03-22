import Config

config :emakola, :plans, [
  %{
    name: "Free",
    slug: "free",
    stripe_product_id: "prod_free",
    stripe_price_id: "price_free",
    price_cents: 0,
    interval: :monthly,
    features: ["1 workspace", "3 AI agents", "1,000 API calls/month"],
    max_seats: 1,
    max_agents: 3,
    max_api_calls_per_month: 1000,
    sort_order: 0
  },
  %{
    name: "Starter",
    slug: "starter",
    stripe_product_id: "prod_starter",
    stripe_price_id: "price_starter_monthly",
    price_cents: 2900,
    interval: :monthly,
    features: ["5 workspaces", "10 AI agents", "10,000 API calls/month", "Priority support"],
    max_seats: 5,
    max_agents: 10,
    max_api_calls_per_month: 10_000,
    sort_order: 1
  },
  %{
    name: "Pro",
    slug: "pro",
    stripe_product_id: "prod_pro",
    stripe_price_id: "price_pro_monthly",
    price_cents: 7900,
    interval: :monthly,
    features: [
      "Unlimited workspaces",
      "50 AI agents",
      "100,000 API calls/month",
      "Priority support",
      "Custom branding"
    ],
    max_seats: 20,
    max_agents: 50,
    max_api_calls_per_month: 100_000,
    sort_order: 2
  },
  %{
    name: "Enterprise",
    slug: "enterprise",
    stripe_product_id: "prod_enterprise",
    stripe_price_id: "price_enterprise_monthly",
    price_cents: 19900,
    interval: :monthly,
    features: ["Unlimited everything", "Dedicated support", "SLA", "Custom integrations", "SSO"],
    max_seats: 100,
    max_agents: 500,
    max_api_calls_per_month: 1_000_000,
    sort_order: 3
  }
]
