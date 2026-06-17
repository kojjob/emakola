defmodule EmakolaWeb.Company.TermsLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]
  import EmakolaWeb.CompanyComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Terms of Service — Emakola",
       meta_description: "The terms governing use of the Emakola commerce platform.",
       og_image: url(~p"/images/og-image.png"),
       canonical_url: url(~p"/terms"),
       mobile_menu_open: false
     ), layout: false}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />
      <main>
        <.legal_layout
          title="Terms of Service"
          subtitle="The rules and agreements that govern your use of Emakola."
          last_updated="June 15, 2026"
        >
          <:section id="acceptance" title="Acceptance of terms">
            <p class="text-[#5f6b7a] leading-relaxed">
              By creating an account, accessing, or using the Emakola platform (the "Service"),
              you agree to be bound by these Terms of Service ("Terms"). If you do not agree,
              you may not use the Service. These Terms form a binding agreement between you
              and Emakola.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We may update these Terms from time to time. Continued use of the Service after
              changes are posted constitutes acceptance of the revised Terms. Material changes
              will be communicated by email or in-platform notice.
            </p>
          </:section>

          <:section id="definitions" title="Definitions">
            <p class="text-[#5f6b7a] leading-relaxed">
              "Emakola", "we", "us", or "our" refers to the Emakola platform operator.
              "Merchant" means any business or individual who registers a store on Emakola.
              "Customer" means a person who purchases from a Merchant's store. "Platform" means
              the Emakola software, APIs, websites, and related services.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              "Content" means any text, images, product listings, or other material uploaded
              to the Platform by a Merchant. "Transaction" means a purchase, refund, or other
              financial exchange facilitated through the Platform.
            </p>
          </:section>

          <:section id="accounts" title="Eligibility & accounts">
            <p class="text-[#5f6b7a] leading-relaxed">
              You must be at least 18 years of age and legally capable of entering a binding
              contract to use Emakola as a Merchant. By registering, you represent that all
              information you provide is accurate, complete, and current.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              You are responsible for maintaining the confidentiality of your account credentials
              and for all activity that occurs under your account. Notify us immediately at
              support@emakola.com if you suspect unauthorised access.
            </p>
          </:section>

          <:section id="merchant-obligations" title="Merchant obligations">
            <p class="text-[#5f6b7a] leading-relaxed">
              As a Merchant, you agree to: list only products and services you are legally
              permitted to sell; accurately describe your products, prices, and fulfilment
              timelines; comply with all applicable laws in your jurisdiction (including consumer
              protection, tax, and import/export regulations); and honour orders placed through
              your store in a timely manner.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Merchants are solely responsible for the accuracy of their Content, the quality
              of their products, and the resolution of disputes with Customers. Emakola may
              act as an intermediary at its discretion but is not obligated to do so.
            </p>
          </:section>

          <:section id="acceptable-use" title="Acceptable use & prohibited goods">
            <p class="text-[#5f6b7a] leading-relaxed">
              You may not use the Platform to sell counterfeit goods, regulated firearms or
              weapons, illegal drugs or controlled substances, adult content in jurisdictions
              where prohibited, or any goods or services that violate applicable law. Emakola
              reserves the right to determine, at its sole discretion, whether a product or
              service is prohibited.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              You may not attempt to gain unauthorised access to the Platform, engage in
              scraping or automated data collection, transmit malware, or interfere with the
              operation of the Service or other merchants' stores.
            </p>
          </:section>

          <:section id="payments-fees" title="Payments, fees & payouts">
            <p class="text-[#5f6b7a] leading-relaxed">
              Emakola charges platform fees as set out in your subscription plan. Payment
              processing fees are charged by our payment partners (Paystack, Hubtel, mobile-money
              operators) and passed through at cost unless otherwise stated. All fees are
              exclusive of applicable taxes.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Payouts to Merchants are made according to the payout schedule associated with
              your payment provider. Emakola may withhold payouts in cases of suspected fraud,
              chargebacks, or where required by law. Fees are non-refundable except where
              required by law.
            </p>
          </:section>

          <:section id="orders" title="Orders & fulfillment">
            <p class="text-[#5f6b7a] leading-relaxed">
              Emakola facilitates the sale between a Merchant and a Customer. The Merchant is
              the seller of record for every transaction; Emakola is not a party to the contract
              of sale and does not hold title to any goods. Merchants are responsible for
              fulfilling orders, managing returns, and handling Customer complaints.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Customers contract directly with the Merchant whose store they purchase from.
              Emakola provides the technology platform and payment infrastructure but does not
              guarantee the quality, safety, or delivery of any product or service sold by a
              Merchant.
            </p>
          </:section>

          <:section id="intellectual-property" title="Intellectual property">
            <p class="text-[#5f6b7a] leading-relaxed">
              Emakola and its licensors retain all intellectual property rights in the Platform,
              including software, design, trademarks, and documentation. These Terms do not
              grant you any rights in Emakola's intellectual property except as expressly set
              out herein.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              By uploading Content to the Platform, you grant Emakola a non-exclusive,
              royalty-free licence to host, display, and transmit that Content solely for the
              purpose of operating the Service. You retain all ownership rights in your Content.
            </p>
          </:section>

          <:section id="third-party" title="Third-party services">
            <p class="text-[#5f6b7a] leading-relaxed">
              The Platform integrates with third-party services including payment gateways,
              SMS and WhatsApp providers, and shipping partners. Your use of those services is
              governed by their respective terms and privacy policies. Emakola is not responsible
              for the availability or conduct of third-party services.
            </p>
          </:section>

          <:section id="disclaimers" title="Disclaimers">
            <p class="text-[#5f6b7a] leading-relaxed">
              The Platform is provided "as is" and "as available" without warranty of any kind,
              express or implied. We do not warrant that the Service will be uninterrupted,
              error-free, or free from viruses or other harmful components. We disclaim all
              implied warranties of merchantability, fitness for a particular purpose, and
              non-infringement to the maximum extent permitted by law.
            </p>
          </:section>

          <:section id="liability" title="Limitation of liability">
            <p class="text-[#5f6b7a] leading-relaxed">
              To the maximum extent permitted by applicable law, Emakola's total liability to
              you for any claim arising under or in connection with these Terms shall not exceed
              the fees you paid to Emakola in the three months preceding the claim.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              In no event shall Emakola be liable for any indirect, incidental, special,
              consequential, or punitive damages, including loss of profits or revenue, loss of
              data, or business interruption, even if advised of the possibility of such damages.
            </p>
          </:section>

          <:section id="indemnification" title="Indemnification">
            <p class="text-[#5f6b7a] leading-relaxed">
              You agree to indemnify and hold harmless Emakola, its officers, directors,
              employees, and agents from any claims, losses, damages, and expenses (including
              reasonable legal fees) arising out of your use of the Platform, your Content,
              your products or services, or your violation of these Terms or applicable law.
            </p>
          </:section>

          <:section id="termination" title="Suspension & termination">
            <p class="text-[#5f6b7a] leading-relaxed">
              Emakola may suspend or terminate your account and access to the Service at any
              time, with or without notice, for conduct that we believe violates these Terms,
              is harmful to other users, or is otherwise unacceptable. You may close your
              account at any time from your account settings.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              Upon termination, your right to access the Platform ceases immediately. We will
              retain your data in accordance with our Privacy Policy and applicable law.
              Provisions of these Terms that by their nature should survive termination will
              do so.
            </p>
          </:section>

          <:section id="governing-law" title="Governing law">
            <p class="text-[#5f6b7a] leading-relaxed">
              These Terms are governed by and construed in accordance with the laws of the
              Republic of Ghana. Any disputes arising under these Terms shall be subject to the
              exclusive jurisdiction of the courts of Ghana, except where mandatory local law
              requires otherwise for merchants operating in other markets.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              As Emakola expands to other markets (including Nigeria), merchants in those
              jurisdictions may also be subject to additional local terms required by applicable
              law. Such terms will be presented at registration or when entering a new market.
            </p>
          </:section>

          <:section id="changes" title="Changes to these terms">
            <p class="text-[#5f6b7a] leading-relaxed">
              We reserve the right to modify these Terms at any time. When we make material
              changes, we will update the "Last updated" date and notify you by email or
              in-platform message at least 14 days before the changes take effect.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              If you do not agree to the revised Terms, you must stop using the Platform before
              the effective date of the changes. Continued use after that date constitutes
              acceptance.
            </p>
          </:section>

          <:section id="contact" title="Contact us">
            <p class="text-[#5f6b7a] leading-relaxed">
              For questions about these Terms, please contact us at <a
                href="mailto:support@emakola.com"
                class="text-[#d4a843] hover:underline"
              >
                support@emakola.com
              </a>.
            </p>
            <p class="text-[#5f6b7a] leading-relaxed">
              We aim to respond to all legal queries within five business days.
            </p>
          </:section>
        </.legal_layout>
      </main>
      <.landing_footer />
    </div>
    """
  end
end
