# External service setup

This file previously duplicated provider instructions and had drifted away from
the executable production configuration. Use the maintained guides instead:

1. [Deployment](DEPLOYMENT.md) — infrastructure, required production variables,
   database TLS, releases, migrations, health checks, and rollback.
2. [Provider setup](PROVIDER_SETUP.md) — Paystack, Hubtel, Resend, SMS,
   WhatsApp, storage, OAuth, push notifications, search, and domain cutover.
3. [Environment reference](../.env.example) — every environment variable read
   by the current application, including conditional requirements.
4. [Monitoring](MONITORING.md) — private Prometheus endpoint, dashboards, and
   alerting.

At production boot, the current release requires PostgreSQL, Resend, both
Paystack keys, SMS credentials, WhatsApp credentials, Phoenix/auth secrets, and
the canonical host. S3-compatible storage is degradable at boot but uploads will
fail until it is configured. Hubtel, OAuth, FCM, Search Console, Sentry, and
Anthropic integrations ship dark until their credentials are present.

Do not follow copied credentials, prices, API versions, or provider screenshots
from old tickets. Provider consoles and commercial terms change; verify them in
the provider's current official documentation before spending money or enabling
production traffic.
