defmodule EmakolaWeb.Platform.LoginLive do
  @moduledoc """
  Two-step platform staff login.

  Step 1 (:credentials): email + password via the AshAuthentication password
  strategy. Non-staff and deactivated accounts get the same generic error as
  bad credentials, so the page never reveals which accounts are staff.

  Step 2 (:totp): 6-digit TOTP verify — or (:totp_setup) forced enrolment
  with a QR code on first sign-in. Pending state lives only in this process;
  a page reload restarts the login, which is acceptable.

  On success we redirect to `GET /platform/session?t=<30s token>` —
  `PlatformSessionController` writes the session cookie (LiveView cannot).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Accounts.TOTP
  alias EmakolaWeb.AuthTokens

  @rate_limit 5
  @rate_window_ms 60_000
  @rate_limited_error "Too many attempts. Please try again in a minute."
  @generic_error "Invalid email or password"

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(client_ip: client_ip(socket))
     |> reset_to_credentials()
     |> assign(error: nil)}
  end

  # ── Step 1: credentials ─────────────────────────────────────────

  def handle_event("submit_credentials", %{"user" => params}, socket) do
    case Emakola.RateLimit.check_rate(
           "platform_login:#{socket.assigns.client_ip}",
           @rate_limit,
           @rate_window_ms
         ) do
      {:deny, _retry_after} ->
        {:noreply, assign(socket, error: @rate_limited_error)}

      {:allow, _count} ->
        verify_password(socket, params["email"] || "", params["password"] || "")
    end
  end

  # ── Step 2a: forced TOTP enrolment ──────────────────────────────

  def handle_event("submit_totp_setup", %{"totp" => %{"code" => code}}, socket) do
    case load_pending_staff(socket) do
      {:ok, user} ->
        user
        |> Ash.Changeset.for_update(:setup_totp, %{
          secret: socket.assigns.pending_secret,
          code: code
        })
        |> Ash.update(authorize?: false)
        |> case do
          # setup_totp already set totp_last_used_at — no record_totp_use
          {:ok, user} -> {:noreply, redirect_to_exchange(socket, user)}
          {:error, _} -> {:noreply, assign(socket, error: "Invalid code")}
        end

      {:reset, socket} ->
        {:noreply, socket}
    end
  end

  # ── Step 2b: TOTP verify ────────────────────────────────────────

  def handle_event("submit_totp", %{"totp" => %{"code" => code}}, socket) do
    case load_pending_staff(socket) do
      {:ok, user} ->
        case Emakola.RateLimit.check_rate(
               "platform_totp:#{user.id}",
               @rate_limit,
               @rate_window_ms
             ) do
          {:deny, _retry_after} ->
            {:noreply, assign(socket, error: @rate_limited_error)}

          {:allow, _count} ->
            verify_totp(socket, user, code)
        end

      {:reset, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, socket |> reset_to_credentials() |> assign(error: nil)}
  end

  # ── Credential verification ─────────────────────────────────────

  defp verify_password(socket, email, password) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.User, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, user} ->
        if PlatformPermissions.staff?(user) do
          {:noreply, advance_to_totp(socket, user)}
        else
          # Treat exactly like wrong credentials — never reveal staff status
          audit_sign_in_failed(socket, %{email: email, reason: "not_staff"})
          {:noreply, invalid_credentials(socket, email)}
        end

      {:error, _} ->
        audit_sign_in_failed(socket, %{email: email})
        {:noreply, invalid_credentials(socket, email)}
    end
  end

  defp advance_to_totp(socket, %{totp_secret: nil} = user) do
    secret = TOTP.generate_secret()
    uri = TOTP.otpauth_uri(to_string(user.email), secret)

    assign(socket,
      step: :totp_setup,
      pending_user_id: user.id,
      pending_secret: secret,
      # Safe to mark raw: EQRCode emits pure geometry; no user text in the markup
      qr_svg: Phoenix.HTML.raw(TOTP.qr_svg(uri)),
      otpauth_secret_base32: Base.encode32(secret, padding: false),
      error: nil
    )
  end

  defp advance_to_totp(socket, user) do
    assign(socket, step: :totp, pending_user_id: user.id, error: nil)
  end

  defp invalid_credentials(socket, email) do
    socket
    |> assign(error: @generic_error)
    |> assign(form: to_form(%{"email" => email, "password" => ""}, as: :user))
  end

  defp audit_sign_in_failed(socket, metadata) do
    PlatformAudit.log(:sign_in_failed, nil, metadata, socket.assigns.client_ip)
  end

  # ── TOTP verification ───────────────────────────────────────────

  defp verify_totp(socket, user, code) do
    if TOTP.valid_code?(user.totp_secret, code, since: user.totp_last_used_at) do
      user
      |> Ash.Changeset.for_update(:record_totp_use, %{})
      |> Ash.update!(authorize?: false)

      {:noreply, redirect_to_exchange(socket, user)}
    else
      PlatformAudit.log(:totp_failed, user, %{}, socket.assigns.client_ip)
      {:noreply, assign(socket, error: "Invalid code")}
    end
  end

  # Re-verify staff status on every step-2 event: the pending state could be
  # stale (e.g. deactivated mid-login) or absent (direct event submission).
  defp load_pending_staff(socket) do
    with id when is_binary(id) <- socket.assigns.pending_user_id,
         {:ok, user} <- Emakola.Accounts.get_user_by_id(id, authorize?: false),
         true <- PlatformPermissions.staff?(user) do
      {:ok, user}
    else
      _ -> {:reset, socket |> reset_to_credentials() |> assign(error: @generic_error)}
    end
  end

  defp redirect_to_exchange(socket, user) do
    token = AuthTokens.sign_login_exchange(user.id)
    redirect(socket, to: "/platform/session?t=#{URI.encode_www_form(token)}")
  end

  defp reset_to_credentials(socket) do
    assign(socket,
      step: :credentials,
      pending_user_id: nil,
      pending_secret: nil,
      qr_svg: nil,
      otpauth_secret_base32: nil,
      form: to_form(%{"email" => "", "password" => ""}, as: :user)
    )
  end

  # Must be called during mount — get_connect_info is only available then
  defp client_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      %{address: ip} -> to_string(:inet.ntoa(ip))
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  # ── Render ──────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#0c1526] px-6 py-12">
      <div class="w-full max-w-md">
        <div class="flex items-center justify-center gap-2 mb-8">
          <img src={~p"/images/emakola-logo.svg"} alt="Emakola" class="h-8 w-auto" />
          <span class="text-[#f1f5f9] text-lg font-bold tracking-tight">Emakola</span>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-6 sm:p-8">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-[#0c1526]">Platform sign in</h1>
            <p class="text-[#5f6b7a] mt-1 text-sm">{subtitle(@step)}</p>
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
            :if={@error}
            class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
            role="alert"
          >
            <span class="material-symbols-outlined text-lg text-red-500">error</span>
            <span>{@error}</span>
          </div>

          <.credentials_form :if={@step == :credentials} form={@form} />
          <.totp_setup_form
            :if={@step == :totp_setup}
            qr_svg={@qr_svg}
            otpauth_secret_base32={@otpauth_secret_base32}
          />
          <.totp_form :if={@step == :totp} />
        </div>
      </div>
    </div>
    """
  end

  defp subtitle(:credentials), do: "Restricted to Emakola platform staff"
  defp subtitle(:totp_setup), do: "Set up two-factor authentication to continue"
  defp subtitle(:totp), do: "Enter the code from your authenticator app"

  defp credentials_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="platform-credentials-form"
      phx-submit="submit_credentials"
      class="space-y-4"
    >
      <div>
        <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Email</label>
        <input
          type="email"
          name="user[email]"
          value={@form[:email].value}
          placeholder="you@emakola.com"
          required
          class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
        />
      </div>
      <div>
        <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Password</label>
        <input
          type="password"
          name="user[password]"
          placeholder="Enter your password"
          required
          class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
        />
      </div>
      <button
        type="submit"
        class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
      >
        Continue
      </button>
    </.form>
    """
  end

  defp totp_setup_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-[#5f6b7a]">
        Scan this QR code with your authenticator app (Google Authenticator, 1Password, …),
        then enter the 6-digit code it shows.
      </p>
      <%!-- @qr_svg is already marked safe at assign time (pure QR geometry) --%>
      <div class="flex justify-center rounded-xl border border-gray-200 p-4">
        {@qr_svg}
      </div>
      <p class="text-xs text-[#5f6b7a]">
        Can't scan? Enter this key manually:
        <code
          id="totp-manual-secret"
          class="block mt-1 break-all rounded-lg bg-gray-50 px-3 py-2 font-mono text-[#0c1526]"
        >
          {@otpauth_secret_base32}
        </code>
      </p>
      <.form
        for={%{}}
        as={:totp}
        id="platform-totp-setup-form"
        phx-submit="submit_totp_setup"
        class="space-y-4"
      >
        <.code_input />
        <button
          type="submit"
          class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
        >
          Verify and sign in
        </button>
      </.form>
      <.back_link />
    </div>
    """
  end

  defp totp_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <.form for={%{}} as={:totp} id="platform-totp-form" phx-submit="submit_totp" class="space-y-4">
        <.code_input />
        <button
          type="submit"
          class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
        >
          Verify and sign in
        </button>
      </.form>
      <.back_link />
    </div>
    """
  end

  defp code_input(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-[#0c1526] mb-1.5">6-digit code</label>
      <input
        type="text"
        name="totp[code]"
        inputmode="numeric"
        autocomplete="one-time-code"
        pattern="[0-9]{6}"
        maxlength="6"
        placeholder="123456"
        required
        class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-center text-lg tracking-[0.5em] text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
      />
    </div>
    """
  end

  defp back_link(assigns) do
    ~H"""
    <button
      type="button"
      id="totp-back"
      phx-click="back"
      class="w-full text-center text-sm font-medium text-[#5f6b7a] hover:text-[#0c1526] transition-colors"
    >
      Back
    </button>
    """
  end
end
