defmodule EmakolaWeb.Router do
  use EmakolaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmakolaWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "cross-origin-opener-policy" => "same-origin"
    }

    plug EmakolaWeb.Plugs.ContentSecurityPolicy
    plug EmakolaWeb.Plugs.CartSession
    plug EmakolaWeb.Plugs.UtmCapture
    plug EmakolaWeb.Plugs.RecentlyViewedStores
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Pipeline for SEO/crawler endpoints that return XML or plain text.
  # Separate from :api to avoid the JSON-only :accepts plug rejecting
  # crawlers that send Accept: text/xml or Accept: */*.
  pipeline :seo do
    plug :accepts, ["xml", "text", "html", "json"]
  end

  # Stricter rate limiting for authentication endpoints to prevent brute-force attacks
  pipeline :auth_rate_limit do
    plug EmakolaWeb.Plugs.RateLimiter, limit: 10, window_ms: 60_000
  end

  # Source-IP allowlist for the Hubtel webhook endpoint. Hubtel does not
  # sign webhooks, so remote_ip is the only trust boundary. The plug fails
  # closed on any misconfiguration.
  pipeline :hubtel_webhook_auth do
    plug EmakolaWeb.Plugs.HubtelAllowlist
  end

  # Health check — required by Docker/fly.toml for deployment readiness
  scope "/api", EmakolaWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end

  # Payment gateway webhooks — no CSRF, raw JSON bodies.
  #
  # Paystack is authenticated via HMAC-SHA512 signature verified in the
  # controller/gateway. Hubtel does not sign webhooks, so the route is
  # gated by :hubtel_webhook_auth which matches conn.remote_ip against a
  # configured IPv4/CIDR allowlist and fails closed on misconfiguration.
  scope "/webhooks", EmakolaWeb do
    pipe_through [:api, :hubtel_webhook_auth]
    post "/hubtel", WebhookController, :hubtel
  end

  scope "/webhooks", EmakolaWeb do
    pipe_through :api
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

  # Platform staff session controller (exchanges a short-lived signed login
  # token for a DB-backed session). GET is rate limited (brute-force vector).
  scope "/platform", EmakolaWeb do
    pipe_through [:browser, :auth_rate_limit]
    get "/session", PlatformSessionController, :create
  end

  scope "/platform", EmakolaWeb do
    pipe_through :browser
    delete "/session", PlatformSessionController, :delete
  end

  # Platform staff login (two-step: password + TOTP). Root layout only —
  # no platform sidebar. Staff with a live session skip straight to /platform.
  scope "/platform", EmakolaWeb do
    pipe_through [:browser, :auth_rate_limit]

    live_session :platform_auth,
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RedirectIfPlatformStaff, :default}
      ] do
      live "/login", Platform.LoginLive
      live "/invite/accept/:token", Platform.InviteAcceptLive
    end
  end

  # Customer storefront session controller (sets/clears customer token cookie)
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through [:browser, :auth_rate_limit]
    get "/auth/customer-session", CustomerSessionController, :create
  end

  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through :browser
    delete "/auth/customer-session", CustomerSessionController, :delete
    get "/auth/customer-logout", CustomerSessionController, :logout

    # Digital download delivery (Phase 1). Resolves the customer from
    # session, validates grant ownership + expiry/limit, redirects to
    # a presigned URL from Emakola.Storage.
    get "/downloads/:id", DownloadController, :show
  end

  # Customer storefront auth pages (login/register — no customer auth required)
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through [:browser, :auth_rate_limit]

    live_session :storefront_auth,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [{EmakolaWeb.Hooks.ResolveStore, :default}],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/login", CustomerLoginLive
      live "/register", CustomerRegisterLive
    end
  end

  # Platform-level sitemap (apex domain marketing pages).
  # TODO: when store subdomain routing lands, add a host guard here so
  # mystore.emakola.com/sitemap.xml serves the store sitemap instead.
  scope "/", EmakolaWeb do
    pipe_through :seo
    get "/sitemap.xml", SitemapController, :platform
  end

  # Sitemap + AI-readable files — uses :seo pipeline (accepts XML/text),
  # NOT :api (which enforces JSON-only and would 406 crawlers).
  scope "/s/:store_slug", EmakolaWeb do
    pipe_through :seo
    get "/sitemap.xml", SitemapController, :show
    get "/robots.txt", SitemapController, :robots
    get "/llms.txt", SitemapController, :llms
    get "/feed/instagram.xml", InstagramFeedController, :show
  end

  # Customer storefront (public — no auth required)
  # In production, store is resolved from subdomain. For now, use store slug in URL.
  scope "/s/:store_slug", EmakolaWeb.Storefront do
    pipe_through :browser

    live_session :storefront,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStore, :default},
        {EmakolaWeb.Hooks.ResolveCustomer, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/", StoreLive
      live "/products", ProductListLive
      live "/products/:product_slug", ProductDetailLive
      live "/cart", CartLive
      live "/checkout", CheckoutLive
      live "/orders/:order_number/confirmation", OrderConfirmationLive
      live "/category/:category_slug", CategoryLive
      live "/about", AboutLive
      live "/blog", BlogListLive
      live "/blog/:post_slug", BlogPostLive
      live "/recipes", RecipeListLive
      live "/recipes/:recipe_slug", RecipeLive
      live "/account", AccountLive
      live "/account/downloads", AccountDownloadsLive
      live "/saved-stores", SavedStoresLive
      live "/wishlist", WishlistLive
      live "/track/:order_number", TrackingLive
      live "/p/:page_slug", PageLive
    end
  end

  scope "/", EmakolaWeb do
    pipe_through :browser

    live "/", LandingLive
    live "/pricing", PricingLive
    live "/stores", StoresLive
    live "/docs", Docs.DocsLive

    # Platform admin routes (platform staff only). Pages gate themselves with
    # a module-level {Hooks.RequirePermission, permission} on_mount:
    #   stores → :manage_stores, team → :manage_team, audit-log → :view_audit_log
    # Future pages: merchants → :manage_merchants, billing → :manage_billing,
    # settings → :manage_settings. Dashboard and security are any-staff.
    live_session :platform,
      layout: {EmakolaWeb.Layouts, :platform},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequirePlatformStaff, :default}
      ] do
      live "/platform", Platform.DashboardLive
      live "/platform/stores", Platform.StoreLive.Index
      live "/platform/team", Platform.TeamLive
      live "/platform/security", Platform.SecurityLive
      live "/platform/audit-log", Platform.AuditLogLive
    end

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
      live "/admin/products/:id/files", Admin.ProductLive.DigitalFiles
      live "/admin/categories", Admin.CategoryLive.Index

      # Merchant admin — review management
      live "/admin/reviews", Admin.ReviewLive

      # Merchant admin — inventory management
      live "/admin/inventory", Admin.InventoryLive

      # Merchant admin — order management
      live "/admin/orders", Admin.OrderLive.Index
      live "/admin/orders/:id", Admin.OrderLive.Show

      # Merchant admin — returns
      live "/admin/returns", Admin.ReturnLive

      # Merchant admin — payment reconciliation
      live "/admin/payments", Admin.PaymentsLive

      # Customer management
      live "/admin/customers", Admin.CustomerLive.Index
      live "/admin/customers/:id", Admin.CustomerLive.Show

      # Store settings & delivery zones
      live "/admin/settings", Admin.SettingsLive
      live "/admin/settings/delivery", Admin.DeliveryLive.Index

      # Suppliers (dropshipping) — management + payout ledger
      live "/admin/settings/suppliers", Admin.SupplierLive.Index
      live "/admin/suppliers/:id", Admin.SupplierLive.Show

      # Theme customizer
      live "/admin/theme", Admin.ThemeLive
      live "/admin/design", Admin.DesignLive

      # Marketing
      live "/admin/campaigns", Admin.CampaignLive.Index
      live "/admin/discounts", Admin.DiscountLive.Index
      live "/admin/coupons", Admin.CouponLive

      # Content management
      live "/admin/content/posts", Admin.Content.PostLive.Index
      live "/admin/content/posts/new", Admin.Content.PostLive.Form, :new
      live "/admin/content/posts/:id/edit", Admin.Content.PostLive.Form, :edit
      live "/admin/content/media", Admin.Content.MediaLive.Index

      # Pages (block-based merchant pages with images/audio/video)
      live "/admin/pages", Admin.PageLive.Index
      live "/admin/pages/new", Admin.PageLive.Form, :new
      live "/admin/pages/:id/edit", Admin.PageLive.Form, :edit

      # Analytics
      live "/admin/reports", Admin.ReportLive.Index
      live "/admin/revenue", Admin.RevenueLive.Index
    end

    # PDF export (outside live_session, uses session-based auth)
    get "/admin/export/analytics.pdf", ExportController, :analytics_pdf

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
