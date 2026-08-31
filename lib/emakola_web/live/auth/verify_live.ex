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
     |> assign(caller: caller_ip(socket))
     |> assign(status: nil)}
  end

  # Only mount may read connect_info: asking for it inside handle_event raises,
  # which crashed this LiveView on the first tap of Resend. It remounted
  # instantly, so the page looked unchanged and the tap looked ignored.
  defp caller_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> "unknown"
    end
  end

  @impl true
  def handle_event("resend", _params, socket) do
    email = socket.assigns.email

    case throttle(socket, email) do
      :ok ->
        Emakola.Accounts.resend_confirmation(email)
        {:noreply, assign(socket, status: :sent)}

      :rate_limited ->
        {:noreply, assign(socket, status: :rate_limited)}
    end
  end

  # Keyed on the address AND the caller, so one person hammering the button
  # cannot mail-bomb somebody else's inbox from a page that needs no login.
  defp throttle(socket, email) do
    ip = socket.assigns.caller

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

        <div class="flex flex-col gap-3">
          <h1 class="text-2xl font-extrabold tracking-tight text-text">Check your email</h1>

          <%!-- The address on its own line, not inside a sentence: interpolated
                mid-sentence it produced "name@shop.com ." and broke mid-word on
                a phone. It is also the one thing here worth reading closely —
                a merchant who mistyped their address can only see it here. --%>
          <span
            :if={@email != ""}
            class="rounded-control bg-surface-subtle border border-border px-3 py-2.5 text-sm font-semibold text-slate-700 break-all"
          >
            {@email}
          </span>

          <p class="text-sm leading-relaxed text-text-muted">Tap the link we sent you.</p>
        </div>

        <div
          :if={@status == :sent}
          class="flex items-start gap-2.5 rounded-control bg-primary-soft border border-emerald-200 px-3 py-2.5"
        >
          <svg
            class="w-[18px] h-[18px] text-primary shrink-0 mt-px"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.4"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="m4.5 12.75 6 6 9-13.5" />
          </svg>
          <span class="text-[13px] font-semibold text-primary-hover">
            Sent. It can take a minute.
          </span>
        </div>

        <div
          :if={@status == :rate_limited}
          class="rounded-control bg-warning-soft border border-amber-200 px-3 py-2.5 text-[13px] font-semibold text-amber-800"
        >
          Too many tries. Wait a few minutes.
        </div>

        <button
          phx-click="resend"
          class="min-h-12 rounded-control bg-primary hover:bg-primary-hover text-white text-[15px] font-bold transition-colors cursor-pointer"
        >
          {if @status == :sent, do: "Send it again", else: "Resend the email"}
        </button>

        <.link navigate={~p"/auth/login"} class="text-sm text-text-muted hover:text-slate-700">
          Back to sign in
        </.link>
      </div>
    </div>
    """
  end
end
