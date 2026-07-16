defmodule EmakolaWeb.Router do
  use EmakolaWeb, :router
  use AshAuthentication.Phoenix.Router

  # Hosts that serve the apex (marketing + platform/app admin), NOT a store.
  # A host string WITHOUT a trailing dot is an EXACT match in `scope host:`, so
  # `host: @apex_hosts` matches these hosts only; store subdomains
  # (`kente-kingdom.makola.io`) fall through to the no-host storefront catch-all.
  # fly.dev is listed so the platform host never reaches the catch-all.
  @apex_hosts ~w(makola.io www.makola.io emakola.com www.emakola.com emakola.fly.dev localhost 127.0.0.1)

  pipeline :browser do
    plug :accepts, ["html"]
    # Redirects alias hosts (emakola.com/www/fly default) to the canonical apex.
    # No-op until `:canonical_redirect_hosts` is configured (post emakola.io cutover).
    plug EmakolaWeb.Plugs.CanonicalHost
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

  # Public, store-scoped browse API. Accepts JSON:API media type; per-IP rate
  # limited. Tenant is set per-request by PublicStoreTenant (see scopes below).
  pipeline :shop_api do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  # Pipeline for SEO/crawler endpoints that return XML or plain text.
  # Separate from :api to avoid the JSON-only :accepts plug rejecting
  # crawlers that send Accept: text/xml or Accept: */*.
  pipeline :seo do
    plug :accepts, ["xml", "text", "html", "json"]
    plug :put_secure_browser_headers
    plug EmakolaWeb.Plugs.ContentSecurityPolicy
  end

  # Stricter per-IP rate limiting for authentication endpoints to prevent brute-force attacks.
  # key: :ip forces IP-only keying so attacker-controlled headers (Bearer/X-Org-ID) cannot
  # mint a fresh bucket per request and bypass the limit.
  pipeline :auth_rate_limit do
    plug EmakolaWeb.Plugs.RateLimiter, limit: 10, window_ms: 60_000, key: :ip
  end

  # Resolves + sets the store tenant for storefront (customer) OAuth. No-op for
  # merchant OAuth routes, so it can sit in the shared /oauth pipeline.
  pipeline :customer_oauth_tenant do
    plug EmakolaWeb.Plugs.CustomerOAuthTenant
  end

  # Host-routed storefront: resolves the store from conn.host (the request
  # subdomain) and stashes the slug in the session for ResolveStoreFromHost.
  # Redirects to / on the apex / a reserved label / an unknown host.
  pipeline :resolve_store_host do
    plug EmakolaWeb.Plugs.ResolveStoreHost
  end

  # Unauthenticated mobile-API auth endpoints: JSON + strict per-IP limit.
  # Deliberately NOT stacked on :api — two RateLimiter plugs with the same
  # key share one Hammer bucket and double-count every request.
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 10, window_ms: 60_000, key: :ip
  end

  # Mobile/JSON API: bearer-token merchant auth, then X-Store-ID tenant.
  pipeline :api_bearer do
    plug EmakolaWeb.Plugs.ApiBearerAuth
  end

  pipeline :api_tenant do
    plug EmakolaWeb.Plugs.ApiTenant
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

  # Mobile/JSON API auth — bearer token pair lifecycle. Strict per-IP rate limit:
  # sign_in is a brute-force vector, refresh a replay-probe vector.
  scope "/api/v1/auth", EmakolaWeb.Api do
    pipe_through :api_auth

    post "/sign_in", AuthController, :sign_in
    post "/refresh", AuthController, :refresh
    delete "/sign_out", AuthController, :sign_out
  end

  # Authenticated, NOT tenant-scoped — used to discover/pick a store.
  # MUST stay above the /api/v1 JSON:API forward: `forward` matches every
  # path under its prefix, so a forward declared earlier would swallow
  # /api/v1/stores silently.
  scope "/api/v1", EmakolaWeb.Api do
    pipe_through [:api, :api_bearer]

    get "/stores", StoreController, :index
  end

  # Public store-scoped browse API. Both routes resolve the tenant from the
  # :store_slug via PublicStoreTenant — the Ash tenant is ALWAYS set before the
  # global?(true) browse actions run, fail-closed on unknown/inactive slug (the
  # cross-store leak guard).
  #
  # MUST stay above the /api/v1 JSON:API forward below: that forward matches
  # every path under /api/v1 (including /api/v1/shop/...), so these must be
  # declared first or they get swallowed (same trap as /api/v1/stores).
  #
  # Store-info GET "/" is declared before the ShopApiForward forward for the same
  # reason — the explicit, more-specific route wins over the catch-all forward.
  scope "/api/v1/shop/:store_slug", EmakolaWeb.Api do
    pipe_through [:shop_api, EmakolaWeb.Plugs.PublicStoreTenant]
    get "/", ShopController, :show
  end

  # Phoenix `forward` forbids a dynamic segment, so we forward a STATIC prefix to
  # ShopApiForward, which pops the slug, sets the tenant (PublicStoreTenant,
  # fail-closed), then forwards the rest (e.g. ["products"]) to ShopApiRouter.
  scope "/api/v1/shop" do
    pipe_through :shop_api
    forward "/", EmakolaWeb.Plugs.ShopApiForward
  end

  # Tenant-scoped JSON:API resources (orders; device tokens in a later task).
  # Declared below /api/v1/stores deliberately — forward matches everything
  # under /api/v1, so the stores route above must be declared first.
  scope "/api/v1" do
    pipe_through [:api, :api_bearer, :api_tenant]

    forward "/", EmakolaWeb.ApiRouter
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
    live "/whatsapp", WhatsAppLive
  end

  # Social-login (OAuth) request + callback routes for merchants AND customers,
  # generated by ash_authentication and bridged into the cookie session by
  # AuthController. ONE auth_routes call with both resources — its StrategyRouter
  # dispatches by subject (/oauth/merchant/* and /oauth/customer/*); two separate
  # calls at the same path make the second unreachable. Mounted at /oauth (not
  # /auth) to avoid colliding with the custom routes above. Ship-dark: a strategy
  # 404s until its creds are set and the buttons stay hidden (EmakolaWeb.OAuth).
  # Callback URL per provider: https://<host>/oauth/<subject>/<provider>/callback
  scope "/", EmakolaWeb do
    pipe_through [:browser, :auth_rate_limit, :customer_oauth_tenant]

    auth_routes(AuthController, [Emakola.Accounts.Merchant, Emakola.Customers.Customer],
      path: "/oauth"
    )

    # The interactive email-confirmation page (require_interaction? true): the
    # emailed link GETs this page, which renders a button that POSTs the token
    # to the strategy route under /oauth — so a mail scanner prefetching the
    # link cannot confirm an account.
    confirm_route(Emakola.Accounts.Merchant, :confirm_new_merchant,
      path: "/confirm/merchant",
      auth_routes_prefix: "/oauth"
    )
  end

  # Platform staff session controller (exchanges a short-lived signed login
  # token for a DB-backed session). GET is rate limited (brute-force vector).
  scope "/platform", EmakolaWeb do
    pipe_through [:browser, :auth_rate_limit]
    get "/session", PlatformSessionController, :create
    # Start impersonation — staff + :manage_merchants verified in the controller.
    post "/impersonate/:merchant_id", ImpersonateSessionController, :start
  end

  scope "/platform", EmakolaWeb do
    pipe_through :browser
    delete "/session", PlatformSessionController, :delete
    # Exit impersonation (GET so the banner link + AssignDefaults expiry-redirect reach it).
    get "/impersonate/exit", ImpersonateSessionController, :exit
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
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStore, :default},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/login", CustomerLoginLive
      live "/register", CustomerRegisterLive
      live "/whatsapp", CustomerWhatsAppLive
    end
  end

  # Platform sitemap — host-locked to the apex (exact-match @apex_hosts). On a
  # store subdomain, the catch-all below serves that store's sitemap instead.
  scope "/", EmakolaWeb, host: @apex_hosts do
    pipe_through :seo
    get "/sitemap.xml", SitemapController, :platform
    get "/robots.txt", SitemapController, :platform_robots
    get "/llms.txt", SitemapController, :platform_llms
  end

  # Store sitemap at the subdomain ROOT (<slug>.makola.io/sitemap.xml). The apex
  # route above matches apex hosts first (first-match-wins), so this unrestricted
  # catch-all only fires on store subdomains; :show resolves the store from
  # conn.host via ResolveStoreHost.resolve_store/1 (no session needed, so it sits
  # on the :seo pipeline cleanly).
  scope "/", EmakolaWeb do
    pipe_through :seo
    get "/sitemap.xml", SitemapController, :show
    get "/robots.txt", SitemapController, :robots
    get "/llms.txt", SitemapController, :llms
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
        {EmakolaWeb.Hooks.ResolveCustomer, :default},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
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
      live "/contact", ContactLive
      live "/faq", FaqLive
      live "/policies", PoliciesLive
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

  # Apex marketing + platform/app admin. host-locked to @apex_hosts (exact match)
  # so "/", "/about", "/pricing", etc. match ONLY on the apex — never on a store
  # subdomain, where root is the storefront. Declared BEFORE the storefront
  # catch-all (first-match-wins) so apex hosts resolve here, not the catch-all.
  scope "/", EmakolaWeb, host: @apex_hosts do
    pipe_through :browser

    # Dead render — no LiveView process per anonymous visitor.
    get "/", LandingController, :home
    live "/pricing", PricingLive
    live "/stores", StoresLive
    # Shown when a storefront is requested for a suspended/blocked/closed store.
    live "/store-unavailable", StoreUnavailableLive
    # Programmatic SEO: per-region shop directories + sell-online pages (Phase 4)
    live "/shops/:region", ShopsLive
    live "/sell-online/:region", SellOnlineLive
    live "/docs", Docs.DocsLive
    live "/about", Company.AboutLive
    live "/careers", Company.CareersLive
    live "/press", Company.PressLive
    live "/legal", Company.LegalLive
    live "/privacy", Company.PrivacyLive
    live "/terms", Company.TermsLive
    live "/cookies", Company.CookiesLive
    live "/contact", Company.ContactLive

    # Platform admin routes (platform staff only). Pages gate themselves with
    # a module-level {Hooks.RequirePermission, permission} on_mount:
    #   stores → :manage_stores, team → :manage_team, audit-log → :view_audit_log,
    #   billing → :manage_billing, payments → :manage_billing
    # Future pages: merchants → :manage_merchants, settings → :manage_settings.
    live_session :platform,
      layout: {EmakolaWeb.Layouts, :platform},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequirePlatformStaff, :default}
      ] do
      live "/platform", Platform.DashboardLive
      live "/platform/stores", Platform.StoreLive.Index
      live "/platform/stores/:id", Platform.StoreLive.Show
      live "/platform/merchants", Platform.MerchantLive.Index
      live "/platform/verifications", Platform.VerificationLive.Index
      live "/platform/verifications/:id", Platform.VerificationLive.Show
      live "/platform/moderation", Platform.ModerationLive.Index
      live "/platform/announcements", Platform.AnnouncementLive.Index
      live "/platform/onboarding", Platform.OnboardingLive
      live "/platform/team", Platform.TeamLive
      live "/platform/security", Platform.SecurityLive
      live "/platform/audit-log", Platform.AuditLogLive
      live "/platform/security-events", Platform.SecurityEventsLive
      live "/platform/billing", Platform.BillingLive
      live "/platform/finance", Platform.FinanceLive
      live "/platform/payments", Platform.PaymentLive.Index
      live "/platform/refunds", Platform.RefundsLive
      live "/platform/settings", Platform.SettingsLive
    end

    # Authenticated app routes with sidebar layout
    live_session :app,
      layout: {EmakolaWeb.Layouts, :app},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequireAuth, :default},
        {EmakolaWeb.Hooks.RequireActiveStore, :default},
        {EmakolaWeb.Hooks.NotificationHandler, :default},
        {EmakolaWeb.Hooks.MerchantAnnouncements, :default}
      ] do
      live "/dashboard", DashboardLive

      # Merchant admin — catalog management
      live "/admin/products", Admin.ProductLive.Index
      live "/admin/products/bulk", Admin.ProductLive.BulkPhoto
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

      # SEO quick-wins dashboard (AI content gaps)
      live "/admin/seo", Admin.SEODashboardLive

      # Store settings & delivery zones
      live "/admin/settings", Admin.SettingsLive
      live "/admin/verification", Admin.VerificationLive
      live "/admin/payouts", Admin.PayoutLive
      live "/admin/settings/delivery", Admin.DeliveryLive.Index
      live "/admin/settings/address", Admin.StoreAddressLive

      # Suppliers (dropshipping) — management + payout ledger
      live "/admin/settings/suppliers", Admin.SupplierLive.Index
      live "/admin/settings/supply-network", Admin.SupplyNetworkLive
      live "/admin/suppliers/:id", Admin.SupplierLive.Show

      # Theme customizer
      live "/admin/theme", Admin.ThemeLive
      live "/admin/design", Admin.DesignLive
      live "/admin/design/sections", Admin.DesignSectionsLive

      # Marketing
      live "/admin/campaigns", Admin.CampaignLive.Index
      live "/admin/discounts", Admin.DiscountLive.Index
      live "/admin/coupons", Admin.CouponLive

      # Content management
      live "/admin/content/posts", Admin.Content.PostLive.Index
      live "/admin/content/posts/new", Admin.Content.PostLive.Form, :new
      live "/admin/content/posts/:id/edit", Admin.Content.PostLive.Form, :edit
      live "/admin/content/media", Admin.Content.MediaLive.Index
      live "/admin/content/pages", Admin.Content.PageContentLive

      # Pages (block-based merchant pages with images/audio/video)
      live "/admin/pages", Admin.PageLive.Index
      live "/admin/pages/new", Admin.PageLive.Form, :new
      live "/admin/pages/:id/edit", Admin.PageLive.Form, :edit

      # Analytics
      live "/admin/reports", Admin.ReportLive.Index
      live "/admin/revenue", Admin.RevenueLive.Index
    end

    # Merchant store-locked interstitial — same auth as :app but WITHOUT
    # RequireActiveStore, so a merchant whose store is suspended/blocked/archived
    # can see why without a redirect loop.
    live_session :app_store_locked,
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequireAuth, :default}
      ] do
      live "/store-locked", MerchantStoreLockedLive
    end

    # PDF export (outside live_session, uses session-based auth)
    get "/admin/export/analytics.pdf", ExportController, :analytics_pdf

    live "/onboarding", OnboardingLive
  end

  # ── Host-routed storefront (no host: → catch-all) ───────────────────────────
  # Declared AFTER the host-locked apex scope so apex hosts match there first
  # (first-match-wins). On a store's own subdomain, :resolve_store_host resolves
  # the store from conn.host into the session and the storefront renders at ROOT
  # — so the address-bar URL matches the mounted LiveView and the client never
  # force-reloads. These routes mirror the /s/:store_slug `:storefront` and
  # `:storefront_auth` live_sessions, at root, under distinct live_session names.

  # Storefront customer-session controller at ROOT, host-resolved. Mirrors the
  # /s/:store_slug controller routes so logged-in subdomain customers can sign
  # out (the storefront's logout link renders root-relative via store_path/2)
  # and fetch digital downloads. The controllers read the store from
  # conn.assigns[:store] (set by ResolveStoreHost) on this path.
  scope "/", EmakolaWeb.Storefront do
    pipe_through [:browser, :resolve_store_host, :auth_rate_limit]
    get "/auth/customer-session", CustomerSessionController, :create
  end

  scope "/", EmakolaWeb.Storefront do
    pipe_through [:browser, :resolve_store_host]
    delete "/auth/customer-session", CustomerSessionController, :delete
    get "/auth/customer-logout", CustomerSessionController, :logout
    get "/downloads/:id", DownloadController, :show
  end

  # Storefront customer-auth pages (login/register — no customer auth required).
  scope "/", EmakolaWeb.Storefront do
    pipe_through [:browser, :resolve_store_host]

    live_session :storefront_auth_root,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStoreFromHost, :default},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/login", CustomerLoginLive
      live "/register", CustomerRegisterLive
      live "/whatsapp", CustomerWhatsAppLive
    end
  end

  # Storefront (public — no auth required). ResolveStoreFromHost BEFORE
  # ResolveCustomer: the customer hook reads the store's tenant context.
  scope "/", EmakolaWeb.Storefront do
    pipe_through [:browser, :resolve_store_host]

    live_session :storefront_root,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStoreFromHost, :default},
        {EmakolaWeb.Hooks.ResolveCustomer, :default},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
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
      live "/contact", ContactLive
      live "/faq", FaqLive
      live "/policies", PoliciesLive
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
