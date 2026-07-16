defmodule EmakolaWeb.Company.PrivacyLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Privacy Policy — Makola",
       meta_description: "How Makola collects, uses, and protects merchant and customer data.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/privacy")
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav />
      <main>
        <.legal_layout
          title="Privacy Policy"
          subtitle="How we collect, use, and protect your information."
          last_updated="June 15, 2026"
        >
          <:section id="introduction" title="Introduction">
            <p class="text-[#5f6b7a] leading-relaxed">
              This Privacy Policy explains how Makola ("we", "us", "our") collects, uses, and
              protects personal information when you use our platform, websites, and services.
              By using Makola you agree to the practices described here.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We take privacy seriously and are committed to handling your information with
              care, transparency, and respect for your rights. This policy applies to merchants,
              customers, and visitors to our platform.
            </p>
          </:section>

          <:section id="who-we-are" title="Who we are">
            <p class="text-[#5f6b7a] leading-relaxed">
              Makola operates a multi-tenant commerce platform that enables merchants in Ghana
              and Nigeria to sell online. Each merchant runs their own independent store and acts
              as the controller of their customers' data; Makola processes data on the merchant's
              behalf as the platform operator.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Merchants are responsible for their own privacy notices to their customers and for
              complying with applicable data protection law in their jurisdiction. Makola provides
              the technical infrastructure and tooling.
            </p>
          </:section>

          <:section id="data-we-collect" title="Information we collect">
            <p class="text-[#5f6b7a] leading-relaxed">
              We collect information you provide directly, information generated through your use
              of the platform, and certain technical data. This includes:
            </p>
            <ul class="list-disc pl-5 text-[#5f6b7a] space-y-1">
              <li>Account details: name, email address, phone number, business name</li>
              <li>Store configuration: domain, branding, product catalogue, pricing</li>
              <li>
                Order and transaction metadata: order IDs, amounts, delivery addresses, fulfilment status
              </li>
              <li>Device and usage data: browser type, IP address, pages visited, time on page</li>
              <li>Cookies and similar technologies — see our Cookie Policy for details</li>
            </ul>
            <p class="text-[#5f6b7a] leading-relaxed">
              We do not collect sensitive personal data such as national ID numbers, biometric data,
              or health information unless you provide it voluntarily.
            </p>
          </:section>

          <:section id="how-we-use-it" title="How we use it">
            <p class="text-[#5f6b7a] leading-relaxed">
              We use the information we collect to operate and improve the Makola platform,
              process transactions, send order and account notifications (via email, SMS, and
              WhatsApp), provide customer support, detect and prevent fraud, and comply with
              legal obligations.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We may use aggregated, anonymised data to understand how merchants and customers
              use the platform and to improve our products. We will not sell your personal
              information to third parties.
            </p>
          </:section>

          <:section id="payments" title="Payment processing">
            <p class="text-[#5f6b7a] leading-relaxed">
              Payments on the Makola platform are processed by third-party payment providers
              including Paystack, Hubtel, and mobile-money operators (MTN MoMo, Telecel Cash,
              AirtelTigo). Payment data — including card details and mobile-money account numbers
              — is transmitted directly to and stored by these providers under their own security
              standards and privacy policies.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Makola does not store full card numbers, CVV codes, or mobile-money PINs on our
              servers at any time. We receive only the transaction reference, amount, status, and
              the masked identifier needed to display order history.
            </p>
          </:section>

          <:section id="sharing" title="Sharing & third parties">
            <p class="text-[#5f6b7a] leading-relaxed">
              We share your information only as necessary to operate the platform: with payment
              providers to process transactions, with SMS and WhatsApp gateway partners to deliver
              notifications, and with cloud infrastructure providers (hosting, storage, CDN) that
              process data on our behalf under data processing agreements.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We may disclose information where required by law or to protect the rights, property,
              or safety of Makola, our merchants, customers, or the public. We will notify you
              of any such disclosure where permitted by law.
            </p>
          </:section>

          <:section id="retention" title="Data retention">
            <p class="text-[#5f6b7a] leading-relaxed">
              We retain your account and transaction data for as long as your account is active
              and for a further period required by applicable law, tax regulations, or legitimate
              business purposes — typically seven years for financial records. Usage logs and
              analytics data are retained for up to twenty-four months.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              If you close your account, we will delete or anonymise your personal data within
              ninety days, except where retention is required by law.
            </p>
          </:section>

          <:section id="security" title="Security">
            <p class="text-[#5f6b7a] leading-relaxed">
              We implement industry-standard technical and organisational measures to protect
              your data, including encryption in transit (TLS) and at rest, access controls,
              and regular security reviews. Our team follows least-privilege principles and
              all access to production data is logged and audited.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              No system is completely secure. If you discover a security vulnerability, please
              report it to support@emakola.com and we will respond promptly.
            </p>
          </:section>

          <:section id="your-rights" title="Your rights">
            <p class="text-[#5f6b7a] leading-relaxed">
              Depending on your jurisdiction, you may have the right to:
            </p>
            <ul class="list-disc pl-5 text-[#5f6b7a] space-y-1">
              <li><strong>Access</strong> the personal data we hold about you</li>
              <li><strong>Correct</strong> inaccurate or incomplete data</li>
              <li>
                <strong>Delete</strong>
                your data (right to erasure), subject to legal retention requirements
              </li>
              <li><strong>Object</strong> to processing based on legitimate interests</li>
              <li><strong>Portability</strong> — receive your data in a machine-readable format</li>
              <li><strong>Withdraw consent</strong> at any time where processing is consent-based</li>
            </ul>
            <p class="text-[#5f6b7a] leading-relaxed">
              To exercise any of these rights, email us at support@emakola.com. We will respond
              within thirty days.
            </p>
          </:section>

          <:section id="children" title="Children">
            <p class="text-[#5f6b7a] leading-relaxed">
              Makola is not directed at children under the age of 18 and we do not knowingly
              collect personal data from minors. If you believe a child has provided us with
              personal information, please contact us and we will delete it promptly.
            </p>
          </:section>

          <:section id="international" title="International transfers">
            <p class="text-[#5f6b7a] leading-relaxed">
              Makola operates from Ghana and our primary infrastructure is hosted within the
              European Economic Area (EEA) or equivalent jurisdictions with adequate data
              protection laws. Where we transfer data internationally, we apply appropriate
              safeguards such as standard contractual clauses or equivalent mechanisms.
            </p>
          </:section>

          <:section id="changes" title="Changes to this policy">
            <p class="text-[#5f6b7a] leading-relaxed">
              We may update this Privacy Policy from time to time to reflect changes in our
              practices or applicable law. When we make material changes, we will update the
              "Last updated" date at the top of this page and, where appropriate, notify you
              by email or in-platform notification.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Continued use of the platform after the effective date of a revised policy
              constitutes your acceptance of the changes.
            </p>
          </:section>

          <:section id="contact" title="Contact us">
            <p class="text-[#5f6b7a] leading-relaxed">
              If you have questions about this Privacy Policy or how we handle your data,
              please contact our privacy team at <a
                href="mailto:support@emakola.com"
                class="text-[#d4a843] hover:underline"
              >
                support@emakola.com
              </a>.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We are committed to working with you to resolve any concerns. If you are
              unsatisfied with our response, you may have the right to lodge a complaint
              with your local data protection authority.
            </p>
          </:section>
        </.legal_layout>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
