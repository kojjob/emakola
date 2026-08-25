defmodule EmakolaWeb.Auth.ForgotPasswordLive do
  use EmakolaWeb, :live_view

  require Logger

  # Mirrors LoginLive's limiter; plus a per-email cap so nobody can bomb a
  # merchant's inbox from rotating IPs.
  @ip_limit 10
  @ip_window_ms 60_000
  @email_limit 3
  @email_window_ms 15 * 60_000

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(client_ip: EmakolaWeb.ClientIp.resolve(socket))
     |> assign(sent: false)
     |> assign(form: to_form(%{"email" => ""}, as: :forgot)), layout: false}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-6 py-12">
        <div class="w-full max-w-md">
          <div class="flex items-center justify-center gap-2 mb-8">
            <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-8 w-auto" />
            <span class="text-[#0c1526] text-lg font-bold tracking-tight">Makola</span>
          </div>

          <div class="mb-8 text-center">
            <h1 class="text-2xl font-bold text-[#0c1526]">Forgot your password?</h1>
            <p class="text-[#5f6b7a] mt-1 text-sm">
              Enter your account email and we'll send you a reset link.
            </p>
          </div>

          <div
            :if={@flash["error"]}
            class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
            role="alert"
          >
            <span class="material-symbols-outlined text-lg text-red-500">error</span>
            <span>{@flash["error"]}</span>
          </div>

          <div
            :if={@sent}
            class="mb-4 flex items-start gap-2 rounded-xl bg-emerald-50 border border-emerald-200 px-4 py-3 text-sm text-emerald-800"
            role="status"
          >
            <span class="material-symbols-outlined text-lg text-emerald-600">mark_email_read</span>
            <span>
              If that email has a Makola account, we've sent a reset link.
              It expires in 24 hours — check your spam folder too.
            </span>
          </div>

          <.form
            :if={!@sent}
            for={@form}
            id="forgot-password-form"
            phx-submit="request_reset"
            class="space-y-4"
          >
            <div>
              <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Email</label>
              <div class="relative">
                <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                  mail
                </span>
                <input
                  type="email"
                  name="forgot[email]"
                  value={@form[:email].value}
                  placeholder="you@business.com"
                  required
                  class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                />
              </div>
            </div>
            <button
              type="submit"
              class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
            >
              Send Reset Link
            </button>
          </.form>

          <p class="mt-6 text-center text-sm text-[#5f6b7a]">
            Remembered it?
            <a href="/auth/recover-phone" class="font-medium text-[#2563eb] hover:underline">
              No email? Use your phone number
            </a>
            <span class="mx-2 text-slate-300">·</span>
            <a href="/auth/login" class="font-medium text-[#2563eb] hover:underline">Back to login</a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("request_reset", %{"forgot" => %{"email" => email}}, socket) do
    ip = socket.assigns.client_ip
    email = email |> String.trim() |> String.downcase()

    with {:allow, _} <- check_rate("auth_forgot:#{ip}", @ip_limit, @ip_window_ms),
         {:allow, _} <-
           check_rate("auth_forgot_email:#{email}", @email_limit, @email_window_ms) do
      request_reset(email)
      {:noreply, assign(socket, sent: true)}
    else
      {:deny, _retry_after} ->
        Logger.warning("Password-reset request rate limit exceeded for #{ip}")

        {:noreply,
         put_flash(socket, :error, "Too many reset requests. Please try again in a few minutes.")}
    end
  end

  # Honors the :disable_rate_limit kill-switch (DISABLE_RATE_LIMIT=1 in dev):
  # the per-email cap otherwise locks E2E reruns out for 15 minutes at a time.
  defp check_rate(key, limit, window_ms) do
    if Application.get_env(:emakola, :disable_rate_limit, false) do
      {:allow, 0}
    else
      Emakola.RateLimit.check_rate(key, limit, window_ms)
    end
  end

  defp request_reset(email) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :password)
    AshAuthentication.Strategy.action(strategy, :reset_request, %{"email" => email})
  rescue
    # An email/provider hiccup must not become an enumeration oracle — the UI
    # shows the neutral confirmation either way; the failure is in the logs.
    exception ->
      Logger.error("[ForgotPassword] reset_request raised: #{Exception.message(exception)}")
      :ok
  end
end
