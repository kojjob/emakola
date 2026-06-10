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

config :emakola, EmakolaWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Runtime knob (all envs) — compile-time evaluation would bake the
# builder's (unset) value into release builds permanently.
config :emakola, :demo_mode, System.get_env("DEMO_MODE") == "true"

if config_env() == :prod do
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

  # Flat key — read by Emakola.Payments.Gateways.Paystack (webhook HMAC)
  # and Emakola.Payments.PaystackWebhook.
  config :emakola, :paystack_secret_key, paystack_secret_key

  # Nested keyword config — read by Emakola.Payments.PaystackClient.
  config :emakola, Emakola.Payments.PaystackClient,
    secret_key: paystack_secret_key,
    public_key: System.get_env("PAYSTACK_PUBLIC_KEY") || ""

  # Hubtel (optional at launch) — read by Emakola.Payments.HubtelClient.
  if hubtel_id = System.get_env("HUBTEL_CLIENT_ID") do
    config :emakola, Emakola.Payments.HubtelClient,
      client_id: hubtel_id,
      client_secret: System.get_env("HUBTEL_CLIENT_SECRET") || ""
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
  # keyword config.
  config :emakola, :sms_provider, Emakola.Notifications.Channels.SMS

  config :emakola, Emakola.Notifications.Channels.SMS,
    api_key:
      System.get_env("SMS_API_KEY") ||
        raise("environment variable SMS_API_KEY is missing."),
    sender_id: System.get_env("SMS_SENDER_ID") || "Emakola",
    api_url:
      System.get_env("SMS_API_URL") ||
        raise("environment variable SMS_API_URL is missing.")

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

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      Set it to the canonical hostname, e.g. PHX_HOST=emakola.com.
      It is used for URL generation (emails, webhooks) and check_origin —
      a silent default would generate links to the wrong domain.
      """

  config :emakola, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :emakola, EmakolaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # WebSocket origin allowlist. The wildcard covers merchant subdomain
    # storefronts (shopname.emakola.com). NOTE: merchant CUSTOM domains
    # (www.merchantshop.com) need their origins added here — or a
    # function-based check_origin — before LiveView will connect for them.
    check_origin: ["https://#{host}", "https://www.#{host}", "https://*.#{host}"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

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
