defmodule EmakolaWeb.Router do
  use EmakolaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmakolaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug EmakolaWeb.Plugs.ContentSecurityPolicy
    plug EmakolaWeb.Plugs.CartSession
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Stricter rate limiting for authentication endpoints to prevent brute-force attacks
  pipeline :auth_rate_limit do
    plug EmakolaWeb.Plugs.RateLimiter, limit: 10, window_ms: 60_000
  end

  # Health check — required by Docker/fly.toml for deployment readiness
  scope "/api", EmakolaWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  # Payment gateway webhooks — no CSRF, raw JSON bodies
  scope "/webhooks", EmakolaWeb do
    pipe_through :api
    post "/hubtel", WebhookController, :hubtel
    post "/paystack", WebhookController, :paystack
  end

  # Auth session controller (sets/clears session cookie)
  # GET /session creates a session from a token — rate limited (brute-force vector)
  scope "/auth", EmakolaWeb do
    pipe_through [:browser, :auth_rate_limit]
    get "/session", AuthSessionController, :create
  end

  # DELETE /session is logout — no rate limiting needed (not a brute-force vector)
  scope "/auth", EmakolaWeb do
    pipe_through :browser
    delete "/session", AuthSessionController, :delete
  end

  # Auth routes (no layout — full-page auth screens)
  scope "/auth", EmakolaWeb.Auth do
    pipe_through [:browser, :auth_rate_limit]
    live "/login", LoginLive
    live "/register", RegisterLive
  end

  # Customer storefront (public — no auth required)
  # In production, store is resolved from subdomain. For now, use store slug in URL.
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through :browser

    live_session :storefront,
      layout: {EmakolaWeb.Layouts, :storefront},
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/", StoreLive
      live "/products", ProductListLive
      live "/products/:product_slug", ProductDetailLive
      live "/cart", CartLive
      live "/checkout", CheckoutLive
      live "/orders/:order_number/confirmation", OrderConfirmationLive
      live "/category/:category_slug", CategoryLive
      live "/about", AboutLive
      live "/account", AccountLive
      live "/wishlist", WishlistLive
      live "/track/:order_number", TrackingLive
    end
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

      # Merchant admin — catalog management
      live "/admin/products", Admin.ProductLive.Index
      live "/admin/products/new", Admin.ProductLive.Form, :new
      live "/admin/products/:id/edit", Admin.ProductLive.Form, :edit
      live "/admin/categories", Admin.CategoryLive.Index

      # Merchant admin — order management
      live "/admin/orders", Admin.OrderLive.Index
      live "/admin/orders/:id", Admin.OrderLive.Show

      # Merchant admin — payment reconciliation
      live "/admin/payments", Admin.PaymentsLive

      # Customer management
      live "/admin/customers", Admin.CustomerLive.Index
      live "/admin/customers/:id", Admin.CustomerLive.Show

      # Store settings & delivery zones
      live "/admin/settings", Admin.SettingsLive
      live "/admin/settings/delivery", Admin.DeliveryLive.Index

      # Theme customizer
      live "/admin/theme", Admin.ThemeLive

      # Marketing
      live "/admin/campaigns", Admin.CampaignLive.Index
      live "/admin/discounts", Admin.DiscountLive.Index

      # Analytics
      live "/admin/reports", Admin.ReportLive.Index
      live "/admin/revenue", Admin.RevenueLive.Index
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
