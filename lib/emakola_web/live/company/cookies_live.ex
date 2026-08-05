defmodule EmakolaWeb.Company.CookiesLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Cookie Policy — Makola",
       meta_description: "How and why Makola uses cookies and similar technologies.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/cookies")
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen bg-white font-body antialiased">
        <.landing_nav />
        <main>
          <.legal_layout
            title="Cookie Policy"
            subtitle="How and why we use cookies and similar technologies on the Makola platform."
            last_updated="June 15, 2026"
          >
            <:section id="what-cookies-are" title="What cookies are">
              <p class="text-[#5f6b7a] leading-relaxed">
                Cookies are small text files placed on your device by a website when you visit it.
                They are widely used to make websites work correctly, to remember your preferences,
                and to provide information to the site's owners about how visitors use the site.
              </p>
              <p class="text-[#5f6b7a] leading-relaxed">
                In addition to traditional cookies, we and our partners may use similar technologies
                such as local storage, session storage, and service-worker caches. This policy covers
                all such technologies collectively referred to as "cookies".
              </p>
            </:section>

            <:section id="why-we-use" title="Why we use them">
              <p class="text-[#5f6b7a] leading-relaxed">
                We use cookies to keep you signed in to your account, maintain your shopping cart
                and session state, protect the platform against cross-site request forgery (CSRF),
                remember your language and display preferences, and understand how merchants and
                customers navigate the platform so we can improve it.
              </p>
              <p class="text-[#5f6b7a] leading-relaxed">
                Some cookies are strictly necessary for the platform to function — without them,
                features such as login, checkout, and the merchant dashboard will not work correctly.
                Others are optional and can be managed through your browser settings.
              </p>
            </:section>

            <:section id="categories" title="Categories of cookies">
              <p class="text-[#5f6b7a] leading-relaxed">
                We use the following categories of cookies:
              </p>
              <ul class="list-disc pl-5 text-[#5f6b7a] space-y-1">
                <li>
                  <strong>Strictly necessary</strong> — session cookies, authentication tokens,
                  CSRF protection tokens, and shopping cart state. These cannot be disabled without
                  breaking core platform functionality.
                </li>
                <li>
                  <strong>Functional</strong> — cookies that remember your preferences such as
                  language, store theme, and dashboard layout. Disabling these will not break the
                  platform but may reduce your experience.
                </li>
                <li>
                  <strong>Analytics</strong> — aggregated, anonymised usage data that helps us
                  understand page performance and improve the product. We use privacy-respecting
                  analytics that do not track individuals across sites.
                </li>
              </ul>
              <p class="text-[#5f6b7a] leading-relaxed">
                The Makola platform is also installable as a Progressive Web App (PWA). When
                installed, a service-worker cache stores a limited set of static assets (app shell,
                fonts, icons) to enable offline access and faster load times on low-bandwidth
                connections. This cache is local to your device and does not transmit personal data.
                You can clear it at any time by unregistering the service worker in your browser's
                developer tools or application settings.
              </p>
            </:section>

            <:section id="managing" title="Managing cookies">
              <p class="text-[#5f6b7a] leading-relaxed">
                You can control and manage cookies through your browser settings. Most browsers
                allow you to view, block, or delete cookies. The exact steps vary by browser —
                consult your browser's help documentation for instructions.
              </p>
              <p class="text-[#5f6b7a] leading-relaxed">
                Please note that disabling strictly necessary cookies (session, authentication, CSRF)
                will prevent you from logging in, completing checkout, or using the merchant
                dashboard. We recommend keeping these cookies enabled while using the platform.
              </p>
            </:section>

            <:section id="third-party" title="Third-party cookies">
              <p class="text-[#5f6b7a] leading-relaxed">
                Some features of the platform rely on third-party services that may set their own
                cookies. These include payment providers (Paystack, Hubtel) whose payment widgets
                operate within the checkout flow, and analytics providers. Third-party cookies are
                governed by the respective provider's privacy and cookie policies, which we encourage
                you to review.
              </p>
              <p class="text-[#5f6b7a] leading-relaxed">
                We do not permit third-party advertising cookies on the Makola platform. Any
                third-party integrations are reviewed to ensure they meet our data minimisation
                standards.
              </p>
            </:section>

            <:section id="changes" title="Changes to this policy">
              <p class="text-[#5f6b7a] leading-relaxed">
                We may update this Cookie Policy to reflect changes in our use of cookies or
                applicable law. When we make material changes, we will update the "Last updated"
                date at the top of this page. We encourage you to review this policy periodically.
              </p>
            </:section>

            <:section id="contact" title="Contact us">
              <p class="text-[#5f6b7a] leading-relaxed">
                If you have questions about our use of cookies, please contact us at <a
                  href="mailto:support@emakola.com"
                  class="text-[#d4a843] hover:underline"
                >
                support@emakola.com
              </a>.
              </p>
            </:section>
          </.legal_layout>
        </main>
        <.landing_footer />
      </div>
    </Layouts.app>
    """
  end
end
