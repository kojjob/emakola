defmodule EmakolaWeb.Auth.VerifyLive do
  @moduledoc """
  Where a merchant lands when their address is not verified yet.

  This page exists because the alternative is a dead end: access is gated on
  verification now, so without somewhere to resend the mail, a merchant whose
  confirmation email never arrived — spam folder, a mail key that expired,
  a typo they can see but not fix — has no way back in except support.

  It tells the same story whether or not the address exists. The page needs no
  session to reach, so a truthful "no such account" would make it a lookup
  tool for who sells on Makola.
  """
  use EmakolaWeb, :live_view

  @resend_limit 3
  @resend_window_seconds 900

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Verify your email")
     |> assign(email: params["email"] || "")
     |> assign(sent?: false)}
  end

  @impl true
  def handle_event("resend", _params, socket) do
    email = socket.assigns.email

    case throttle(socket, email) do
      :ok ->
        Emakola.Accounts.resend_confirmation(email)

        {:noreply,
         socket
         |> assign(sent?: true)
         |> put_flash(:info, "Sent. Check your email — it can take a minute.")}

      :rate_limited ->
        {:noreply,
         put_flash(socket, :error, "Too many attempts. Wait a few minutes and try again.")}
    end
  end

  # Keyed on the address AND the caller, so one person hammering the button
  # cannot mail-bomb somebody else's inbox from a page that needs no login.
  defp throttle(socket, email) do
    ip =
      case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
        %{address: address} -> :inet.ntoa(address) |> to_string()
        _ -> "unknown"
      end

    case Emakola.RateLimit.check_rate(
           "resend_confirmation:#{String.downcase(email)}:#{ip}",
           @resend_limit,
           @resend_window_seconds * 1_000
         ) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> :rate_limited
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-subtle flex items-center justify-center px-4">
      <div class="w-full max-w-md rounded-card border border-border bg-surface shadow-sm p-8 flex flex-col gap-5">
        <div class="w-14 h-14 rounded-control bg-primary-soft text-primary flex items-center justify-center">
          <svg
            class="w-7 h-7"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <rect x="3" y="5" width="18" height="14" rx="2.4" />
            <path d="m3.6 6.4 8.4 6 8.4-6" />
          </svg>
        </div>

        <div class="flex flex-col gap-2">
          <h1 class="text-2xl font-extrabold tracking-tight text-text">Verify your email</h1>
          <p class="text-sm leading-relaxed text-text-muted">
            We sent a link to
            <span :if={@email != ""} class="font-semibold text-slate-700">{@email}</span>
            <span :if={@email == ""}>your email address</span>. Open it to finish signing in.
          </p>
        </div>

        <button
          phx-click="resend"
          class="min-h-12 rounded-control bg-primary hover:bg-primary-hover text-white text-[15px] font-bold transition-colors cursor-pointer"
        >
          {if @sent?, do: "Send it again", else: "Resend the email"}
        </button>

        <.link navigate={~p"/auth/login"} class="text-sm text-text-muted hover:text-slate-700">
          Back to sign in
        </.link>
      </div>
    </div>
    """
  end
end
