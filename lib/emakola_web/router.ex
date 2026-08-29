defmodule EmakolaWeb.Router do
  use EmakolaWeb, :router
  use AshAuthentication.Phoenix.Router

  # Hosts that serve the apex (marketing + platform/app admin), NOT a store.
  # A host string WITHOUT a trailing dot is an EXACT match in `scope host:`, so
  # `host: @apex_hosts` matches these hosts only; store subdomains
  # (`kente-kingdom.makola.io`) fall through to the no-host storefront catch-all.
  # fly.dev is listed so the platform host never reaches the catch-all.
  #
  # Sourced from config so `Emakola.Stores.Validations.ValidStoreHost` rejects
  # these same hosts as custom domains. Must stay compile_env: `scope host:`
  # needs a literal, and a nil here fails the build rather than silently
  # matching nothing.
  @apex_hosts Application.compile_env!(:emakola, :apex_hosts)

  pipeline :browser do
    plug :accepts, ["html"]
    # Redirects alias hosts (emakola.com/www/fly default) to the canonical apex.
    # No-op until `:canonical_redirect_hosts` is configured (post emakola.io cutover).
    plug EmakolaWeb.Plugs.CanonicalHost
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmakolaWeb.Layouts, :root}
    plug :protect_from_forgery

    # referrer-policy matters more here than on a typical app because several
    # pages carry a credential IN THE PATH — /pair/:token, /susu/:code and
    # /supply/:token. Without this header any outbound link on one of those
    # pages hands the whole URL, token included, to the destination in Referer.
    # Phoenix sets no referrer policy by default.
    plug :put_secure_browser_headers, %{
      "cross-origin-opener-policy" => "same-origin",
      "referrer-policy" => "strict-origin-when-cross-origin"
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

  # The supplier action link is unauthenticated by design — the supplier has no
  # account. key: :ip for the same reason as :auth_rate_limit: attacker-controlled
  # headers must not be able to mint a fresh bucket. Per-fulfilment write limits
  # live in Emakola.Suppliers.SupplierAction; this one only caps request noise.
  pipeline :supplier_action_rate_limit do
    plug EmakolaWeb.Plugs.RateLimiter, limit: 30, window_ms: 60_000, key: :ip
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
    # SplitPay events — HMAC-signed (t=..,v1=..) over the raw body.
    post "/splitpay", SplitPayWebhookController, :handle
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

  # Merchant product writes for the mobile app. Explicit controllers, not
  # ash_json_api: a resource's `json_api` routes are mounted by every router
  # including that domain, and ShopApiRouter mounts Catalog on the PUBLIC
  # storefront surface — product creation must not be routable there.
  #
  # MUST stay above the /api/v1 forward below for the usual reason: that
  # forward matches every path under /api/v1 and would swallow these.
  scope "/api/v1", EmakolaWeb.Api do
    pipe_through [:api, :api_bearer, :api_tenant]

    post "/products", ProductController, :create
    post "/products/:id/variants", ProductController, :create_variant
    post "/products/:id/images", ProductController, :create_image
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

    live_session :merchant_auth,
      on_mount: [{EmakolaWeb.Hooks.NoIndex, :default}] do
      live "/login", LoginLive
      live "/register", RegisterLive
      live "/whatsapp", WhatsAppLive
      live "/forgot-password", ForgotPasswordLive
      live "/recover-phone", PhoneRecoveryLive
      live "/reset-password", ResetPasswordLive
    end
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

    # The interactive email-confirmation page needs no extra route: auth_routes'
    # StrategyRouter serves GET /oauth/merchant/confirm_new_merchant (:accept —
    # the button page) and POST (the actual confirm), so a mail scanner
    # prefetching the emailed GET link cannot confirm an account.
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
        {EmakolaWeb.Hooks.NoIndex, :default},
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
    get "/feed/products.xml", InstagramFeedController, :show
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
      live "/account/messages", CustomerMessagesLive
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
  # Supplier action link — how a dropship supplier accepts, declines or ships a
  # fulfilment. Its own scope purely so it can carry the rate-limit pipeline:
  # folding it into the apex browser scope below would throttle every marketing
  # page at 30 requests a minute.
  #
  # Public because the supplier is a local wholesaler on WhatsApp with no Makola
  # account. The signed token in the URL is the only credential, it is bound to
  # one fulfilment, and the merchant revokes it by rotating
  # Fulfillment.supplier_link_version. Declared before the storefront catch-all,
  # and apex-host scoped like /pay, /susu and /pair, so no store subdomain can
  # shadow it.
  #
  # No layout, like /pair: the storefront layout wraps a shop header, a
  # payment-logo row and a search overlay around a page whose only job is three
  # buttons, and needs assigns this page has no store to provide. NoIndex
  # because the URL carries a credential.
  scope "/", EmakolaWeb, host: @apex_hosts do
    pipe_through [:browser, :supplier_action_rate_limit]

    live_session :supplier_action,
      on_mount: [{EmakolaWeb.Hooks.NoIndex, :default}] do
      live "/supply/:token", Supplier.ActionLive
    end
  end

  scope "/", EmakolaWeb, host: @apex_hosts do
    pipe_through :browser

    # Dead render — no LiveView process per anonymous visitor.
    get "/", LandingController, :home
    get "/how-it-works", HowItWorksController, :show
    get "/how-it-works/tour", HowItWorksController, :tour
    live "/pricing", PricingLive
    live "/stores", StoresLive
    # Shown when a storefront is requested for a suspended/blocked/closed store.
    live "/store-unavailable", StoreUnavailableLive
    # Programmatic SEO: per-region shop directories + sell-online pages (Phase 4)
    live "/shops/:region", ShopsLive
    live "/sell-online/:region", SellOnlineLive
    live "/docs", Docs.DocsLive
    # Platform marketing blog — merchant-acquisition SEO content (nil store_id
    # posts). Store subdomain /blog stays the storefront blog via the catch-all.
    live "/blog", PlatformBlogLive
    live "/blog/:post_slug", PlatformPostLive
    live "/about", Company.AboutLive
    live "/careers", Company.CareersLive
    live "/press", Company.PressLive
    live "/legal", Company.LegalLive
    live "/privacy", Company.PrivacyLive
    live "/terms", Company.TermsLive
    live "/cookies", Company.CookiesLive
    live "/contact", Company.ContactLive

    # Pay links — express checkout shared into DMs. This scope is
    # host: @apex_hosts, so no store subdomain can shadow this path.
    live_session :pay_link,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [{EmakolaWeb.Hooks.AssignDefaults, :default}] do
      live "/pay/:code", Storefront.PayLinkLive
    end

    # Device pairing — the phone half of scan-to-sign-in. Public because the
    # phone is by definition not signed in yet; the token in the URL is the only
    # credential, it is single-use, and it is worthless until the merchant
    # confirms on their already-authenticated desktop. Apex-host scoped like the
    # other code-bearing pages, so no store subdomain can shadow it.
    # No layout, matching the auth routes above: this is a full-page sign-in
    # screen, not a shop page. It previously borrowed the storefront layout from
    # the pay-link block next door, which put a "Shop" header and a row of
    # payment logos around a page whose only job is to sign a phone in.
    # NoIndex because the URL carries a credential.
    live_session :device_pairing,
      on_mount: [{EmakolaWeb.Hooks.NoIndex, :default}] do
      live "/pair/:token", PairLive
    end

    # The exchange itself. A controller, not a LiveView, because signing in
    # means writing the session cookie.
    get "/pair/:token/complete", PairController, :complete

    # Susu (lay-away) buyer pages — public bare-code face + signed "My susu"
    # progress face, both served by ONE LiveView. Same apex-host posture as
    # pay links above (this scope is host: @apex_hosts).
    live_session :susu_link,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [{EmakolaWeb.Hooks.AssignDefaults, :default}] do
      live "/susu/:code", Storefront.SusuLinkLive
    end

    # Platform admin routes (platform staff only). Pages gate themselves with
    # a module-level {Hooks.RequirePermission, permission} on_mount:
    #   stores → :manage_stores, team → :manage_team, audit-log → :view_audit_log,
    #   billing → :manage_billing, payments → :manage_billing,
    #   protection → :manage_billing
    # Future pages: merchants → :manage_merchants, settings → :manage_settings.
    live_session :platform,
      layout: {EmakolaWeb.Layouts, :platform},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :default},
        {EmakolaWeb.Hooks.RequirePlatformStaff, :default}
      ] do
      live "/platform", Platform.DashboardLive
      live "/platform/stores", Platform.StoreLive.Index
      live "/platform/domains", Platform.DomainLive.Index
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
      live "/platform/messages", Platform.MessageLive
      live "/platform/messages/:id", Platform.MessageLive
      live "/platform/protection", Platform.ProtectionLive
      live "/platform/settings", Platform.SettingsLive
    end

    # Authenticated app routes with sidebar layout
    live_session :app,
      layout: {EmakolaWeb.Layouts, :app},
      on_mount: [
        {EmakolaWeb.Hooks.AssignDefaults, :merchant},
        {EmakolaWeb.Hooks.RequireAuth, :default},
        {EmakolaWeb.Hooks.RequireActiveStore, :default},
        {EmakolaWeb.Hooks.MerchantAnnouncements, :default}
      ] do
      live "/dashboard", DashboardLive

      # Merchant admin — catalog management
      live "/admin/products", Admin.ProductLive.Index
      live "/admin/products/bulk", Admin.ProductLive.BulkPhoto
      live "/admin/products/new", Admin.ProductLive.Form, :new
      live "/admin/products/snap", Admin.ProductLive.Snap
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
      live "/admin/pair-phone", Admin.PairPhoneLive
      live "/admin/verification", Admin.VerificationLive
      live "/admin/payouts", Admin.PayoutLive
      live "/admin/earnings", Admin.EarningsLive
      live "/admin/settings/notifications", Admin.NotificationSettingsLive
      live "/admin/settings/delivery", Admin.DeliveryLive.Index
      live "/admin/settings/address", Admin.StoreAddressLive
      live "/admin/settings/domain", Admin.StoreDomainLive

      # Suppliers (dropshipping) — management + payout ledger
      live "/admin/settings/suppliers", Admin.SupplierLive.Index
      live "/admin/settings/supply-network", Admin.SupplyNetworkLive
      live "/admin/supply/catalog", Admin.SupplyCatalogLive.Index
      live "/admin/supply/catalog/:offer_id", Admin.SupplyCatalogLive.Show
      live "/admin/supply/offers", Admin.SupplyOffersLive.Index
      live "/admin/supply/offers/new", Admin.SupplyOffersLive.Form, :new
      live "/admin/supply/offers/:id/edit", Admin.SupplyOffersLive.Form, :edit
      live "/admin/suppliers/:id", Admin.SupplierLive.Show

      # Theme customizer
      live "/admin/theme", Admin.ThemeLive
      live "/admin/design", Admin.DesignLive
      live "/admin/design/sections", Admin.DesignSectionsLive

      # Marketing
      live "/admin/messages", Admin.MessageLive
      live "/admin/messages/:id", Admin.MessageLive
      live "/admin/campaigns", Admin.CampaignLive.Index
      # The placeholder discounts page is gone; Marketing.Coupon is the real
      # feature and /admin/coupons its page. Kept so bookmarks do not 404.
      live "/admin/discounts", Admin.DiscountRedirectLive
      live "/admin/coupons", Admin.CouponLive
      live "/admin/pay-links", Admin.PayLinkLive.Index

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
        {EmakolaWeb.Hooks.AssignDefaults, :merchant},
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
        {EmakolaWeb.Hooks.NoIndex, :default},
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
      live "/account/messages", CustomerMessagesLive
      live "/saved-stores", SavedStoresLive
      live "/wishlist", WishlistLive
      live "/track/:order_number", TrackingLive
      live "/p/:page_slug", PageLive
    end
  end

  # ---------------------------------------------------------------------------
  # Short store URLs: makola.io/yourshop
  #
  # Declared LAST, on purpose. Phoenix takes the first matching route, so every
  # apex page above wins — makola.io/pricing is the pricing page, and no store
  # slug can ever shadow it. The hazard runs the other way (a store slugged
  # `pricing` being unreachable here), and `EmakolaWeb.ReservedStoreSlugs`
  # closes that at slug-generation time, deriving the reserved list from THIS
  # router so it cannot rot.
  #
  # Host-locked to the apex: branded hosts (store subdomains and merchant custom
  # domains) already serve the storefront at root via :storefront_root, where the
  # slug is not in the path at all.
  #
  # The older /s/:store_slug routes above still serve, so links shared before
  # this existed keep working.
  scope "/", EmakolaWeb.Storefront, host: @apex_hosts do
    pipe_through :browser

    live_session :storefront_short,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.ResolveStore, :short},
        {EmakolaWeb.Hooks.ResolveCustomer, :default},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/:store_slug", StoreLive
      live "/:store_slug/products", ProductListLive
      live "/:store_slug/products/:product_slug", ProductDetailLive
      live "/:store_slug/cart", CartLive
      live "/:store_slug/checkout", CheckoutLive
      live "/:store_slug/orders/:order_number/confirmation", OrderConfirmationLive
      live "/:store_slug/category/:category_slug", CategoryLive
      live "/:store_slug/about", AboutLive
      live "/:store_slug/contact", ContactLive
      live "/:store_slug/faq", FaqLive
      live "/:store_slug/policies", PoliciesLive
      live "/:store_slug/blog", BlogListLive
      live "/:store_slug/blog/:post_slug", BlogPostLive
      live "/:store_slug/recipes", RecipeListLive
      live "/:store_slug/recipes/:recipe_slug", RecipeLive
      live "/:store_slug/account", AccountLive
      live "/:store_slug/account/downloads", AccountDownloadsLive
      live "/:store_slug/account/messages", CustomerMessagesLive
      live "/:store_slug/saved-stores", SavedStoresLive
      live "/:store_slug/wishlist", WishlistLive
      live "/:store_slug/track/:order_number", TrackingLive
      live "/:store_slug/p/:page_slug", PageLive
    end
  end

  # Customer auth + session for the short store URLs. Same surface as the
  # /s/:store_slug scopes above — found missing by a production smoke test:
  # checkout redirects a guest to store_path(slug, "/login"), which on the
  # short dialect is /:slug/login, and that 404ed with a paid cart behind it.
  scope "/", EmakolaWeb.Storefront, host: @apex_hosts do
    pipe_through [:browser, :auth_rate_limit]
    get "/:store_slug/auth/customer-session", CustomerSessionController, :create

    live_session :storefront_auth_short,
      layout: {EmakolaWeb.Layouts, :storefront},
      on_mount: [
        {EmakolaWeb.Hooks.NoIndex, :default},
        {EmakolaWeb.Hooks.ResolveStore, :short},
        {EmakolaWeb.Hooks.NewsletterSubscription, :default}
      ],
      session: {EmakolaWeb.Plugs.CartSession, :live_session_data, []} do
      live "/:store_slug/login", CustomerLoginLive
      live "/:store_slug/register", CustomerRegisterLive
      live "/:store_slug/whatsapp", CustomerWhatsAppLive
    end
  end

  scope "/", EmakolaWeb.Storefront, host: @apex_hosts do
    pipe_through :browser
    delete "/:store_slug/auth/customer-session", CustomerSessionController, :delete
    get "/:store_slug/auth/customer-logout", CustomerSessionController, :logout
    get "/:store_slug/downloads/:id", DownloadController, :show
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
