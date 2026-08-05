defmodule EmakolaWeb.Platform.SecurityComponents do
  @moduledoc """
  Function components for the platform security page: own 2FA status card
  (with the code-gated rotation flow) and the active sessions table.

  Extracted from SecurityLive to keep that module under ~220 lines.
  """
  use Phoenix.Component

  import EmakolaWeb.Platform.LoginComponents, only: [code_input: 1]

  alias Emakola.Security.SecretStorage
  alias EmakolaWeb.Layouts

  attr :current_user, :map, required: true
  attr :rotation_step, :atom, required: true
  attr :rotation_error, :string, required: true
  attr :qr_svg, :any, required: true
  attr :otpauth_secret_base32, :string, required: true
  attr :rotation_verify_form, :any, required: true
  attr :rotation_confirm_form, :any, required: true
  attr :sessions, :any, required: true
  attr :sessions_count, :integer, required: true
  attr :sessions_loaded?, :boolean, required: true
  attr :current_session_id, :string, required: true

  def security_page(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-4xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Security</h1>
        <p class="text-sm text-gray-500 mt-1">Your two-factor authentication and active sessions</p>
      </div>

      <.totp_card
        current_user={@current_user}
        rotation_step={@rotation_step}
        rotation_error={@rotation_error}
        qr_svg={@qr_svg}
        otpauth_secret_base32={@otpauth_secret_base32}
        rotation_verify_form={@rotation_verify_form}
        rotation_confirm_form={@rotation_confirm_form}
      />
      <.sessions_card
        sessions={@sessions}
        sessions_count={@sessions_count}
        sessions_loaded?={@sessions_loaded?}
        current_session_id={@current_session_id}
      />
    </div>
    """
  end

  # ── Two-factor card ──────────────────────────────────────────────

  attr :current_user, :map, required: true
  attr :rotation_step, :atom, required: true
  attr :rotation_error, :string, required: true
  attr :qr_svg, :any, required: true
  attr :otpauth_secret_base32, :string, required: true
  attr :rotation_verify_form, :any, required: true
  attr :rotation_confirm_form, :any, required: true

  defp totp_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mb-8">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="text-lg font-semibold text-gray-900">Two-factor authentication</h2>
      </div>
      <div class="px-6 py-5">
        <div
          :if={@rotation_error}
          class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
          role="alert"
        >
          <span class="material-symbols-outlined text-lg text-red-500">error</span>
          <span>{@rotation_error}</span>
        </div>

        <.totp_status :if={@rotation_step == :status} current_user={@current_user} />
        <.totp_verify :if={@rotation_step == :verify} form={@rotation_verify_form} />
        <.totp_confirm
          :if={@rotation_step == :confirm}
          form={@rotation_confirm_form}
          qr_svg={@qr_svg}
          otpauth_secret_base32={@otpauth_secret_base32}
        />
      </div>
    </div>
    """
  end

  attr :current_user, :map, required: true

  defp totp_status(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 flex-wrap">
      <%= if SecretStorage.totp_configured?(@current_user) do %>
        <div>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
            Two-factor authentication is enabled
          </span>
          <%!-- totp_last_used_at tracks last USE, not setup — label it as such --%>
          <p :if={@current_user.totp_last_used_at} class="text-xs text-gray-400 mt-2">
            Last used {Layouts.relative_time(@current_user.totp_last_used_at)} ago
          </p>
        </div>
        <button
          type="button"
          id="rotate-totp"
          phx-click="start_rotation"
          class="inline-flex items-center px-4 py-2 rounded-xl text-sm font-semibold text-blue-600 border border-blue-200 hover:bg-blue-50 transition-colors"
        >
          Rotate 2FA
        </button>
      <% else %>
        <p class="text-sm text-gray-500">
          Two-factor authentication is not set up. You will be asked to set it up at your
          next sign-in.
        </p>
      <% end %>
    </div>
    """
  end

  attr :form, :any, required: true

  defp totp_verify(assigns) do
    ~H"""
    <div class="space-y-4 max-w-sm">
      <p class="text-sm text-gray-500">
        Enter your <strong>current</strong> authenticator code to rotate your 2FA secret.
      </p>
      <.form
        for={@form}
        id="totp-rotate-verify-form"
        phx-submit="verify_rotation_code"
        class="space-y-4"
      >
        <.code_input id="rotate-verify-code" field={@form[:code]} />
        <button
          type="submit"
          class="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Continue
        </button>
      </.form>
      <.cancel_button />
    </div>
    """
  end

  attr :qr_svg, :any, required: true
  attr :otpauth_secret_base32, :string, required: true
  attr :form, :any, required: true

  defp totp_confirm(assigns) do
    ~H"""
    <div class="space-y-4 max-w-sm">
      <p class="text-sm text-gray-500">
        Scan this QR code with your authenticator app, then enter the 6-digit code it shows.
        Your old secret stops working once you confirm.
      </p>
      <%!-- @qr_svg is already marked safe at assign time (pure QR geometry) --%>
      <div class="flex justify-center rounded-xl border border-gray-200 p-4">
        {@qr_svg}
      </div>
      <p class="text-xs text-gray-500">
        Can't scan? Enter this key manually:
        <code
          id="totp-manual-secret"
          class="block mt-1 break-all rounded-lg bg-gray-50 px-3 py-2 font-mono text-gray-900"
        >
          {@otpauth_secret_base32}
        </code>
      </p>
      <.form
        for={@form}
        id="totp-rotate-confirm-form"
        phx-submit="confirm_rotation_code"
        class="space-y-4"
      >
        <.code_input id="rotate-confirm-code" field={@form[:code]} />
        <button
          type="submit"
          class="w-full py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
        >
          Confirm new code
        </button>
      </.form>
      <.cancel_button />
    </div>
    """
  end

  defp cancel_button(assigns) do
    ~H"""
    <button
      type="button"
      id="cancel-rotation"
      phx-click="cancel_rotation"
      class="w-full text-center text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors"
    >
      Cancel
    </button>
    """
  end

  # ── Active sessions card ─────────────────────────────────────────

  attr :sessions, :any, required: true
  attr :sessions_count, :integer, required: true
  attr :sessions_loaded?, :boolean, required: true
  attr :current_session_id, :string, required: true

  defp sessions_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100">
        <h2 class="text-lg font-semibold text-gray-900">Active sessions</h2>
      </div>
      <%= if !@sessions_loaded? do %>
        <div class="px-6 py-12 text-center text-sm text-gray-400">Loading sessions…</div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Device</th>
                <th class="px-6 py-3">IP address</th>
                <th class="px-6 py-3">Last seen</th>
                <th class="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody
              id="platform-security-sessions"
              phx-update="stream"
              data-count={@sessions_count}
              class="divide-y divide-gray-100"
            >
              <tr :if={@sessions_count == 0} id="platform-security-sessions-empty">
                <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">
                  No active sessions
                </td>
              </tr>
              <tr
                :for={{id, session} <- @sessions}
                id={id}
                class="hover:bg-gray-50 transition-colors"
              >
                <td class="px-6 py-4">
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-medium text-gray-900">
                      {device_label(session.user_agent)}
                    </span>
                    <span
                      :if={session.id == @current_session_id}
                      class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-blue-100 text-blue-700"
                    >
                      Current session
                    </span>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">{session.ip}</td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  {Layouts.relative_time(session.last_seen_at)} ago
                </td>
                <td class="px-6 py-4 text-right whitespace-nowrap">
                  <button
                    type="button"
                    id={"revoke-session-#{session.id}"}
                    phx-click="revoke_session"
                    phx-value-id={session.id}
                    data-confirm={revoke_confirm(session.id == @current_session_id)}
                    class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium text-rose-600 hover:bg-rose-50"
                  >
                    Sign out
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  # Crude on purpose — enough to tell devices apart without a UA library.
  defp device_label(user_agent) when is_binary(user_agent) do
    cond do
      user_agent =~ "Mobile" -> "Mobile"
      user_agent =~ "Macintosh" -> "Mac"
      user_agent =~ "Windows" -> "Windows"
      user_agent =~ "Linux" -> "Linux"
      true -> "Unknown device"
    end
  end

  defp device_label(_), do: "Unknown device"

  defp revoke_confirm(true),
    do: "This is your current session — you will be signed out of this page. Continue?"

  defp revoke_confirm(false), do: "Sign out this session?"
end
