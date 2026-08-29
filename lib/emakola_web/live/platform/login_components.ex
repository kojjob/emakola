defmodule EmakolaWeb.Platform.LoginComponents do
  @moduledoc """
  Form components for the platform two-step login page.

  Extracted from LoginLive to keep that module under ~220 lines.
  """

  use Phoenix.Component

  # ── credentials step ────────────────────────────────────────────

  attr :form, :any, required: true

  def credentials_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="platform-credentials-form"
      phx-submit="submit_credentials"
      class="space-y-4"
    >
      <div>
        <label for="login-email" class="block text-sm font-medium text-[#0c1526] mb-1.5">
          Email
        </label>
        <input
          type="email"
          id="login-email"
          name="user[email]"
          value={@form[:email].value}
          placeholder="you@makola.io"
          required
          autocomplete="email"
          class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
        />
      </div>
      <div>
        <label for="login-password" class="block text-sm font-medium text-[#0c1526] mb-1.5">
          Password
        </label>
        <input
          type="password"
          id="login-password"
          name="user[password]"
          placeholder="Enter your password"
          required
          autocomplete="current-password"
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

  # ── TOTP enrolment step ──────────────────────────────────────────

  attr :qr_svg, :any, required: true
  attr :otpauth_secret_base32, :string, required: true

  def totp_setup_form(assigns) do
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
        <.code_input id="totp-setup-code" />
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

  # ── TOTP verify step ────────────────────────────────────────────

  def totp_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <.form for={%{}} as={:totp} id="platform-totp-form" phx-submit="submit_totp" class="space-y-4">
        <.code_input id="totp-code" />
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

  # ── Shared primitives ────────────────────────────────────────────

  attr :id, :string, required: true
  attr :field, Phoenix.HTML.FormField, default: nil

  def code_input(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-[#0c1526] mb-1.5">6-digit code</label>
      <input
        type="text"
        id={@id}
        name={if @field, do: @field.name, else: "totp[code]"}
        value={@field && @field.value}
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

  def back_link(assigns) do
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
