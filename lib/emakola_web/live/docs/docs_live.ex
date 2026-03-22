defmodule EmakolaWeb.Docs.DocsLive do
  use EmakolaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Documentation -- Emakola",
       active_section: "getting-started"
     ), layout: false}
  end

  def handle_event("navigate", %{"section" => section}, socket) do
    {:noreply, assign(socket, active_section: section)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-background text-on-surface font-body selection:bg-primary/30 selection:text-primary">
      <.docs_nav active="docs" />

      <div class="pt-20 max-w-7xl mx-auto px-6">
        <div class="flex gap-12">
          <%!-- Sticky side TOC --%>
          <aside class="hidden lg:block w-[200px] shrink-0">
            <nav class="sticky top-24 space-y-1">
              <p class="text-[10px] uppercase tracking-[0.2em] text-on-surface-variant/50 font-semibold mb-4">
                On this page
              </p>
              <.toc_link section="getting-started" label="Getting Started" active={@active_section} />
              <.toc_link section="authentication" label="Authentication" active={@active_section} />
              <.toc_link section="ai-agents" label="AI Agents" active={@active_section} />
              <.toc_link section="billing" label="Billing" active={@active_section} />
              <.toc_link section="api" label="API" active={@active_section} />
              <.toc_link section="deployment" label="Deployment" active={@active_section} />
              <.toc_link section="configuration" label="Configuration" active={@active_section} />
            </nav>
          </aside>

          <%!-- Main content --%>
          <main class="flex-1 min-w-0 pb-32">
            <%!-- Search bar --%>
            <div class="mb-16">
              <div class="relative max-w-xl">
                <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant/40 text-lg">
                  search
                </span>
                <input
                  type="text"
                  placeholder="Search documentation..."
                  class="w-full bg-surface-container rounded-xl pl-12 pr-4 py-3.5 text-sm focus:ring-2 focus:ring-primary/30 text-on-surface placeholder:text-on-surface-variant/40 outline-none"
                />
              </div>
            </div>

            <%!-- ════════ Getting Started ════════ --%>
            <section id="getting-started" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                Getting Started
              </h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Get Emakola running locally in three simple steps. You will have a fully
                functional SaaS boilerplate with AI agents, billing, and auth in under five minutes.
              </p>

              <div class="space-y-6">
                <div class="bg-surface-container rounded-xl p-6">
                  <div class="flex items-center gap-3 mb-4">
                    <span class="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center text-xs font-bold text-primary font-mono">
                      1
                    </span>
                    <h3 class="text-base font-semibold font-headline">
                      Clone and install dependencies
                    </h3>
                  </div>
                  <.code_block code="git clone https://github.com/founderpad/founderpad.git\ncd founderpad\nmix deps.get && mix deps.compile" />
                </div>

                <div class="bg-surface-container rounded-xl p-6">
                  <div class="flex items-center gap-3 mb-4">
                    <span class="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center text-xs font-bold text-primary font-mono">
                      2
                    </span>
                    <h3 class="text-base font-semibold font-headline">
                      Setup database and environment
                    </h3>
                  </div>
                  <.code_block code="cp .env.example .env            # configure API keys\nmix ecto.setup                  # create & migrate DB\nmix run priv/repo/seeds.exs     # seed demo data" />
                </div>

                <div class="bg-surface-container rounded-xl p-6">
                  <div class="flex items-center gap-3 mb-4">
                    <span class="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center text-xs font-bold text-primary font-mono">
                      3
                    </span>
                    <h3 class="text-base font-semibold font-headline">Start the server</h3>
                  </div>
                  <.code_block code="mix phx.server\n\n# Visit http://localhost:4000\n# Login with demo@founderpad.io / password123" />
                </div>
              </div>
            </section>

            <%!-- ════════ Authentication ════════ --%>
            <section id="authentication" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">
                Authentication
              </h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Emakola ships with AshAuthentication supporting multiple strategies
                out of the box. Password, magic link, and OAuth2 are all pre-configured.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Password Authentication</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Secure password-based auth with bcrypt hashing, configurable password
                    policies, and built-in reset flows via email.
                  </p>
                  <.code_block code="defmodule Emakola.Accounts.User do\n  use Ash.Resource,\n    extensions: [AshAuthentication]\n\n  authentication do\n    strategies do\n      password :password do\n        identity_field :email\n        sign_in_tokens_enabled? true\n        resettable do\n          sender Emakola.Accounts.Senders.SendResetEmail\n        end\n      end\n    end\n  end\nend" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Magic Link</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Passwordless authentication via email. Users receive a secure, time-limited
                    link that signs them in instantly.
                  </p>
                  <.code_block code="authentication do\n  strategies do\n    magic_link do\n      identity_field :email\n      sender Emakola.Accounts.Senders.SendMagicLink\n    end\n  end\nend" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">OAuth2</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Ready for Google, GitHub, and any OAuth2 provider. Configure your
                    client credentials and callback URLs in the environment.
                  </p>
                  <.code_block code={"# config/runtime.exs\nconfig :emakola, :oauth,\n  google: [\n    client_id: System.get_env(\"GOOGLE_CLIENT_ID\"),\n    client_secret: System.get_env(\"GOOGLE_CLIENT_SECRET\"),\n    redirect_uri: \"https://yourapp.com/auth/google/callback\"\n  ]"} />
                </div>
              </div>
            </section>

            <%!-- ════════ AI Agents ════════ --%>
            <section id="ai-agents" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">AI Agents</h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Create and manage AI agents powered by Anthropic Claude and OpenAI GPT-4o.
                Supports real-time streaming, tool calls, and conversation memory.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Creating an Agent</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Agents are Ash resources with configurable providers, models, system prompts,
                    and temperature settings.
                  </p>
                  <.code_block code={"agent = Emakola.AI.Agent\n  |> Ash.Changeset.for_create(:create, %{\n    name: \"Research Assistant\",\n    provider: :anthropic,\n    model: \"claude-sonnet-4-20250514\",\n    system_prompt: \"You are a helpful research assistant.\",\n    temperature: 0.7\n  })\n  |> Ash.create!()"} />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Streaming Responses</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Stream AI responses in real-time via PubSub. Each token is broadcast
                    as it arrives, enabling live typing indicators in the UI.
                  </p>
                  <.code_block code={"Emakola.AI.chat(agent, \"Summarize this document\", fn\n  {:chunk, text} -> IO.write(text)\n  {:done, full_response} -> IO.puts(\"\\n---\\nDone!\")\n  {:error, reason} -> IO.puts(\"Error: \#{reason}\")\nend)"} />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Provider Configuration</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Switch between providers seamlessly. Each provider is configured via
                    environment variables.
                  </p>
                  <.code_block code="# .env\nANTHROPIC_API_KEY=sk-ant-...\nOPENAI_API_KEY=sk-...\n\n# Supported providers & models:\n# :anthropic  -> claude-sonnet-4-20250514, claude-3-haiku\n# :openai     -> gpt-4o, gpt-4o-mini, gpt-3.5-turbo" />
                </div>
              </div>
            </section>

            <%!-- ════════ Billing ════════ --%>
            <section id="billing" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">Billing</h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Stripe-powered billing with four pre-configured tiers, usage metering,
                webhook processing, and graceful degradation when Stripe is unavailable.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Plans and Subscriptions</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Four tiers ship out of the box: Free, Starter ($29/mo), Pro ($79/mo),
                    and Enterprise ($199/mo). Each with configurable feature limits.
                  </p>
                  <.code_block code={"# Plans are seeded automatically\nEmakola.Billing.Plan\n|> Ash.Query.sort(:price_monthly)\n|> Ash.read!()\n\n# Create a checkout session\nEmakola.Billing.create_checkout_session(user, plan, %{\n  success_url: \"https://yourapp.com/billing?success=true\",\n  cancel_url: \"https://yourapp.com/billing\"\n})"} />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Usage Metering</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Track API calls, token usage, and agent runs per billing period.
                    Usage data syncs to Stripe for metered billing.
                  </p>
                  <.code_block code="Emakola.Billing.record_usage(subscription, %{\n  metric: :api_calls,\n  quantity: 1,\n  timestamp: DateTime.utc_now()\n})\n\n# Check remaining quota\nEmakola.Billing.remaining_quota(subscription, :api_calls)\n# => {:ok, 8234}" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Webhook Processing</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Stripe webhooks are verified and processed automatically. Handles
                    subscription lifecycle events, payment failures, and invoice updates.
                  </p>
                  <.code_block code="# Handled automatically:\n# checkout.session.completed\n# customer.subscription.updated\n# customer.subscription.deleted\n# invoice.payment_succeeded\n# invoice.payment_failed\n\n# POST /webhooks/stripe\n# Signature verified via STRIPE_WEBHOOK_SECRET" />
                </div>
              </div>
            </section>

            <%!-- ════════ API ════════ --%>
            <section id="api" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">API</h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Auto-derived REST (JSON:API) and GraphQL endpoints from Ash resources.
                Rate limiting, authentication, and OpenAPI specs included.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">REST Endpoints</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    All resources expose JSON:API-compliant endpoints under <code class="text-primary font-mono text-sm">/api/v1</code>.
                  </p>
                  <.code_block code="GET    /api/v1/agents          # List agents\nGET    /api/v1/agents/:id      # Get agent by ID\nGET    /api/v1/plans           # List billing plans\nGET    /api/v1/plans/:id       # Get plan details\nGET    /api/v1/open_api        # OpenAPI specification" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">GraphQL</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    A full GraphQL schema is auto-generated from your Ash resources.
                    Use the built-in GraphiQL explorer in development.
                  </p>
                  <.code_block code="# POST /api/graphql\n{\n  agents {\n    id\n    name\n    provider\n    model\n    status\n    messages {\n      role\n      content\n    }\n  }\n}" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Rate Limiting</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Built-in rate limiting protects your API. Configurable per-endpoint
                    with sliding window counters.
                  </p>
                  <.code_block code="# Default: 100 requests per minute\nplug EmakolaWeb.Plugs.RateLimiter,\n  limit: 100,\n  window_ms: 60_000\n\n# Response headers:\n# X-RateLimit-Limit: 100\n# X-RateLimit-Remaining: 87\n# X-RateLimit-Reset: 1711234567" />
                </div>
              </div>
            </section>

            <%!-- ════════ Deployment ════════ --%>
            <section id="deployment" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">Deployment</h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Deploy to Fly.io with a single command, or use Docker for any platform.
                Production-ready configs ship out of the box.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Fly.io</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    The fastest path to production. Emakola includes a complete
                    <code class="text-primary font-mono text-sm">fly.toml</code>
                    configuration.
                  </p>
                  <.code_block code="fly launch --name my-saas\nfly secrets set ANTHROPIC_API_KEY=sk-ant-...\nfly secrets set STRIPE_SECRET_KEY=sk_live_...\nfly deploy" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Docker</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Multi-stage Dockerfile optimized for small image size and fast builds.
                  </p>
                  <.code_block code="docker build -t founderpad .\ndocker run -p 4000:4000 \\\n  -e DATABASE_URL=postgres://... \\\n  -e SECRET_KEY_BASE=... \\\n  -e ANTHROPIC_API_KEY=... \\\n  founderpad" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Environment Variables</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    All secrets and configuration are managed via environment variables.
                  </p>
                  <.code_block code="# Required\nDATABASE_URL=postgres://user:pass@host/db\nSECRET_KEY_BASE=super-secret-64-char-key\nPHX_HOST=yourapp.com\n\n# AI Providers\nANTHROPIC_API_KEY=sk-ant-...\nOPENAI_API_KEY=sk-...\n\n# Billing\nSTRIPE_SECRET_KEY=sk_live_...\nSTRIPE_WEBHOOK_SECRET=whsec_..." />
                </div>
              </div>
            </section>

            <%!-- ════════ Configuration ════════ --%>
            <section id="configuration" class="mb-24">
              <h2 class="text-3xl font-extrabold font-headline tracking-tight mb-3">Configuration</h2>
              <p class="text-on-surface-variant text-lg leading-relaxed mb-8 max-w-2xl">
                Customize branding, feature flags, and demo mode through simple
                configuration files.
              </p>

              <div class="space-y-8">
                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Branding</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Customize the app name, tagline, and logo from your config files.
                  </p>
                  <.code_block code={"# config/config.exs\nconfig :emakola, :branding,\n  app_name: \"My SaaS\",\n  tagline: \"Ship faster\",\n  logo_url: \"/images/logo.svg\",\n  primary_color: \"#6366f1\""} />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Feature Flags</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Toggle features on and off without deployments. Built on the
                    FeatureFlags Ash domain.
                  </p>
                  <.code_block code="# Check a feature flag\nEmakola.FeatureFlags.enabled?(:beta_agents)\n# => true\n\n# Toggle via admin\nEmakola.FeatureFlags.toggle(:beta_agents, false)" />
                </div>

                <div>
                  <h3 class="text-xl font-bold font-headline mb-3">Demo Mode</h3>
                  <p class="text-on-surface-variant leading-relaxed mb-4">
                    Enable demo mode for showcasing the app without real API keys or
                    payment processing.
                  </p>
                  <.code_block code="# config/dev.exs\nconfig :emakola,\n  demo_mode: true,\n  mock_ai_responses: true,\n  mock_stripe: true\n\n# Demo mode provides:\n# - Simulated AI responses with realistic delays\n# - Mock Stripe checkout flows\n# - Pre-populated dashboard data" />
                </div>
              </div>
            </section>
          </main>
        </div>
      </div>

      <.public_footer />
    </div>
    """
  end

  # -- Components --

  defp toc_link(assigns) do
    ~H"""
    <a
      href={"#" <> @section}
      phx-click="navigate"
      phx-value-section={@section}
      class={"block py-1.5 pl-3 text-sm transition-colors " <>
        if(@active == @section,
          do: "text-primary font-medium bg-primary/5 rounded-lg",
          else: "text-on-surface-variant hover:text-on-surface"
        )}
    >
      {@label}
    </a>
    """
  end

  defp code_block(assigns) do
    ~H"""
    <div class="bg-[#0d1117] rounded-xl p-6 overflow-x-auto">
      <pre class="font-mono text-[13px] leading-relaxed"><code><%= format_code(@code) %></code></pre>
    </div>
    """
  end

  defp format_code(code) do
    code
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

  # -- Shared nav --
  defp docs_nav(assigns) do
    ~H"""
    <nav class="fixed top-0 inset-x-0 z-50 bg-background/60 backdrop-blur-md">
      <div class="max-w-7xl mx-auto flex items-center justify-between px-6 py-4">
        <a href="/" class="flex items-center gap-2.5">
          <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <span class="material-symbols-outlined text-on-primary text-lg">architecture</span>
          </div>
          <span class="text-xl font-extrabold font-headline tracking-tight text-on-surface">
            Emakola
          </span>
        </a>

        <div class="hidden md:flex items-center gap-8 text-sm font-medium text-on-surface-variant">
          <a
            href="/docs"
            class={"hover:text-on-surface transition-colors " <> if(@active == "docs", do: "text-primary", else: "")}
          >
            Docs
          </a>
          <a
            href="/docs/api"
            class={"hover:text-on-surface transition-colors " <> if(@active == "api", do: "text-primary", else: "")}
          >
            API
          </a>
          <a
            href="/docs/changelog"
            class={"hover:text-on-surface transition-colors " <> if(@active == "changelog", do: "text-primary", else: "")}
          >
            Changelog
          </a>
          <a href="/auth/login" class="hover:text-on-surface transition-colors">Login</a>
        </div>

        <div class="flex items-center gap-3">
          <a
            href="/auth/register"
            class="hidden sm:inline-flex items-center px-5 py-2 rounded-lg text-sm font-semibold primary-gradient transition-transform hover:scale-[1.02] active:scale-95"
          >
            Get Started
          </a>
          <button
            id="theme-toggle-docs"
            phx-hook="ThemeToggle"
            class="p-2 text-on-surface-variant hover:text-on-surface transition-colors cursor-pointer rounded-lg hover:bg-surface-container-high/50"
          >
            <span class="material-symbols-outlined text-xl">dark_mode</span>
          </button>
        </div>
      </div>
    </nav>
    """
  end
end
