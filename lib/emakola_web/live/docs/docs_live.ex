defmodule EmakolaWeb.Docs.DocsLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.LandingComponents, only: [landing_nav: 1, landing_footer: 1]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Documentation — Emakola",
       meta_description:
         "Build on Emakola — multi-tenant storefronts, mobile money payments, WhatsApp order alerts, and the merchant mobile API.",
       canonical_url: url(~p"/docs"),
       active_section: "getting-started",
       mobile_menu_open: false
     ), layout: false}
  end

  def handle_event("navigate", %{"section" => section}, socket) do
    {:noreply, assign(socket, active_section: section)}
  end

  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-[#0c1526] font-body antialiased">
      <.landing_nav mobile_menu_open={@mobile_menu_open} />

      <main class="pt-16">
        <.docs_hero />

        <section class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14 lg:py-20">
          <div class="flex gap-12">
            <%!-- Sticky side TOC --%>
            <aside class="hidden lg:block w-[210px] shrink-0">
              <nav class="sticky top-24 space-y-1">
                <p class="text-[10px] uppercase tracking-[0.2em] text-[#8896ab] font-semibold mb-4">
                  On this page
                </p>
                <.toc_link section="getting-started" label="Getting Started" active={@active_section} />
                <.toc_link section="multitenancy" label="Multi-Tenancy" active={@active_section} />
                <.toc_link section="payments" label="Payments" active={@active_section} />
                <.toc_link section="money" label="Money & Currency" active={@active_section} />
                <.toc_link section="notifications" label="Notifications" active={@active_section} />
                <.toc_link section="mobile-api" label="Mobile API" active={@active_section} />
                <.toc_link section="deployment" label="Deployment" active={@active_section} />
              </nav>
            </aside>

            <%!-- Main content --%>
            <div class="flex-1 min-w-0 pb-16">
              <%!-- ════════ Getting Started ════════ --%>
              <section id="getting-started" class="scroll-mt-24 mb-24">
                <.section_eyebrow>01 — Setup</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                  Getting Started
                </h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  Get Emakola running locally in a few minutes. You'll need <strong class="text-[#0c1526]">Elixir 1.18+</strong>, <strong class="text-[#0c1526]">Erlang OTP 27+</strong>, and <strong class="text-[#0c1526]">PostgreSQL 15+</strong>.
                </p>

                <div class="space-y-6">
                  <.step n="1" title="Clone and install dependencies">
                    <.code_block code="git clone git@github.com:your-org/emakola.git\ncd emakola\nmix deps.get" />
                  </.step>

                  <.step n="2" title="Configure secrets and set up the database">
                    <.code_block code="cp .env.example .env          # Paystack, S3, WhatsApp & SMS keys\nmix ecto.setup                # create, migrate, seed demo data" />
                  </.step>

                  <.step n="3" title="Start the server">
                    <.code_block code="mix phx.server\n\n# Visit http://localhost:4000\n# A demo store is seeded at /s/demo-store" />
                  </.step>
                </div>
              </section>

              <%!-- ════════ Multi-Tenancy ════════ --%>
              <section id="multitenancy" class="scroll-mt-24 mb-24">
                <.section_eyebrow>02 — Architecture</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                  Multi-Tenancy
                </h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  Every store is an isolated tenant. Emakola uses Ash attribute-based
                  multitenancy keyed on
                  <.inline_code>store_id</.inline_code>
                  — store data
                  never leaks across tenants.
                </p>

                <div class="space-y-8">
                  <.doc_block title="Tenant-scoped resources">
                    Every tenant-scoped resource declares its multitenancy strategy. Queries
                    must always carry a tenant.
                    <:code>
                      <.code_block code="defmodule Emakola.Catalog.Product do\n  use Ash.Resource,\n    domain: Emakola.Catalog,\n    data_layer: AshPostgres.DataLayer\n\n  multitenancy do\n    strategy :attribute\n    attribute :store_id\n  end\nend" />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Reading with a tenant">
                    Pass the store as the tenant on every read. Without it, the query raises
                    rather than silently returning another store's data.
                    <:code>
                      <.code_block code="Emakola.Catalog.Product\n|> Ash.Query.for_read(:read)\n|> Ash.read!(tenant: store.id)" />
                    </:code>
                  </.doc_block>
                </div>
              </section>

              <%!-- ════════ Payments ════════ --%>
              <section id="payments" class="scroll-mt-24 mb-24">
                <.section_eyebrow>03 — Commerce</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">Payments</h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  Mobile money first. Emakola routes payments through a
                  <.inline_code>Gateway</.inline_code>
                  behaviour with Paystack and Hubtel
                  implementations — covering MTN MoMo, Vodafone Cash, and AirtelTigo.
                </p>

                <div class="space-y-8">
                  <.doc_block title="The Gateway behaviour">
                    Every provider implements the same contract, so checkout code is
                    provider-agnostic.
                    <:code>
                      <.code_block code="defmodule Emakola.Payments.Gateway do\n  @callback initiate_payment(map()) :: {:ok, map()} | {:error, term()}\n  @callback verify_payment(String.t()) :: {:ok, map()} | {:error, term()}\n  @callback process_refund(String.t(), integer()) :: {:ok, map()} | {:error, term()}\nend" />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Initiating a payment">
                    Amounts are passed in minor units (see Money &amp; Currency). The gateway
                    returns an authorization URL or mobile-money prompt reference.
                    <:code>
                      <.code_block code={"Emakola.Payments.Gateways.Paystack.initiate_payment(%{\n  amount_pesewas: 50_000,\n  currency: \"GHS\",\n  email: customer.email,\n  reference: order.number\n})"} />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Webhooks">
                    Provider callbacks are verified and processed by an idempotent Oban
                    worker, which confirms the payment and advances the order.
                    <:code>
                      <.code_block code="# POST /webhooks/paystack\n# Signature verified, then handed to:\nEmakola.Workers.WebhookWorker\n\n# Order transitions to :paid once verify_payment/1 succeeds." />
                    </:code>
                  </.doc_block>
                </div>
              </section>

              <%!-- ════════ Money & Currency ════════ --%>
              <section id="money" class="scroll-mt-24 mb-24">
                <.section_eyebrow>04 — Commerce</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                  Money &amp; Currency
                </h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  All monetary amounts are stored as integers in minor units —
                  <strong class="text-[#0c1526]">pesewas</strong>
                  for GHS, <strong class="text-[#0c1526]">kobo</strong>
                  for NGN. Never use floats for money.
                </p>

                <div class="space-y-8">
                  <.doc_block title="Minor units">
                    Store the amount and currency code together; format only in the
                    presentation layer.
                    <:code>
                      <.code_block code={"# 1 GHS = 100 pesewas, 1 NGN = 100 kobo\n%{amount_pesewas: 50_000, currency: \"GHS\"}  # = GHS 500.00\n\nEmakola.Money.format(50_000, \"GHS\")\n# => \"GHS 500.00\""} />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Supported currencies">
                    GHS (Ghana Cedi) is the default for Ghana stores, with NGN for the
                    Nigeria expansion and USD for future international payments.
                    <:code>
                      <.code_block code="# GHS — Ghana Cedi   (default)\n# NGN — Nigerian Naira\n# USD — international (future)" />
                    </:code>
                  </.doc_block>
                </div>
              </section>

              <%!-- ════════ Notifications ════════ --%>
              <section id="notifications" class="scroll-mt-24 mb-24">
                <.section_eyebrow>05 — Engagement</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                  Notifications
                </h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  Merchants and customers get order updates over WhatsApp and SMS. Delivery
                  runs through idempotent Oban workers so a retry never double-sends.
                </p>

                <div class="space-y-8">
                  <.doc_block title="Sending an alert">
                    Enqueue a notification job; the worker picks the channel and provider.
                    <:code>
                      <.code_block code="%{order_id: order.id, channel: :whatsapp}\n|> Emakola.Workers.NotificationWorker.new()\n|> Oban.insert()" />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Provider configuration">
                    WhatsApp Business API and the SMS gateway are configured via environment
                    variables.
                    <:code>
                      <.code_block code="WHATSAPP_API_TOKEN=...\nWHATSAPP_PHONE_NUMBER_ID=...\nSMS_API_KEY=...\nSMS_SENDER_ID=Emakola" />
                    </:code>
                  </.doc_block>
                </div>
              </section>

              <%!-- ════════ Mobile API ════════ --%>
              <section id="mobile-api" class="scroll-mt-24 mb-24">
                <.section_eyebrow>06 — Integration</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">Mobile API</h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  A JSON:API surface (via <.inline_code>ash_json_api</.inline_code>) powers the
                  merchant mobile app. Bearer auth, per-store scoping, and an OpenAPI contract
                  are built in.
                </p>

                <div class="space-y-8">
                  <.doc_block title="Authentication">
                    Sign in for a 15-minute access token plus a 30-day rotating, single-use
                    refresh token.
                    <:code>
                      <.code_block code={"POST /api/v1/auth/sign_in\n{ \"email\": \"merchant@example.com\", \"password\": \"...\" }\n\n# => { \"access_token\": \"...\", \"refresh_token\": \"...\" }"} />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Per-store requests">
                    Every request carries the bearer token and an
                    <.inline_code>X-Store-ID</.inline_code>
                    header, validated against the
                    merchant's store memberships.
                    <:code>
                      <.code_block code="GET  /api/v1/stores              # the merchant's stores\nGET  /api/v1/orders              # list orders\nGET  /api/v1/orders/:id          # order detail\nPOST /api/v1/orders/:id/transition\nGET  /api/v1/open_api            # OpenAPI specification" />
                    </:code>
                  </.doc_block>
                </div>
              </section>

              <%!-- ════════ Deployment ════════ --%>
              <section id="deployment" class="scroll-mt-24 mb-24">
                <.section_eyebrow>07 — Ship it</.section_eyebrow>
                <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                  Deployment
                </h2>
                <p class="text-[#5f6b7a] text-lg leading-relaxed mb-8 max-w-2xl">
                  Emakola ships with a production
                  <.inline_code>Dockerfile</.inline_code>
                  and
                  Fly.io config. Deploy in a single command.
                </p>

                <div class="space-y-8">
                  <.doc_block title="Fly.io">
                    The fastest path to production.
                    <:code>
                      <.code_block code="fly launch --name emakola\nfly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)\nfly secrets set PAYSTACK_SECRET_KEY=sk_live_...\nfly deploy" />
                    </:code>
                  </.doc_block>

                  <.doc_block title="Environment variables">
                    All secrets are read from the environment at runtime.
                    <:code>
                      <.code_block code="DATABASE_URL=postgres://user:pass@host/db\nSECRET_KEY_BASE=super-secret-64-char-key\nPHX_HOST=emakola.com\n\nPAYSTACK_SECRET_KEY=sk_live_...\nHUBTEL_CLIENT_ID=...\nAWS_S3_BUCKET=emakola-uploads\nWHATSAPP_API_TOKEN=..." />
                    </:code>
                  </.doc_block>
                </div>
              </section>
            </div>
          </div>
        </section>
      </main>

      <.landing_footer />
    </div>
    """
  end

  # ── Hero ──────────────────────────────────────────────────────────────
  defp docs_hero(assigns) do
    ~H"""
    <section class="relative isolate overflow-hidden bg-[#0c1526] text-[#f1f5f9]">
      <div
        aria-hidden="true"
        class="absolute inset-0 -z-10"
        style="background:
          radial-gradient(54rem 26rem at 88% -20%, rgba(212,168,67,0.20), transparent 60%),
          radial-gradient(40rem 24rem at -4% 120%, rgba(181,83,46,0.14), transparent 55%);"
      >
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 lg:py-20">
        <span class="about-rise inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[#d4a843]/30 bg-[#d4a843]/10 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843]">
          <span class="w-1.5 h-1.5 rounded-full bg-[#d4a843] animate-pulse"></span> Documentation
        </span>
        <h1
          class="about-rise mt-6 text-4xl sm:text-5xl font-headline font-extrabold tracking-tight"
          style="animation-delay: 0.1s"
        >
          Build on Emakola
        </h1>
        <p
          class="about-rise mt-4 text-base lg:text-lg text-[#cbd5e1] max-w-2xl leading-relaxed"
          style="animation-delay: 0.2s"
        >
          Everything you need to launch a storefront — multi-tenant stores, mobile money
          payments, WhatsApp order alerts, and the merchant mobile API.
        </p>

        <div class="about-rise relative max-w-xl mt-8" style="animation-delay: 0.3s">
          <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-[#8896ab] text-lg">
            search
          </span>
          <input
            type="text"
            placeholder="Search documentation…"
            class="w-full rounded-xl border border-white/10 bg-white/5 pl-12 pr-4 py-3.5 text-sm text-[#f1f5f9] placeholder:text-[#8896ab] outline-none transition-all focus:border-[#d4a843]/50 focus:ring-4 focus:ring-[#d4a843]/15"
          />
        </div>
      </div>
    </section>
    """
  end

  # ── Content helpers ───────────────────────────────────────────────────
  slot :inner_block, required: true

  defp section_eyebrow(assigns) do
    ~H"""
    <p class="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.22em] text-[#d4a843] mb-4">
      <span class="h-px w-8 bg-[#d4a843]"></span> {render_slot(@inner_block)}
    </p>
    """
  end

  attr :n, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <div class="rounded-2xl border border-slate-200 bg-[#f8fafc] p-6">
      <div class="flex items-center gap-3 mb-4">
        <span class="w-7 h-7 rounded-lg bg-[#0c1526] flex items-center justify-center text-xs font-bold text-[#d4a843] font-mono">
          {@n}
        </span>
        <h3 class="text-base font-semibold font-headline">{@title}</h3>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true
  slot :code, required: true

  defp doc_block(assigns) do
    ~H"""
    <div>
      <h3 class="text-xl font-bold font-headline mb-3">{@title}</h3>
      <p class="text-[#5f6b7a] leading-relaxed mb-4 max-w-2xl">{render_slot(@inner_block)}</p>
      {render_slot(@code)}
    </div>
    """
  end

  slot :inner_block, required: true

  defp inline_code(assigns) do
    ~H"""
    <code class="text-[#0c1526] bg-[#d4a843]/15 rounded px-1.5 py-0.5 font-mono text-[0.85em]">
      {render_slot(@inner_block)}
    </code>
    """
  end

  defp toc_link(assigns) do
    ~H"""
    <a
      href={"#" <> @section}
      phx-click="navigate"
      phx-value-section={@section}
      class={"block py-1.5 pl-3 text-sm border-l-2 transition-colors " <>
        if(@active == @section,
          do: "text-[#0c1526] font-semibold border-[#d4a843] bg-[#d4a843]/10 rounded-r-lg",
          else: "text-[#5f6b7a] border-transparent hover:text-[#0c1526] hover:border-slate-300"
        )}
    >
      {@label}
    </a>
    """
  end

  defp code_block(assigns) do
    ~H"""
    <div class="bg-[#0d1117] rounded-xl p-6 overflow-x-auto ring-1 ring-white/5">
      <pre class="font-mono text-[13px] leading-relaxed"><code><%= format_code(@code) %></code></pre>
    </div>
    """
  end

  defp format_code(code) do
    code
    # Normalize literal "\n" (from plain HEEX attributes the formatter collapses)
    # into real line breaks so multi-line samples split correctly.
    |> String.replace("\\n", "\n")
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&colorize_line/1)
    |> Enum.intersperse({:safe, "\n"})
  end

  defp colorize_line(line) do
    escaped = escape(line)

    cond do
      String.starts_with?(String.trim(line), "#") ->
        {:safe, ~s[<span style="color:#8b949e">#{escaped}</span>]}

      String.starts_with?(String.trim(line), "$ ") ->
        {:safe, ~s[<span style="color:#c9d1d9">#{escaped}</span>]}

      has_keyword?(line) ->
        {:safe, ~s[<span style="color:#c9d1d9">#{colorize_keywords(escaped)}</span>]}

      String.contains?(line, "\"") ->
        {:safe, ~s[<span style="color:#c9d1d9">#{colorize_strings(escaped)}</span>]}

      true ->
        {:safe, ~s[<span style="color:#c9d1d9">#{escaped}</span>]}
    end
  end

  defp has_keyword?(line) do
    trimmed = String.trim(line)

    Enum.any?(
      ~w(defmodule def do end use config plug if fn when),
      fn kw ->
        String.starts_with?(trimmed, kw <> " ") or String.starts_with?(trimmed, kw <> "\n") or
          trimmed == kw or String.contains?(line, " " <> kw <> " ")
      end
    )
  end

  defp colorize_keywords(escaped) do
    ~w(defmodule def do end use config plug import require alias if else fn when case cond with for)
    |> Enum.reduce(escaped, fn kw, acc ->
      String.replace(acc, kw, ~s[<span style="color:#ff7b72">#{kw}</span>])
    end)
    |> colorize_strings()
  end

  defp colorize_strings(escaped) do
    Regex.replace(~r/&quot;([^&]*)&quot;/, escaped, fn _full, inner ->
      ~s[<span style="color:#a5d6ff">&quot;#{inner}&quot;</span>]
    end)
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
