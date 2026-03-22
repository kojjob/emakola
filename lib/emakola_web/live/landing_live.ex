defmodule EmakolaWeb.LandingLive do
  use EmakolaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Emakola — Ship Your SaaS in Days, Not Months",
       meta_description:
         "The production-ready Phoenix boilerplate with built-in AI agents, Stripe billing, team management, and beautiful dark/light UI. Ship your SaaS in days, not months.",
       og_title: "Emakola — Ship Your SaaS in Days, Not Months",
       og_description:
         "Production-ready Phoenix boilerplate with AI agents, Stripe billing, team management, and dark/light UI.",
       og_image: "/images/og-founderpad.png",
       twitter_card: "summary_large_image"
     ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div
      id="landing-scroll"
      phx-hook="ScrollReveal"
      class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary"
    >
      <%!-- ═══════════════════════════════════════════════════════
           NAVIGATION — Sticky glass nav bar
           ═══════════════════════════════════════════════════════ --%>
      <style>
        #main-nav.scrolled {
          background: rgba(255,255,255,0.95);
          backdrop-filter: blur(12px);
          border-bottom: 1px solid rgba(0,0,0,0.06);
          box-shadow: 0 1px 3px rgba(0,0,0,0.04);
        }
        :root[data-theme="dark"] #main-nav.scrolled,
        .dark #main-nav.scrolled {
          background: rgba(30,30,30,0.95);
          border-bottom: 1px solid rgba(255,255,255,0.06);
          box-shadow: 0 1px 3px rgba(0,0,0,0.2);
        }
      </style>
      <nav
        id="main-nav"
        phx-hook="ScrollGlass"
        class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md transition-all duration-300"
      >
        <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
          <%!-- Logo --%>
          <a href="/" class="flex items-center gap-2.5">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
            </div>
            <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">
              Emakola
            </span>
          </a>

          <%!-- Desktop nav links --%>
          <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
            <a href="#features" class="hover:text-on-surface transition-colors">Features</a>
            <a href="#pricing" class="hover:text-on-surface transition-colors">Pricing</a>
            <a
              href="/docs"
              class="hover:text-on-surface transition-colors"
            >
              Docs
            </a>
            <a href="/auth/login" class="hover:text-on-surface transition-colors">Login</a>
          </div>

          <%!-- Right side: CTA + Theme toggle --%>
          <div class="flex items-center gap-3">
            <a
              href="/auth/register"
              class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
            >
              Get Started
            </a>
            <button
              id="theme-toggle-landing"
              phx-hook="ThemeToggle"
              class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50"
            >
              <span class="material-symbols-outlined text-xl">dark_mode</span>
            </button>
          </div>
        </div>
      </nav>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 1: HERO — Full viewport, commanding presence
           ═══════════════════════════════════════════════════════ --%>
      <section class="relative min-h-screen flex items-center pt-24 pb-16 overflow-hidden">
        <%!-- Background glows --%>
        <div class="absolute top-1/4 left-1/4 w-[600px] h-[600px] bg-primary/5 rounded-full blur-[120px] pointer-events-none">
        </div>
        <div class="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-secondary/5 rounded-full blur-[100px] pointer-events-none">
        </div>

        <div class="relative w-full grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-0 items-center">
          <%!-- Left Column: Copy --%>
          <div
            data-reveal="left"
            class="space-y-8 pl-6 md:pl-12 lg:pl-[max(2rem,calc((100vw-1280px)/2+2rem))]"
          >
            <%!-- Announcement bar --%>
            <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-surface-container text-xs font-medium text-on-surface-variant">
              <span class="text-secondary">&#x1F680;</span>
              <span>v1.0 — Now with multi-provider AI agents</span>
              <span class="material-symbols-outlined text-sm text-primary">arrow_forward</span>
            </div>

            <%!-- Headline --%>
            <h1 class="text-5xl sm:text-6xl lg:text-7xl font-extrabold font-headline tracking-tight leading-[1.05]">
              Ship Your SaaS <br />
              <span class="text-primary">In Days, Not Months.</span>
            </h1>

            <%!-- Subheadline --%>
            <p class="text-lg sm:text-xl text-on-surface-variant max-w-xl leading-relaxed">
              The production-ready Phoenix boilerplate with built-in AI agents, Stripe billing, team management, and beautiful dark/light UI.
            </p>

            <%!-- CTA Buttons --%>
            <div class="flex flex-col sm:flex-row items-start gap-4">
              <a
                href="/auth/register"
                class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95 editorial-shadow"
              >
                <span>Get Started Free</span>
                <span class="material-symbols-outlined text-lg">arrow_forward</span>
              </a>
              <a
                href="https://github.com/kojjob/founder-pad"
                target="_blank"
                class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold text-on-surface bg-surface-container hover:bg-surface-container-high transition-colors"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12Z" />
                </svg>
                <span>View on GitHub</span>
              </a>
            </div>

            <%!-- Social proof --%>
            <div class="flex flex-col sm:flex-row items-start gap-4 text-sm text-on-surface-variant">
              <div class="flex -space-x-2">
                <div class="w-8 h-8 rounded-full bg-primary-container flex items-center justify-center text-[10px] font-bold text-on-primary-container ring-2 ring-background">
                  JD
                </div>
                <div class="w-8 h-8 rounded-full bg-secondary-container flex items-center justify-center text-[10px] font-bold text-on-secondary-container ring-2 ring-background">
                  SC
                </div>
                <div class="w-8 h-8 rounded-full bg-tertiary-container flex items-center justify-center text-[10px] font-bold text-on-tertiary ring-2 ring-background">
                  AL
                </div>
                <div class="w-8 h-8 rounded-full bg-primary-fixed-dim flex items-center justify-center text-[10px] font-bold text-on-primary-fixed ring-2 ring-background">
                  MR
                </div>
                <div class="w-8 h-8 rounded-full bg-surface-container-highest flex items-center justify-center text-[10px] font-bold text-on-surface ring-2 ring-background">
                  +
                </div>
              </div>
              <div class="space-y-1">
                <span>Trusted by <strong class="text-on-surface">500+</strong> founders</span>
                <div class="flex items-center gap-0.5 text-secondary">
                  <span
                    class="material-symbols-outlined text-sm"
                    style="font-variation-settings: 'FILL' 1"
                  >
                    star
                  </span>
                  <span
                    class="material-symbols-outlined text-sm"
                    style="font-variation-settings: 'FILL' 1"
                  >
                    star
                  </span>
                  <span
                    class="material-symbols-outlined text-sm"
                    style="font-variation-settings: 'FILL' 1"
                  >
                    star
                  </span>
                  <span
                    class="material-symbols-outlined text-sm"
                    style="font-variation-settings: 'FILL' 1"
                  >
                    star
                  </span>
                  <span
                    class="material-symbols-outlined text-sm"
                    style="font-variation-settings: 'FILL' 1"
                  >
                    star_half
                  </span>
                  <span class="text-on-surface-variant text-xs ml-1">4.8/5</span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Right Column: Dashboard Screenshot — bleeds to right edge --%>
          <div data-reveal="right" class="relative lg:pl-8">
            <div class="rounded-l-2xl lg:rounded-r-none overflow-hidden editorial-shadow ring-1 ring-outline-variant/10 ring-r-0">
              <img
                src="/images/dashboard-preview.png"
                alt="Emakola Dashboard — AI agent orchestration, billing metrics, and team activity in the Midnight Architect dark theme"
                class="w-full h-auto"
                width="1280"
                height="1024"
                loading="eager"
              />
            </div>
            <%!-- Glow under image --%>
            <div class="absolute -bottom-6 left-1/2 -translate-x-1/2 w-3/4 h-12 bg-primary/15 blur-[50px] rounded-full pointer-events-none">
            </div>
            <%!-- Floating badges --%>
            <div class="absolute -bottom-4 left-4 bg-surface-container-lowest glass-effect rounded-xl px-4 py-2.5 editorial-shadow flex items-center gap-2 z-10">
              <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span class="text-xs font-mono text-on-surface">123 tests passing</span>
            </div>
            <div class="absolute -top-4 right-4 lg:right-8 bg-surface-container-lowest glass-effect rounded-xl px-4 py-2.5 editorial-shadow flex items-center gap-2 z-10">
              <span class="material-symbols-outlined text-primary text-sm">bolt</span>
              <span class="text-xs font-mono text-on-surface">8 Ash domains</span>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 2: LOGOS BAR — Built with trust signals
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-16 px-6">
        <div class="max-w-5xl mx-auto text-center">
          <p class="text-xs uppercase tracking-[0.2em] text-on-surface-variant/50 font-medium mb-8">
            Built with
          </p>
          <div class="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 text-on-surface-variant/40 font-mono text-sm font-medium">
            <span>Phoenix</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Elixir</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Ash Framework</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Stripe</span>
            <span class="text-outline-variant/30">&bull;</span>
            <span>Tailwind CSS</span>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 3: FEATURES GRID — Asymmetric bento layout
           ═══════════════════════════════════════════════════════ --%>
      <section id="features" class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div data-reveal class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Features</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">
              Everything you need to ship
            </h2>
            <p class="mt-4 text-lg text-on-surface-variant max-w-2xl mx-auto">
              Stop wiring boilerplate. Start building your product from day one.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            <%!-- Feature 1: AI Agents — Large card --%>
            <div
              data-reveal
              class="lg:col-span-2 bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01] group"
            >
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">smart_toy</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">AI Agent Orchestration</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Multi-provider support for Claude and GPT-4o with real-time streaming, tool calls, and conversation history. Built on a composable agent framework that scales.
              </p>
              <div class="mt-5 flex flex-wrap gap-2">
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Streaming
                </span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Tool Calls
                </span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Multi-Provider
                </span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Conversation Memory
                </span>
              </div>
            </div>

            <%!-- Feature 2: Stripe Billing --%>
            <div
              data-reveal
              class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]"
            >
              <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-secondary text-2xl">payments</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Stripe Billing</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Plans, subscriptions, usage metering, and webhook processing — all pre-wired and production-tested.
              </p>
            </div>

            <%!-- Feature 3: Team Management --%>
            <div
              data-reveal
              class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]"
            >
              <div class="w-12 h-12 rounded-xl bg-tertiary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-tertiary text-2xl">group</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Team Management</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Roles, invitations, and org-scoped tenancy out of the box. Invite teammates and manage permissions seamlessly.
              </p>
            </div>

            <%!-- Feature 4: Dark & Light Mode — Large card --%>
            <div
              data-reveal
              class="lg:col-span-2 bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]"
            >
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">dark_mode</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Dark &amp; Light Mode</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Stitch-designed theming with a polished theme toggle, system preference detection, and the Indigo Slate Protocol design system built on tonal layering.
              </p>
              <div class="mt-5 flex flex-wrap gap-2">
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  System Preference
                </span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Tonal Surfaces
                </span>
                <span class="text-xs px-2.5 py-1 rounded-md bg-surface-container-high text-on-surface-variant font-medium">
                  Design Tokens
                </span>
              </div>
            </div>

            <%!-- Feature 5: API Layer --%>
            <div
              data-reveal
              class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]"
            >
              <div class="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-secondary text-2xl">api</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">API Layer</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Auto-derived REST and GraphQL endpoints from Ash resources. Define once, expose everywhere.
              </p>
            </div>

            <%!-- Feature 6: Production Ready --%>
            <div
              data-reveal
              class="bg-surface-container rounded-xl p-8 transition-transform hover:scale-[1.01]"
            >
              <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center mb-5">
                <span class="material-symbols-outlined text-primary text-2xl">rocket_launch</span>
              </div>
              <h3 class="text-xl font-bold font-headline mb-2">Production Ready</h3>
              <p class="text-on-surface-variant leading-relaxed">
                Docker, Fly.io config, CI/CD pipelines, audit logs, and rate limiting — deploy with confidence from day one.
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 4: METRICS — Social proof numbers
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-5xl mx-auto">
          <div data-reveal class="grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">8</p>
              <p class="text-sm text-on-surface-variant font-medium">Ash Domains</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">123</p>
              <p class="text-sm text-on-surface-variant font-medium">Tests Passing</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">19+</p>
              <p class="text-sm text-on-surface-variant font-medium">Database Tables</p>
            </div>
            <div class="space-y-2">
              <p class="text-5xl font-mono font-bold text-on-surface">12</p>
              <p class="text-sm text-on-surface-variant font-medium">LiveView Screens</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 5: CODE PREVIEW — Developer experience
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-3xl mx-auto">
          <div data-reveal class="text-center mb-12">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">
              Developer Experience
            </p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">
              Three commands. Ship it.
            </h2>
          </div>

          <div
            data-reveal="scale"
            class="bg-surface-container rounded-xl p-6 sm:p-8 editorial-shadow ring-1 ring-outline-variant/10"
          >
            <div class="flex items-center gap-2 mb-5">
              <div class="w-3 h-3 rounded-full bg-error/60"></div>
              <div class="w-3 h-3 rounded-full bg-secondary/60"></div>
              <div class="w-3 h-3 rounded-full bg-primary/40"></div>
              <span class="ml-3 text-xs text-on-surface-variant/50 font-mono">terminal</span>
            </div>
            <pre class="font-mono text-sm leading-relaxed overflow-x-auto"><code>{"$ mix phx.new my_app          # scaffold\n$ mix emakola.setup       # configure everything\n$ mix phx.server              # ship it"}</code></pre>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 6: PRICING — 4 tiers
           ═══════════════════════════════════════════════════════ --%>
      <section id="pricing" class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div data-reveal class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">Pricing</p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">
              Simple, transparent pricing
            </h2>
            <p class="mt-4 text-lg text-on-surface-variant max-w-2xl mx-auto">
              Start free. Scale when you're ready.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            <%!-- Free tier --%>
            <div
              data-reveal="scale"
              class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]"
            >
              <h3 class="text-lg font-bold font-headline">Free</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$0</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1 AI Agent
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1,000 API calls/mo
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>1 Team member
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Community support
                </li>
              </ul>
              <a
                href="/auth/register"
                class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors"
              >
                Get Started
              </a>
            </div>

            <%!-- Starter tier --%>
            <div
              data-reveal="scale"
              class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]"
            >
              <h3 class="text-lg font-bold font-headline">Starter</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$29</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>5 AI Agents
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>10,000 API calls/mo
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>5 Team members
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Email support
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Custom branding
                </li>
              </ul>
              <a
                href="/auth/register"
                class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors"
              >
                Start Free Trial
              </a>
            </div>

            <%!-- Pro tier — Highlighted --%>
            <div
              data-reveal="scale"
              class="relative bg-surface-container rounded-xl p-8 flex flex-col ring-2 ring-primary transition-transform hover:scale-[1.01]"
            >
              <div class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-0.5 rounded-full primary-gradient text-xs font-bold">
                Most Popular
              </div>
              <h3 class="text-lg font-bold font-headline">Pro</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$79</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited AI Agents
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>100,000 API calls/mo
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited Team members
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Priority support
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Advanced analytics
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>API access
                </li>
              </ul>
              <a
                href="/auth/register"
                class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
              >
                Start Free Trial
              </a>
            </div>

            <%!-- Enterprise tier --%>
            <div
              data-reveal="scale"
              class="bg-surface-container rounded-xl p-8 flex flex-col transition-transform hover:scale-[1.01]"
            >
              <h3 class="text-lg font-bold font-headline">Enterprise</h3>
              <div class="mt-4 mb-6">
                <span class="text-4xl font-mono font-bold text-on-surface">$199</span>
                <span class="text-on-surface-variant text-sm">/month</span>
              </div>
              <ul class="space-y-3 text-sm text-on-surface-variant flex-1">
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Everything in Pro
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Unlimited API calls
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>SSO &amp; SAML
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Dedicated support
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>Custom integrations
                </li>
                <li class="flex items-start gap-2">
                  <span class="material-symbols-outlined text-primary text-base mt-0.5">check</span>SLA guarantee
                </li>
              </ul>
              <a
                href="/auth/register"
                class="mt-8 inline-flex items-center justify-center px-6 py-3 rounded-xl text-sm font-semibold border border-outline-variant/30 text-on-surface hover:bg-surface-container-high transition-colors"
              >
                Contact Sales
              </a>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 7: TESTIMONIALS — 3 editorial quotes
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-7xl mx-auto">
          <div data-reveal class="text-center mb-16">
            <p class="text-xs uppercase tracking-[0.2em] text-primary font-semibold mb-3">
              Testimonials
            </p>
            <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">
              Loved by founders
            </h2>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            <div data-reveal class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "Emakola saved us 3 months of setup work. The AI agent framework alone was worth it — we had multi-provider streaming running in under an hour."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-primary-container flex items-center justify-center text-xs font-bold text-on-primary-container">
                  JK
                </div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">James Kowalski</p>
                  <p class="text-xs text-on-surface-variant">CTO, DataSync AI</p>
                </div>
              </div>
            </div>

            <div data-reveal class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "The Stripe integration is flawless. Subscriptions, usage metering, webhooks — everything just works. We launched our billing on day two."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-secondary-container flex items-center justify-center text-xs font-bold text-on-secondary-container">
                  SP
                </div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">Sarah Park</p>
                  <p class="text-xs text-on-surface-variant">Founder, InvoiceFlow</p>
                </div>
              </div>
            </div>

            <div data-reveal class="bg-surface-container rounded-xl p-8 editorial-shadow">
              <div class="flex items-center gap-1 mb-5 text-secondary">
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
                <span
                  class="material-symbols-outlined text-sm"
                  style="font-variation-settings: 'FILL' 1"
                >
                  star
                </span>
              </div>
              <blockquote class="text-on-surface leading-relaxed mb-6">
                "Best dark mode I've ever seen in a boilerplate. The design system is incredibly polished — our designers were impressed from the first screenshot."
              </blockquote>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-tertiary-container flex items-center justify-center text-xs font-bold text-on-tertiary">
                  ML
                </div>
                <div>
                  <p class="text-sm font-semibold text-on-surface">Marcus Lee</p>
                  <p class="text-xs text-on-surface-variant">CEO, NightOwl Labs</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 8: CTA — Final conversion push
           ═══════════════════════════════════════════════════════ --%>
      <section class="py-24 px-6">
        <div class="max-w-4xl mx-auto text-center">
          <div
            data-reveal="scale"
            class="bg-surface-container rounded-2xl p-12 sm:p-16 relative overflow-hidden"
          >
            <%!-- Background glow --%>
            <div class="absolute top-0 right-0 w-80 h-80 bg-primary/5 rounded-full blur-[100px] pointer-events-none">
            </div>
            <div class="absolute bottom-0 left-0 w-60 h-60 bg-secondary/5 rounded-full blur-[80px] pointer-events-none">
            </div>

            <div class="relative">
              <h2 class="text-4xl md:text-5xl font-extrabold font-headline tracking-tight">
                Ready to ship your SaaS?
              </h2>
              <p class="mt-4 text-lg text-on-surface-variant">Get started in under 5 minutes.</p>
              <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
                <a
                  href="/auth/register"
                  class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl text-base font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95 editorial-shadow"
                >
                  <span>Get Started Free</span>
                  <span class="material-symbols-outlined text-lg">arrow_forward</span>
                </a>
              </div>
              <p class="mt-4 text-sm text-on-surface-variant/60">No credit card required</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- ═══════════════════════════════════════════════════════
           SECTION 9: FOOTER
           ═══════════════════════════════════════════════════════ --%>
      <.public_footer />
    </div>
    """
  end
end
