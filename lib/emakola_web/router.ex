defmodule EmakolaWeb.Router do
  use EmakolaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmakolaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Health check — required by Docker/fly.toml for deployment readiness
  scope "/api", EmakolaWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  # Auth session controller (sets/clears session cookie)
  scope "/auth", EmakolaWeb do
    pipe_through :browser
    get "/session", AuthSessionController, :create
    delete "/session", AuthSessionController, :delete
  end

  # Auth routes (no layout — full-page auth screens)
  scope "/auth", EmakolaWeb.Auth do
    pipe_through :browser
    live "/login", LoginLive
    live "/register", RegisterLive
  end

  scope "/", EmakolaWeb do
    pipe_through :browser

    live "/", LandingLive
    live "/docs", Docs.DocsLive

    # Authenticated app routes with sidebar layout
    live_session :app,
      layout: {EmakolaWeb.Layouts, :app},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequireAuth, :default},
        {EmakolaWeb.Hooks.NotificationHandler, :default}
      ] do
      live "/dashboard", DashboardLive
    end

    live "/onboarding", OnboardingLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:emakola, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EmakolaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
