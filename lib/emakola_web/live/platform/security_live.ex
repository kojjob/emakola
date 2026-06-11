defmodule EmakolaWeb.Platform.SecurityLive do
  @moduledoc """
  Self-service security page for platform staff: own 2FA status with
  code-gated rotation, and own active sessions with per-device sign-out.

  Authorization model: any staff may mount (live_session hooks). Every
  mutating event acts only on the current user's own data — session ids
  from the DOM are re-fetched and ownership-checked against the current
  user, and rotating 2FA first requires (and consumes, via
  `record_totp_use`) a valid CURRENT code, so a captured code cannot be
  replayed to start a second rotation.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Platform.SecurityComponents

  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.UserSession

  @rate_limit 5
  @rate_window_ms 60_000
  @rate_limited_error "Too many attempts. Please try again in a minute."

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Security")
      |> assign(:active_nav, :security)
      |> reset_rotation()

    # No DB queries in disconnected mount — render a loading shell first.
    socket =
      if connected?(socket) do
        load_sessions(socket)
      else
        assign(socket, :sessions, nil)
      end

    {:ok, socket}
  end

  # ── 2FA rotation ────────────────────────────────────────────────

  @impl true
  def handle_event("start_rotation", _params, socket) do
    if socket.assigns.current_user.totp_secret do
      {:noreply, assign(socket, rotation_step: :verify, rotation_error: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_rotation", _params, socket) do
    {:noreply, reset_rotation(socket)}
  end

  def handle_event("verify_rotation_code", %{"totp" => %{"code" => code}}, socket) do
    # Shared bucket with login — caps total guesses against one user's TOTP secret.
    case Emakola.RateLimit.check_rate(
           "platform_totp:#{socket.assigns.current_user.id}",
           @rate_limit,
           @rate_window_ms
         ) do
      {:deny, _retry_after} ->
        {:noreply, assign(socket, rotation_step: :verify, rotation_error: @rate_limited_error)}

      {:allow, _count} ->
        verify_rotation_code(code, socket)
    end
  end

  def handle_event("confirm_rotation_code", %{"totp" => %{"code" => code}}, socket) do
    case socket.assigns.pending_secret do
      nil ->
        {:noreply, reset_rotation(socket)}

      secret ->
        # setup_totp validates the new code against the new secret and
        # overwrites totp_secret — rotation complete (audits :totp_enabled).
        socket.assigns.current_user
        |> Ash.Changeset.for_update(:setup_totp, %{secret: secret, code: code},
          actor: socket.assigns.current_user
        )
        |> Ash.update(authorize?: false)
        |> case do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(:current_user, user)
             |> reset_rotation()
             |> put_flash(:info, "Two-factor authentication rotated.")}

          {:error, _} ->
            {:noreply, assign(socket, :rotation_error, "Invalid code")}
        end
    end
  end

  # ── Sessions ────────────────────────────────────────────────────

  def handle_event("revoke_session", %{"id" => id}, socket) do
    # Ownership check: re-fetch by id and compare user_id — never trust
    # the DOM. Revoking the CURRENT session is allowed: the disconnect
    # broadcast kills this very LiveView and the user lands back on
    # /platform/login on the reconnect attempt.
    with {:ok, %UserSession{} = session} <- Ash.get(UserSession, id, authorize?: false),
         true <- session.user_id == socket.assigns.current_user.id,
         {:ok, _revoked} <- Sessions.revoke(session) do
      {:noreply, socket |> load_sessions() |> put_flash(:info, "Session signed out.")}
    else
      _ -> {:noreply, socket}
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp verify_rotation_code(code, socket) do
    # Re-fetch the user: totp_last_used_at must be fresh for the since:
    # replay guard to hold across events and tabs.
    user = reload_current_user(socket)

    if TOTP.valid_code?(user.totp_secret, code, since: user.totp_last_used_at) do
      # Consume the code BEFORE showing the new secret — the same current
      # code must not be able to start a second rotation. Consumption is
      # load-bearing for the replay guard, so a failure aborts the rotation.
      case user
           |> Ash.Changeset.for_update(:record_totp_use, %{}, actor: user)
           |> Ash.update(authorize?: false) do
        {:ok, user} ->
          secret = TOTP.generate_secret()
          uri = TOTP.otpauth_uri(to_string(user.email), secret)

          {:noreply,
           assign(socket,
             current_user: user,
             rotation_step: :confirm,
             rotation_error: nil,
             pending_secret: secret,
             # Safe to mark raw: EQRCode emits pure geometry; no user text in the markup
             qr_svg: Phoenix.HTML.raw(TOTP.qr_svg(uri)),
             otpauth_secret_base32: Base.encode32(secret, padding: false)
           )}

        {:error, _} ->
          {:noreply, assign(socket, :rotation_error, "Something went wrong. Please try again.")}
      end
    else
      {:noreply, assign(socket, :rotation_error, "Invalid code")}
    end
  end

  defp load_sessions(socket) do
    case Sessions.list_active_for_user(socket.assigns.current_user.id) do
      {:ok, sessions} -> assign(socket, :sessions, sessions)
      {:error, _} -> assign(socket, :sessions, [])
    end
  end

  defp reset_rotation(socket) do
    assign(socket,
      rotation_step: :status,
      rotation_error: nil,
      pending_secret: nil,
      qr_svg: nil,
      otpauth_secret_base32: nil
    )
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> socket.assigns.current_user
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.security_page
      current_user={@current_user}
      rotation_step={@rotation_step}
      rotation_error={@rotation_error}
      qr_svg={@qr_svg}
      otpauth_secret_base32={@otpauth_secret_base32}
      sessions={@sessions}
      current_session_id={@current_session_id}
    />
    """
  end
end
