defmodule EmakolaWeb.Admin.PairPhoneLive do
  @moduledoc """
  The desktop half of scan-to-sign-in: shows a code, then asks the merchant to
  approve whichever phone reads it.

  The approval step is the point of this page. Displaying a code and signing in
  whoever scans it would be phishable in reverse — a merchant who scans a
  stranger's code out of habit would hand over their own account. Here the scan
  only raises a request; nothing is authenticated until the merchant, on this
  already-signed-in screen, is shown what is asking and says yes.

  The code is live for 90 seconds. A page that quietly kept showing a dead
  square would send a merchant to a phone that fails silently, so the countdown
  is on screen and expiry is a state with its own way out.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.QRComponents, only: [qr_code: 1]

  alias Emakola.Accounts.DevicePairings
  alias EmakolaWeb.QR

  @topic_prefix "device_pairing:"

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Sign in my phone", active_nav: :settings)
      |> start_pairing()

    {:ok, socket}
  end

  @impl true
  def handle_event("new_code", _params, socket), do: {:noreply, start_pairing(socket)}

  @impl true
  def handle_event("confirm", _params, socket) do
    %{pairing: pairing, current_merchant: merchant} = socket.assigns

    case DevicePairings.confirm(pairing.id, merchant.id) do
      {:ok, _confirmed} ->
        broadcast(pairing.id, :confirmed)
        {:noreply, assign(socket, stage: :confirmed)}

      {:error, reason} ->
        {:noreply, assign(socket, stage: :error, error: message_for(reason))}
    end
  end

  @impl true
  def handle_event("reject", _params, socket) do
    %{pairing: pairing, current_merchant: merchant} = socket.assigns
    DevicePairings.reject(pairing.id, merchant.id)
    broadcast(pairing.id, :rejected)

    {:noreply, assign(socket, stage: :rejected)}
  end

  # The phone scanned. Show the merchant what is asking, in the plainest terms
  # available — the browser's own description of itself.
  @impl true
  def handle_info({:scanned, scanned_by}, socket) do
    {:noreply, assign(socket, stage: :awaiting_confirmation, scanned_by: scanned_by)}
  end

  # Only the two live stages can expire. Without this guard the countdown
  # overwrites whatever is on screen when it reaches zero — including
  # :awaiting_confirmation, losing a real pending request, and :confirmed, so a
  # merchant who had just paired their phone would watch this page announce
  # "That code ran out" ninety seconds later.
  @expirable [:waiting, :awaiting_confirmation]

  def handle_info(:tick, socket) do
    cond do
      socket.assigns.stage not in @expirable ->
        {:noreply, socket}

      seconds_left(socket.assigns.expires_at) == 0 ->
        # Tell the phone too, or it waits for ever on "look at your other
        # screen" for a code that can no longer be confirmed.
        if socket.assigns.pairing, do: broadcast(socket.assigns.pairing.id, :expired)
        {:noreply, assign(socket, stage: :expired, seconds_left: 0)}

      true ->
        {:noreply, assign(socket, seconds_left: seconds_left(socket.assigns.expires_at))}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp start_pairing(socket) do
    merchant = socket.assigns.current_merchant

    case DevicePairings.issue(merchant.id) do
      {:ok, token, pairing} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Emakola.PubSub, @topic_prefix <> pairing.id)
          :timer.send_interval(1_000, self(), :tick)
        end

        assign(socket,
          pairing: pairing,
          pairing_code: %{token: token},
          expires_at: pairing.expires_at,
          seconds_left: seconds_left(pairing.expires_at),
          scanned_by: nil,
          stage: :waiting,
          error: nil
        )

      {:error, _reason} ->
        assign(socket,
          pairing: nil,
          pairing_code: nil,
          expires_at: nil,
          seconds_left: 0,
          scanned_by: nil,
          stage: :error,
          error: "Could not make a code. Try again."
        )
    end
  end

  defp broadcast(pairing_id, message) do
    Phoenix.PubSub.broadcast(Emakola.PubSub, @topic_prefix <> pairing_id, message)
  end

  defp seconds_left(nil), do: 0

  defp seconds_left(expires_at) do
    expires_at |> DateTime.diff(DateTime.utc_now()) |> max(0)
  end

  defp message_for(:expired), do: "That code ran out. Make a new one."
  defp message_for(:not_scanned), do: "No phone has scanned it yet."
  defp message_for(_reason), do: "That didn't work. Make a new code."

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto space-y-6">
      <.admin_page_header
        title="Sign in my phone"
        subtitle="Show this to your phone instead of typing a password"
        icon="hero-device-phone-mobile"
      />

      <.admin_card>
        <div :if={@stage == :waiting} class="text-center">
          <.qr_code
            id="pair-qr"
            svg={QR.pair_svg(@pairing_code)}
            caption="Scan this with your phone"
            class="mb-4"
          />
          <p id="pair-countdown" class="text-sm text-slate-500">
            Code lasts {@seconds_left} more seconds
          </p>
        </div>

        <div :if={@stage == :awaiting_confirmation} id="pair-confirm" class="text-center">
          <.icon name="hero-device-phone-mobile" class="size-10 text-primary mx-auto" />
          <h3 class="text-base font-bold text-slate-900 mt-3">A phone wants to sign in</h3>
          <p class="text-sm text-slate-600 mt-1 mb-1">{@scanned_by}</p>
          <%!-- Said plainly, because saying yes here hands over the account. --%>
          <p class="text-sm text-slate-500 mb-5">Is this your phone?</p>

          <div class="flex justify-center gap-3">
            <.admin_button id="pair-confirm-yes" phx-click="confirm">Yes, that's me</.admin_button>
            <.admin_button id="pair-confirm-no" variant={:secondary} phx-click="reject">
              No
            </.admin_button>
          </div>
        </div>

        <div :if={@stage == :confirmed} id="pair-done" class="text-center">
          <.icon name="hero-check-circle" class="size-10 text-success mx-auto" />
          <h3 class="text-base font-bold text-slate-900 mt-3">Your phone is signed in</h3>
        </div>

        <div :if={@stage == :rejected} id="pair-rejected" class="text-center">
          <.icon name="hero-x-circle" class="size-10 text-slate-400 mx-auto" />
          <h3 class="text-base font-bold text-slate-900 mt-3">Nothing was signed in</h3>
          <.admin_button class="mt-4" phx-click="new_code">Make a new code</.admin_button>
        </div>

        <div :if={@stage == :expired} id="pair-expired" class="text-center">
          <h3 class="text-base font-bold text-slate-900">That code ran out</h3>
          <p class="text-sm text-slate-600 mt-1 mb-4">Codes last 90 seconds, to keep them safe.</p>
          <.admin_button phx-click="new_code">Make a new code</.admin_button>
        </div>

        <div :if={@stage == :error} id="pair-error" class="text-center">
          <p class="text-sm text-danger mb-4">{@error}</p>
          <.admin_button phx-click="new_code">Make a new code</.admin_button>
        </div>
      </.admin_card>
    </div>
    """
  end
end
