import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/emakola start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :emakola, EmakolaWeb.Endpoint, server: true
end

# AI content generation (SEO Phase 3). All environments: nil = ships dark, so the
# Claude generator returns {:error, :not_configured} and nothing is spent.
config :emakola, :anthropic_api_key, System.get_env("ANTHROPIC_API_KEY")

# Sentry DSN is read at runtime so the same release works with or without it.
# Without SENTRY_DSN set, Sentry stays inert (no events sent).
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  release: System.get_env("SENTRY_RELEASE")

config :emakola, EmakolaWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Runtime knob (all envs) — compile-time evaluation would bake the
# builder's (unset) value into release builds permanently.
config :emakola, :demo_mode, System.get_env("DEMO_MODE") == "true"

# SplitPay tenant client (any env) — ships dark until both are set.
# Fly certificate provisioning for merchant custom domains. Ships dark: without
# FLY_API_TOKEN the client makes no network call and no certificate is ever
# requested, so the whole custom-domain flow stalls harmlessly at :verifying.
config :emakola, Emakola.Infra.FlyCerts,
  api_token: System.get_env("FLY_API_TOKEN"),
  app_name: System.get_env("FLY_APP_NAME") || "emakola"

if splitpay_url = System.get_env("SPLITPAY_API_URL") do
  config :emakola, Emakola.SplitPay.Client,
    base_url: splitpay_url,
    api_key: System.get_env("SPLITPAY_API_KEY"),
    webhook_secret: System.get_env("SPLITPAY_WEBHOOK_SECRET")
end

if config_env() == :prod do
  config :emakola,
         :metrics_port,
         String.to_integer(System.get_env("METRICS_PORT", "9091"))

  # Application-level encryption keyrings. Values are JSON objects mapping a
  # stable key id to a base64-encoded, 32-byte random key. Ciphertext envelopes
  # carry the encryption key id so old keys can remain readable during
  # rotation. Blind-index keys are deliberately separate key material.
  decode_keyring! = fn env_name ->
    encoded =
      System.get_env(env_name) ||
        raise("environment variable #{env_name} is missing.")

    case Jason.decode(encoded) do
      {:ok, keyring} when is_map(keyring) and map_size(keyring) > 0 ->
        Map.new(keyring, fn {key_id, encoded_key} ->
          key =
            case is_binary(encoded_key) && Base.decode64(encoded_key) do
              {:ok, key} when byte_size(key) == 32 -> key
              _ -> raise("#{env_name} contains a key that is not valid base64 for 32 bytes.")
            end

          unless Regex.match?(~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,63}\z/, key_id) do
            raise("#{env_name} contains an invalid key id.")
          end

          {key_id, key}
        end)

      _ ->
        raise("environment variable #{env_name} must be a non-empty JSON object.")
    end
  end

  encryption_keys = decode_keyring!.("FIELD_ENCRYPTION_KEYS")
  encryption_active_key_id = System.fetch_env!("FIELD_ENCRYPTION_ACTIVE_KEY_ID")
  blind_index_keys = decode_keyring!.("FIELD_BLIND_INDEX_KEYS")
  blind_index_active_key_id = System.fetch_env!("FIELD_BLIND_INDEX_ACTIVE_KEY_ID")

  unless Map.has_key?(encryption_keys, encryption_active_key_id) do
    raise("FIELD_ENCRYPTION_ACTIVE_KEY_ID is not present in FIELD_ENCRYPTION_KEYS.")
  end

  unless Map.has_key?(blind_index_keys, blind_index_active_key_id) do
    raise("FIELD_BLIND_INDEX_ACTIVE_KEY_ID is not present in FIELD_BLIND_INDEX_KEYS.")
  end

  unless MapSet.disjoint?(
           MapSet.new(Map.values(encryption_keys)),
           MapSet.new(Map.values(blind_index_keys))
         ) do
    raise("field-encryption and blind-index keyrings must use separate key material.")
  end

  config :emakola, Emakola.Security.FieldEncryption,
    active_key_id: encryption_active_key_id,
    keys: encryption_keys,
    blind_index_active_key_id: blind_index_active_key_id,
    blind_index_keys: blind_index_keys

  # Database
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing."

  # Database TLS. Defaults to full peer verification against the OS trust
  # store. Set DATABASE_SSL=false only when the connection is already
  # private and encrypted at a lower layer — e.g. Fly.io 6PN private
  # networking to a `.internal` Postgres. For any external/public database
  # keep the default. See docs/DEPLOYMENT.md "Database TLS".
  database_ssl =
    case System.get_env("DATABASE_SSL", "true") do
      "false" ->
        false

      _ ->
        [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          server_name_indication:
            case URI.parse(database_url).host do
              nil -> :disable
              host -> to_charlist(host)
            end,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]
    end

  config :emakola, Emakola.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: database_ssl,
    socket_options: if(System.get_env("ECTO_IPV6") == "true", do: [:inet6], else: [])

  # Swoosh / Resend
  resend_api_key =
    System.get_env("RESEND_API_KEY") ||
      raise "environment variable RESEND_API_KEY is missing."

  config :emakola, Emakola.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: resend_api_key

  config :emakola,
    contact_email: System.get_env("CONTACT_EMAIL", "support@makola.io"),
    careers_email: System.get_env("CAREERS_EMAIL", "careers@makola.io"),
    press_email: System.get_env("PRESS_EMAIL", "press@makola.io"),
    support_whatsapp: System.get_env("SUPPORT_WHATSAPP", "233200000000"),
    support_phone: System.get_env("SUPPORT_PHONE", "+233 20 000 0000")

  # Outbound mail "from" domain (noreply@/billing@). Flip the whole sending
  # domain by setting MAIL_FROM_DOMAIN — no code change needed.
  config :emakola, :mail_from_domain, System.get_env("MAIL_FROM_DOMAIN", "makola.io")

  # ChromicPDF (analytics PDF export) — the Docker runner installs Debian's
  # chromium package and runs as a non-root user. Chrome's sandbox needs
  # privileges unavailable in the container, so we follow ChromicPDF's
  # documented Docker pattern: explicit binary + no_sandbox. on_demand
  # spawns Chrome lazily per PDF request, so a broken Chrome install breaks
  # PDF export instead of crashing the app at boot.
  config :emakola, ChromicPDF,
    chrome_executable: System.get_env("CHROME_EXECUTABLE", "/usr/bin/chromium"),
    no_sandbox: System.get_env("CHROME_NO_SANDBOX", "true") == "true",
    discard_stderr: true,
    on_demand: true,
    session_pool: [checkout_timeout: 30_000]

  # S3-compatible storage for product images, media uploads
  config :emakola, :storage, Emakola.Storage.S3

  # Bucket/region: AWS_S3_* take precedence; BUCKET_NAME / AWS_REGION are
  # what `fly storage create` (Tigris) sets automatically.
  config :emakola,
         :s3_bucket,
         System.get_env("AWS_S3_BUCKET") || System.get_env("BUCKET_NAME") ||
           "emakola-uploads"

  s3_region =
    System.get_env("AWS_S3_REGION") || System.get_env("AWS_REGION") || "auto"

  config :emakola, :s3_region, s3_region

  # ExAws credentials. Warn loudly but don't raise — image upload is a
  # degradable feature and must not block boot.
  s3_access_key_id = System.get_env("AWS_ACCESS_KEY_ID")
  s3_secret_access_key = System.get_env("AWS_SECRET_ACCESS_KEY")

  if is_nil(s3_access_key_id) or is_nil(s3_secret_access_key) do
    IO.puts(
      :stderr,
      "WARNING: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY not set — " <>
        "S3 uploads (product images, media) WILL FAIL until configured."
    )
  end

  config :ex_aws,
    access_key_id: s3_access_key_id,
    secret_access_key: s3_secret_access_key,
    region: s3_region

  # Tigris / non-AWS S3 endpoint. ExAws does not read AWS_ENDPOINT_URL_S3
  # (the var `fly storage create` sets) — parse it into the scheme/host/port
  # keys ExAws actually uses.
  if endpoint_url = System.get_env("AWS_ENDPOINT_URL_S3") do
    endpoint = URI.parse(endpoint_url)

    config :ex_aws, :s3,
      scheme: "#{endpoint.scheme}://",
      host: endpoint.host,
      port: endpoint.port
  end

  # Payment gateways (required in prod)
  paystack_secret_key =
    System.get_env("PAYSTACK_SECRET_KEY") ||
      raise "environment variable PAYSTACK_SECRET_KEY is missing."

  # Flat key — read by Emakola.Payments.Gateways.Paystack (webhook HMAC).
  config :emakola, :paystack_secret_key, paystack_secret_key

  # Nested keyword config — read by Emakola.Payments.PaystackClient.
  # The public key drives client-side Paystack.js checkout; an empty default
  # would silently break the checkout page with no boot error, so fail fast.
  config :emakola, Emakola.Payments.PaystackClient,
    secret_key: paystack_secret_key,
    public_key:
      System.get_env("PAYSTACK_PUBLIC_KEY") ||
        raise("environment variable PAYSTACK_PUBLIC_KEY is missing.")

  # Hubtel (optional at launch) — read by Emakola.Payments.HubtelClient. If the
  # client id is set, the secret is required too — a half-configured gateway
  # would fail opaquely at the first call.
  if hubtel_id = System.get_env("HUBTEL_CLIENT_ID") do
    config :emakola, Emakola.Payments.HubtelClient,
      client_id: hubtel_id,
      client_secret:
        System.get_env("HUBTEL_CLIENT_SECRET") ||
          raise(
            "environment variable HUBTEL_CLIENT_SECRET is missing (required with HUBTEL_CLIENT_ID)."
          )
  end

  # Hubtel webhook source-IP allowlist. Hubtel does not sign webhooks, so
  # conn.remote_ip is the only trust boundary. Populate from the comma-
  # separated HUBTEL_WEBHOOK_ALLOWLIST env var with IPv4 addresses or CIDR
  # ranges (e.g. "203.0.113.5,10.0.0.0/24"). If unset or empty, the
  # HubtelAllowlist plug fails closed and rejects every /webhooks/hubtel
  # request with 403 — see Emakola.Web.Plugs.HubtelAllowlist.
  config :emakola,
         :hubtel_webhook_allowlist,
         (System.get_env("HUBTEL_WEBHOOK_ALLOWLIST") || "")
         |> String.split(",", trim: true)
         |> Enum.map(&String.trim/1)

  # Bypass flag is never set in prod — keeping fail-closed semantics.
  config :emakola, :hubtel_webhook_allowlist_disabled, false

  # SMS notifications — required in prod (order/stock notifications are
  # business-critical, so missing credentials fail the boot, not silently
  # no-op). Workers resolve :sms_provider; the channel reads its own
  # keyword config. SMS_PROVIDER=arkesel switches the channel to Arkesel's
  # v2 contract (api-key header + sender/message/recipients payload) and
  # makes SMS_API_URL optional (defaults to the Arkesel endpoint).
  config :emakola, :sms_provider, Emakola.Notifications.Channels.SMS

  sms_provider_mode =
    case System.get_env("SMS_PROVIDER", "generic") do
      "arkesel" -> :arkesel
      _generic -> :generic
    end

  sms_api_url =
    System.get_env("SMS_API_URL") ||
      if sms_provider_mode == :arkesel do
        # The channel's own Arkesel default; nil lets it apply.
        nil
      else
        raise("environment variable SMS_API_URL is missing (or set SMS_PROVIDER=arkesel).")
      end

  config :emakola, Emakola.Notifications.Channels.SMS,
    provider: sms_provider_mode,
    api_key:
      System.get_env("SMS_API_KEY") ||
        raise("environment variable SMS_API_KEY is missing."),
    sender_id: System.get_env("SMS_SENDER_ID") || "Makola",
    api_url: sms_api_url

  # WhatsApp Business Cloud API — credentials required in prod.
  # Workers resolve :whatsapp_provider and call send_message/4, which the
  # channel implements (map params -> positional template parameters).
  # api_version is overridable via WHATSAPP_API_VERSION env var so we
  # can roll forward when Meta deprecates a Graph API version without
  # a redeploy. See https://developers.facebook.com/docs/graph-api/changelog
  config :emakola, :whatsapp_provider, Emakola.Notifications.Channels.WhatsApp

  config :emakola, Emakola.Notifications.Channels.WhatsApp,
    api_token:
      System.get_env("WHATSAPP_API_TOKEN") ||
        raise("environment variable WHATSAPP_API_TOKEN is missing."),
    phone_number_id:
      System.get_env("WHATSAPP_PHONE_NUMBER_ID") ||
        raise("environment variable WHATSAPP_PHONE_NUMBER_ID is missing."),
    api_version: System.get_env("WHATSAPP_API_VERSION") || "v21.0"

  # Phone (WhatsApp/SMS) OTP auth — ship-dark. Reveal the WhatsApp sign-in
  # button only once SMS (now) or the approved WhatsApp auth_code template can
  # deliver codes: set PHONE_AUTH_ENABLED=true. See docs/PROVIDER_SETUP.md.
  config :emakola, :phone_auth_enabled, System.get_env("PHONE_AUTH_ENABLED") == "true"

  # Mobile push (FCM HTTP v1 via Req + Goth). Only active when a Firebase
  # service account is configured; otherwise the Log provider keeps the
  # pipeline observable without sending anything.
  if System.get_env("FCM_SERVICE_ACCOUNT_JSON") do
    config :emakola, :push_provider, Emakola.Notifications.Providers.FcmPush
    config :emakola, :fcm_project_id, System.fetch_env!("FCM_PROJECT_ID")
  else
    config :emakola, :push_provider, Emakola.Notifications.Providers.LogPush
  end

  # Google Search Console sync (SEO Phase 5). Ships dark: without a service
  # account the fetcher returns {:ok, []} and the daily cron is a no-op.
  #
  # GSC_SITE_URL must match the property KIND, not just the hostname. A Domain
  # property (DNS-verified, covers merchant subdomains — what
  # docs/SEO_PRODUCTION_SETUP_BEGINNERS_GUIDE.md §2.1 instructs) is addressed
  # as `sc-domain:makola.io`. Passing the URL-prefix form `https://makola.io`
  # against a Domain property returns 403 while the browser UI still shows the
  # site as verified, so we default to the sc-domain form.
  if System.get_env("GSC_SERVICE_ACCOUNT_JSON") do
    config :emakola, :gsc_credentials, {:goth, Emakola.GscGoth}

    config :emakola,
           :gsc_site_url,
           System.get_env("GSC_SITE_URL") || "sc-domain:#{System.fetch_env!("PHX_HOST")}"
  end

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # AshAuthentication token signing secret (User/Merchant/Customer tokens).
  # Resources read this at runtime via Application.fetch_env/2.
  config :emakola,
         :token_signing_secret,
         System.get_env("TOKEN_SIGNING_SECRET") ||
           raise("""
           environment variable TOKEN_SIGNING_SECRET is missing.
           You can generate one by calling: mix phx.gen.secret 64
           """)

  # Social login (OAuth) — ship-dark: each provider activates only when its
  # credentials are present (see EmakolaWeb.OAuth). Leaving the env vars unset
  # keeps that provider's button hidden and its routes inert, so this deploys
  # safely before any provider is set up. Apple uses a .p8 signing key, not a
  # client secret.
  config :emakola, :oauth,
    google: %{
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
    },
    facebook: %{
      client_id: System.get_env("FACEBOOK_CLIENT_ID"),
      client_secret: System.get_env("FACEBOOK_CLIENT_SECRET")
    },
    apple: %{
      client_id: System.get_env("APPLE_CLIENT_ID"),
      team_id: System.get_env("APPLE_TEAM_ID"),
      private_key_id: System.get_env("APPLE_KEY_ID"),
      private_key_path: System.get_env("APPLE_PRIVATE_KEY_PATH")
    }

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      Set it to the canonical hostname, e.g. PHX_HOST=makola.io.
      It is used for URL generation (emails, webhooks) and check_origin —
      a silent default would generate links to the wrong domain.
      """

  # OAuth callback base — providers redirect back to
  # "<base>/<subject>/<strategy>/callback" (e.g. .../oauth/merchant/google/callback).
  # Derived from PHX_HOST so it follows the canonical host automatically.
  config :emakola, :oauth_redirect_base, "https://#{host}/oauth"

  config :emakola, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :emakola, EmakolaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # WebSocket origin allowlist. The wildcard covers merchant subdomain
    # storefronts (shopname.emakola.com). NOTE: merchant CUSTOM domains
    # (www.merchantshop.com) need their origins added here — or a
    # function-based check_origin — before LiveView will connect for them.
    check_origin: [
      "https://#{host}",
      "https://www.#{host}",
      "https://*.#{host}",
      # Fly's default hostname — the app is reachable here until (and after)
      # the emakola.com DNS cutover. Without it, LiveView websockets from
      # emakola.fly.dev are rejected and clients degrade to long-polling,
      # which breaks across multiple machines (reconnect/error loops).
      "https://emakola.fly.dev"
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # Branded merchant subdomains (yourshop.makola.io). Ships dark: until this is
  # set, EmakolaWeb.Plugs.ResolveStoreByHost is a pure pass-through. Set it to
  # the apex (e.g. "makola.io") only AFTER wildcard *.makola.io DNS + TLS exist,
  # or branded hosts would resolve to a cert error.
  config :emakola, :store_subdomain_base, System.get_env("STORE_SUBDOMAIN_BASE")

  # Hosts that 301-redirect to the canonical apex (EmakolaWeb.Plugs.CanonicalHost).
  # Auto-activates once PHX_HOST is makola.io: the Fly default + emakola.* aliases
  # consolidate onto the brand apex, and www -> apex. Override with
  # CANONICAL_REDIRECT_HOSTS (comma-separated) for any other host setup, or set it
  # to an empty string to disable the redirects entirely.
  canonical_redirect_hosts =
    case System.get_env("CANONICAL_REDIRECT_HOSTS") do
      nil ->
        if host == "makola.io",
          do: ["www.makola.io", "emakola.fly.dev", "emakola.com", "www.emakola.com"],
          else: []

      csv ->
        csv |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    end

  config :emakola, :canonical_redirect_hosts, canonical_redirect_hosts

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :emakola, EmakolaWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :emakola, EmakolaWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :emakola, Emakola.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
