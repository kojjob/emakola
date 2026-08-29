defmodule EmakolaWeb.PairLive do
  @moduledoc """
  The phone half of scan-to-sign-in: what a merchant lands on after scanning.

  This page deliberately does **not** sign anyone in. Scanning raises a request
  and then waits. The whole security of the flow rests on the desktop being the
  one to say yes, so the phone's job is to ask and to say clearly that it is
  waiting on the other screen.

  It is public — it has to be, since the phone is by definition not signed in
  yet — and it authenticates nothing on its own. The token in the URL is the
  only credential, it is single-use, and it is worthless until confirmed
  elsewhere.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Accounts.DevicePairings

  @topic_prefix "device_pairing:"

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket = assign(socket, page_title: "Sign in", token: token)

    # The scan is recorded only once the socket is live, so a link preview or a
    # security scanner fetching the URL does not burn the merchant's code before
    # they ever see this page.
    if connected?(socket) do
      {:ok, register_scan(socket, token)}
    else
      {:ok, assign(socket, stage: :connecting, error: nil)}
    end
  end

  @impl true
  def handle_info(:confirmed, socket) do
    # Redirect out of LiveView on purpose: only a controller can write the
    # session cookie that actually signs this phone in.
    {:noreply, redirect(socket, to: ~p"/pair/#{socket.assigns.token}/complete")}
  end

  def handle_info(:rejected, socket) do
    {:noreply, assign(socket, stage: :rejected)}
  end

  def handle_info(:expired, socket) do
    {:noreply, assign(socket, stage: :error, error: message_for(:expired))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp register_scan(socket, token) do
    device = describe_device(get_connect_info(socket, :user_agent))

    case DevicePairings.scan(token, device) do
      {:ok, pairing} ->
        Phoenix.PubSub.subscribe(Emakola.PubSub, @topic_prefix <> pairing.id)

        Phoenix.PubSub.broadcast(
          Emakola.PubSub,
          @topic_prefix <> pairing.id,
          {:scanned, device}
        )

        assign(socket, stage: :waiting, error: nil)

      {:error, reason} ->
        assign(socket, stage: :error, error: message_for(reason))
    end
  end

  # A user-agent string is unreadable to anyone, let alone a merchant who reads
  # slowly. Reduce it to something they can match against the phone in their
  # hand: "an iPhone", "an Android phone".
  defp describe_device(nil), do: "A phone"

  defp describe_device(user_agent) when is_binary(user_agent) do
    cond do
      user_agent =~ ~r/iPhone|iPad/i -> "An iPhone"
      user_agent =~ ~r/Android/i -> "An Android phone"
      true -> "A phone"
    end
  end

  defp describe_device(_), do: "A phone"

  defp message_for(:expired), do: "That code ran out. Ask for a new one."
  defp message_for(_reason), do: "That code doesn't work. Ask for a new one."

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-6 bg-slate-50">
      <div class="w-full max-w-sm bg-white rounded-card border border-slate-200 p-8 text-center">
        <div :if={@stage == :connecting} id="pair-connecting">
          <p class="text-sm text-slate-500">One moment…</p>
        </div>

        <div :if={@stage == :waiting} id="pair-waiting">
          <.icon name="hero-computer-desktop" class="size-12 text-primary mx-auto" />
          <h1 class="text-lg font-bold text-slate-900 mt-4">Look at your other screen</h1>
          <p class="text-sm text-slate-600 mt-2">
            Tap yes there and this phone signs in.
          </p>
        </div>

        <div :if={@stage == :rejected} id="pair-refused">
          <.icon name="hero-x-circle" class="size-12 text-slate-400 mx-auto" />
          <h1 class="text-lg font-bold text-slate-900 mt-4">Not signed in</h1>
        </div>

        <div :if={@stage == :error} id="pair-failed">
          <.icon name="hero-exclamation-triangle" class="size-12 text-slate-400 mx-auto" />
          <h1 class="text-lg font-bold text-slate-900 mt-4">{@error}</h1>
        </div>
      </div>
    </div>
    """
  end
end
