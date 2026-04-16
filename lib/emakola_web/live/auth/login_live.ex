defmodule EmakolaWeb.Auth.LoginLive do
  use EmakolaWeb, :live_view

  require Logger

  @login_limit 10
  @login_window_ms 60_000

  def mount(_params, _session, socket) do
    ip = get_client_ip(socket)

    {:ok,
     socket
     |> assign(client_ip: ip)
     |> assign(form: to_form(%{"email" => "", "password" => ""}, as: :user)), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row bg-[#0c1526]">
      <!-- Left Panel: Branded -->
      <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-t from-[#0c1526] via-[#0c1526] to-[#1a2744] overflow-hidden flex-col justify-between p-12">
        <!-- Top: Brand -->
        <div class="relative z-10">
          <div class="flex items-center gap-2">
            <img src={~p"/images/emakola-logo.svg"} alt="Emakola" class="h-9 w-auto" />
            <span class="text-[#f1f5f9] text-xl font-bold tracking-tight">Emakola</span>
          </div>
        </div>
        <!-- Middle: Headline + Photo -->
        <div class="relative z-10 space-y-8">
          <h2 class="text-4xl xl:text-5xl font-extrabold text-[#f1f5f9] leading-tight">
            Empowering Merchants Across Ghana.
          </h2>
          <div class="flex items-end gap-4">
            <div class="w-48 h-56 rounded-2xl overflow-hidden shadow-2xl border-2 border-white/10">
              <img
                src={~p"/images/landing/testimonial-1.jpg"}
                alt="Merchant"
                class="w-full h-full object-cover"
              />
            </div>
            <div class="bg-[#1a2744]/80 backdrop-blur-sm rounded-xl p-4 max-w-[220px] border border-white/10">
              <p class="text-[#d4a843] text-xs font-semibold uppercase tracking-wider mb-1">
                Authentic Growth
              </p>
              <p class="text-[#f1f5f9] text-sm leading-relaxed">
                Join over 500+ merchants building their businesses on Emakola.
              </p>
            </div>
          </div>
        </div>
        <!-- Bottom: Location -->
        <div class="relative z-10 flex items-center justify-between text-[#8896ab] text-sm">
          <span>Accra / Kumasi / Takoradi</span>
          <span>Est. 2024</span>
        </div>
      </div>
      
    <!-- Right Panel: Form -->
      <div class="flex-1 flex items-center justify-center bg-[#f7f8fa] px-6 py-12">
        <div class="w-full max-w-md">
          <!-- Mobile brand (visible on small screens) -->
          <div class="lg:hidden flex items-center justify-center gap-2 mb-8">
            <img src={~p"/images/emakola-logo.svg"} alt="Emakola" class="h-8 w-auto" />
            <span class="text-[#0c1526] text-lg font-bold tracking-tight">Emakola</span>
          </div>
          <!-- Heading -->
          <div class="mb-8">
            <h1 class="text-2xl font-bold text-[#0c1526]">Welcome back</h1>
            <p class="text-[#5f6b7a] mt-1 text-sm">Sign in to your merchant account</p>
          </div>
          <!-- Tab Toggle -->
          <div class="flex mb-8 bg-white rounded-xl p-1 shadow-sm border border-gray-100">
            <div class="flex-1 text-center py-2.5 px-4 bg-[#0c1526] text-[#f1f5f9] rounded-lg text-sm font-semibold">
              Login
            </div>
            <a
              href="/auth/register"
              class="flex-1 text-center py-2.5 px-4 text-[#5f6b7a] rounded-lg text-sm font-medium hover:text-[#0c1526] transition-colors"
            >
              Create Account
            </a>
          </div>
          <!-- WhatsApp Button -->
          <button
            type="button"
            disabled
            class="w-full flex items-center justify-center gap-2 bg-[#25D366] hover:bg-[#20bd5a] text-white font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm mb-6 opacity-50 cursor-not-allowed"
          >
            <span class="material-symbols-outlined text-xl">chat</span>
            Continue with WhatsApp (Coming Soon)
          </button>
          <!-- OR EMAIL Divider -->
          <div class="relative mb-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-200"></div>
            </div>
            <div class="relative flex justify-center text-xs">
              <span class="bg-[#f7f8fa] px-4 text-[#8896ab] font-medium uppercase tracking-wider">
                or sign in with email
              </span>
            </div>
          </div>
          <!-- Flash Messages -->
          <div
            :if={@flash["error"]}
            class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
            role="alert"
          >
            <span class="material-symbols-outlined text-lg text-red-500">error</span>
            <span>{@flash["error"]}</span>
          </div>
          <div
            :if={@flash["info"]}
            class="mb-4 flex items-center gap-2 rounded-xl bg-blue-50 border border-blue-200 px-4 py-3 text-sm text-blue-700"
            role="alert"
          >
            <span class="material-symbols-outlined text-lg text-blue-500">info</span>
            <span>{@flash["info"]}</span>
          </div>
          <!-- Login Form -->
          <.form for={@form} phx-submit="login" class="space-y-4">
            <!-- Email -->
            <div>
              <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Email</label>
              <div class="relative">
                <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                  mail
                </span>
                <input
                  type="email"
                  name="user[email]"
                  value={@form[:email].value}
                  placeholder="you@business.com"
                  required
                  class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                />
              </div>
            </div>
            <!-- Password -->
            <div>
              <div class="flex items-center justify-between mb-1.5">
                <label class="block text-sm font-medium text-[#0c1526]">Password</label>
                <a href="#" class="text-xs font-medium text-[#2563eb] hover:underline">Forgot?</a>
              </div>
              <div class="relative">
                <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                  lock
                </span>
                <input
                  type="password"
                  name="user[password]"
                  placeholder="Enter your password"
                  required
                  id="login-password"
                  class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-10 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                />
                <button
                  type="button"
                  phx-click={JS.dispatch("toggle-password", to: "#login-password")}
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-[#8896ab] hover:text-[#5f6b7a] transition-colors"
                >
                  <span class="material-symbols-outlined text-xl">visibility</span>
                </button>
              </div>
            </div>
            <!-- Keep me logged in -->
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                id="keep-logged-in"
                class="w-4 h-4 rounded border-gray-300 text-[#2563eb] focus:ring-[#2563eb]"
              />
              <label for="keep-logged-in" class="text-sm text-[#5f6b7a]">Keep me logged in</label>
            </div>
            <!-- CTA -->
            <button
              type="submit"
              class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
            >
              Sign In
            </button>
          </.form>
          <!-- Trust Badges -->
          <div class="flex items-center justify-center gap-6 mt-6">
            <div class="flex items-center gap-1.5 text-[#8896ab] text-xs">
              <span class="material-symbols-outlined text-base">lock</span> SSL Secured
            </div>
            <div class="flex items-center gap-1.5 text-[#8896ab] text-xs">
              <span class="material-symbols-outlined text-base">phone_android</span> MoMo Integrated
            </div>
          </div>
          <!-- Terms -->
          <p class="text-center text-xs text-[#8896ab] mt-6">
            By signing in, you agree to our
            <a href="#" class="text-[#2563eb] hover:underline">Terms of Service</a>
            and <a href="#" class="text-[#2563eb] hover:underline">Privacy Policy</a>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("login", %{"user" => params}, socket) do
    ip = socket.assigns.client_ip
    rate_key = "auth_login:#{ip}"

    case Emakola.RateLimit.check_rate(rate_key, @login_limit, @login_window_ms) do
      {:deny, _retry_after} ->
        Logger.warning("Login rate limit exceeded for #{ip}")

        {:noreply,
         socket
         |> put_flash(:error, "Too many login attempts. Please try again in a minute.")
         |> assign(form: to_form(%{"email" => params["email"], "password" => ""}, as: :user))}

      {:allow, _count} ->
        do_login(params, socket, ip)
    end
  end

  defp do_login(params, socket, ip) do
    # Try Merchant auth first (ecommerce merchants), fall back to User (legacy)
    {auth_result, _resource} =
      case try_merchant_login(params) do
        {:ok, merchant} -> {{:ok, merchant}, :merchant}
        _ -> {try_user_login(params), :user}
      end

    case auth_result do
      {:ok, user} ->
        token = AshAuthentication.user_to_subject(user)

        # Log the login to audit trail (safely — connect_info may not be available)
        try do
          ua = Phoenix.LiveView.get_connect_info(socket, :user_agent) || "LiveView"

          Emakola.Audit.log(:login, "User", to_string(user.id), user.id, nil,
            user_agent: ua,
            ip_address: ip
          )
        rescue
          _ -> :ok
        end

        {:noreply,
         socket
         |> put_flash(:info, "Welcome back!")
         |> redirect(to: "/auth/session?token=#{URI.encode_www_form(token)}")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid email or password")
         |> assign(form: to_form(%{"email" => params["email"], "password" => ""}, as: :user))}
    end
  end

  defp try_merchant_login(params) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :password)

    AshAuthentication.Strategy.action(strategy, :sign_in, %{
      "email" => params["email"],
      "password" => params["password"]
    })
  rescue
    _ -> {:error, :not_found}
  end

  defp try_user_login(params) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.User, :password)

    AshAuthentication.Strategy.action(strategy, :sign_in, %{
      "email" => params["email"],
      "password" => params["password"]
    })
  end

  # Must be called during mount — get_connect_info is only available then
  defp get_client_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      %{address: ip} -> to_string(:inet.ntoa(ip))
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
end
