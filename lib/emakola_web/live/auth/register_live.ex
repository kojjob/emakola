defmodule EmakolaWeb.Auth.RegisterLive do
  use EmakolaWeb, :live_view

  import EmakolaWeb.AuthComponents
  import EmakolaWeb.OAuthComponents

  require Logger

  @register_limit 5
  @register_window_ms 60_000

  def mount(_params, _session, socket) do
    ip = EmakolaWeb.ClientIp.resolve(socket)

    {:ok,
     socket
     |> assign(client_ip: ip)
     |> assign(form: to_form(%{"email" => "", "password" => "", "name" => ""}, as: :user)),
     layout: false}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen flex flex-col lg:flex-row bg-[#0c1526]">
        <!-- Left Panel: Branded -->
        <div class="hidden lg:flex lg:w-1/2 bg-gradient-to-t from-[#0c1526] via-[#0c1526] to-[#1a2744] overflow-hidden flex-col justify-between p-12">
          <!-- Top: Brand -->
          <div class="relative z-10">
            <div class="flex items-center gap-2">
              <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-9 w-auto" />
              <span class="text-[#f1f5f9] text-xl font-bold tracking-tight">Makola</span>
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
                  Join over 500+ merchants building their businesses on Makola.
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
              <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-8 w-auto" />
              <span class="text-[#0c1526] text-lg font-bold tracking-tight">Makola</span>
            </div>
            <!-- Heading -->
            <div class="mb-8">
              <h1 class="text-2xl font-bold text-[#0c1526]">Create your account</h1>
              <p class="text-[#5f6b7a] mt-1 text-sm">Start your journey as a merchant in Ghana</p>
            </div>
            <!-- Tab Toggle -->
            <div class="flex mb-8 bg-white rounded-xl p-1 shadow-sm border border-gray-100">
              <a
                href="/auth/login"
                class="flex-1 text-center py-2.5 px-4 text-[#5f6b7a] rounded-lg text-sm font-medium hover:text-[#0c1526] transition-colors"
              >
                Login
              </a>
              <div class="flex-1 text-center py-2.5 px-4 bg-[#0c1526] text-[#f1f5f9] rounded-lg text-sm font-semibold">
                Create Account
              </div>
            </div>
            <!-- WhatsApp Button (ship-dark: shown only when phone auth is enabled) -->
            <.whatsapp_button
              :if={Emakola.Accounts.PhoneAuth.enabled?()}
              href={~p"/auth/whatsapp"}
              class="mb-6"
            />
            <.oauth_buttons subject="merchant" class="mb-6" />
            <!-- OR EMAIL Divider -->
            <div class="relative mb-6">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-gray-200"></div>
              </div>
              <div class="relative flex justify-center text-xs">
                <span class="bg-[#f7f8fa] px-4 text-[#8896ab] font-medium uppercase tracking-wider">
                  or sign up with email
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
            <!-- Register Form -->
            <.form for={@form} phx-submit="register" class="space-y-4">
              <!-- Full Name -->
              <div>
                <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Full Name</label>
                <div class="relative">
                  <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                    person
                  </span>
                  <input
                    type="text"
                    name="user[name]"
                    value={@form[:name].value}
                    placeholder="Kwame Asante"
                    required
                    class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                  />
                </div>
              </div>
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
                <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Password</label>
                <div class="relative">
                  <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                    lock
                  </span>
                  <input
                    type="password"
                    name="user[password]"
                    placeholder="Min. 8 characters"
                    required
                    id="register-password"
                    class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-10 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                  />
                  <button
                    type="button"
                    phx-click={JS.dispatch("toggle-password", to: "#register-password")}
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-[#8896ab] hover:text-[#5f6b7a] transition-colors"
                  >
                    <span class="material-symbols-outlined text-xl">visibility</span>
                  </button>
                </div>
                <p class="text-xs text-[#8896ab] mt-1">Password must be at least 8 characters</p>
              </div>
              <!-- CTA -->
              <button
                type="submit"
                class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
              >
                Create Merchant Account
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
              By creating an account, you agree to our
              <a href="#" class="text-[#2563eb] hover:underline">Terms of Service</a>
              and <a href="#" class="text-[#2563eb] hover:underline">Privacy Policy</a>.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("register", %{"user" => params}, socket) do
    ip = socket.assigns.client_ip
    rate_key = "auth_register:#{ip}"

    case Emakola.RateLimit.check_rate(rate_key, @register_limit, @register_window_ms) do
      {:deny, _retry_after} ->
        Logger.warning("Registration rate limit exceeded for #{ip}")

        {:noreply,
         socket
         |> put_flash(:error, "Too many registration attempts. Please try again in a minute.")
         |> assign(
           form:
             to_form(
               %{"email" => params["email"], "password" => "", "name" => params["name"]},
               as: :user
             )
         )}

      {:allow, _count} ->
        do_register(params, socket)
    end
  end

  defp do_register(params, socket) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :password)

    case AshAuthentication.Strategy.action(strategy, :register, %{
           "email" => params["email"],
           "password" => params["password"],
           "password_confirmation" => params["password"]
         }) do
      {:ok, merchant} ->
        # Save the merchant's name from the registration form
        name = String.trim(params["name"] || "")

        if name != "" do
          Emakola.Accounts.update_merchant_profile(merchant, %{name: name}, authorize?: false)
        end

        token =
          EmakolaWeb.AuthTokens.sign_subject_exchange(AshAuthentication.user_to_subject(merchant))

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(
           to: "/auth/session?token=#{URI.encode_www_form(token)}&redirect_to=%2Fonboarding"
         )}

      {:error, error} ->
        error_messages = extract_errors(error)

        {:noreply,
         socket
         |> put_flash(:error, error_messages)
         |> assign(
           form:
             to_form(
               %{"email" => params["email"], "password" => "", "name" => params["name"]},
               as: :user
             )
         )}
    end
  end

  defp extract_errors(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{field: field} = error when is_binary(field) ->
        "#{Phoenix.Naming.humanize(field)} #{EmakolaWeb.AshErrors.message(error)}"

      %{field: field} = error when is_atom(field) ->
        "#{Phoenix.Naming.humanize(Atom.to_string(field))} #{EmakolaWeb.AshErrors.message(error)}"

      %{message: message} = error when is_binary(message) ->
        EmakolaWeb.AshErrors.message(error)

      other ->
        inspect(other)
    end)
    |> Enum.join(". ")
  end

  defp extract_errors(_), do: "Registration failed. Please try again."
end
