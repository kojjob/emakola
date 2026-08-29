defmodule Emakola.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Activate the Sentry logger handler (configured under `config :emakola, :logger`).
    Logger.add_handlers(:emakola)

    children =
      [
        EmakolaWeb.Telemetry,
        Emakola.Metrics,
        Emakola.Repo,
        {DNSCluster, query: Application.get_env(:emakola, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Emakola.PubSub},
        # Expunges expired token rows (see Emakola.Accounts.Token)
        {AshAuthentication.Supervisor, otp_app: :emakola},
        {Finch, name: Emakola.Finch},
        # Fire-and-forget work that must not sit on the request path — e.g.
        # password-reset delivery, where a synchronous provider round-trip
        # would leak account existence through response latency.
        {Task.Supervisor, name: Emakola.TaskSupervisor},
        {Emakola.RateLimit, clean_period: :timer.minutes(10)},
        {Oban, Application.fetch_env!(:emakola, Oban)},
        # PDF generation via headless Chrome (opts set per-env in config/runtime.exs)
        {ChromicPDF, Application.get_env(:emakola, ChromicPDF, [])},
        # ETS cache for storefront product/category queries
        Emakola.Cache.StoreCache,
        # Per-store daily AI-generation cap (SEO Phase 3 cost guard)
        Emakola.Content.RateLimiter
      ] ++ metrics_children() ++ [EmakolaWeb.Endpoint] ++ fcm_children() ++ gsc_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Emakola.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EmakolaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Goth OAuth2 token server for FCM — only when FCM is configured
  # (FCM_SERVICE_ACCOUNT_JSON in prod). Dev/test boot without it.
  defp fcm_children do
    case System.get_env("FCM_SERVICE_ACCOUNT_JSON") do
      nil ->
        []

      json ->
        credentials = Jason.decode!(json)

        [{Goth, name: Emakola.Goth, source: {:service_account, credentials}}]
    end
  end

  # Goth token server for the Search Console API — a separate instance from
  # Emakola.Goth because the scope differs (read-only Search Console, not FCM
  # messaging) and the two use different service accounts.
  defp gsc_children do
    case System.get_env("GSC_SERVICE_ACCOUNT_JSON") do
      nil ->
        []

      json ->
        credentials = Jason.decode!(json)

        [
          {Goth,
           name: Emakola.GscGoth,
           source:
             {:service_account, credentials,
              scopes: ["https://www.googleapis.com/auth/webmasters.readonly"]}}
        ]
    end
  end

  defp metrics_children do
    case Application.get_env(:emakola, :metrics_port) do
      port when is_integer(port) and port > 0 ->
        options = [
          plug: Emakola.Metrics.Endpoint,
          scheme: :http,
          port: port,
          ip: {0, 0, 0, 0},
          startup_log: false
        ]

        [Supervisor.child_spec({Bandit, options}, id: Emakola.Metrics.Endpoint)]

      _disabled ->
        []
    end
  end
end
