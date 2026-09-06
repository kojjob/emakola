defmodule EmakolaWeb.Hooks.CollectTransport do
  @moduledoc """
  LiveView on_mount hook that garbage-collects the WebSocket transport shortly
  after each connected mount.

  Joining a LiveView makes the transport process JSON-encode the whole first
  render. That burst leaves 250 to 650 KB of garbage on a process that then
  sits idle, and the BEAM only collects a process when it allocates. A shopper
  browsing page to page repeats the burst on every navigation, so a periodic
  sweep (`EmakolaWeb.IdleConnectionSweeper`) cannot keep up with churn: at 200
  shoppers moving every few seconds that is tens of MB of garbage a second.

  This hook asks the LiveView process to collect its own transport 1.5 seconds
  after mount, once the join reply has been encoded and sent. Collecting a
  process with a few KB live costs tens of microseconds. Applied to every
  LiveView through `EmakolaWeb.live_view/0`.
  """

  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  @delay_ms 1_500

  @doc "How long after mount the transport is collected, in milliseconds."
  @spec delay_ms() :: pos_integer()
  def delay_ms, do: @delay_ms

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), {__MODULE__, :collect}, @delay_ms)
      {:cont, attach_hook(socket, __MODULE__, :handle_info, &collect/2)}
    else
      {:cont, socket}
    end
  end

  @doc false
  def collect({__MODULE__, :collect}, socket) do
    if is_pid(socket.transport_pid) and Process.alive?(socket.transport_pid) do
      :erlang.garbage_collect(socket.transport_pid)
    end

    {:halt, socket}
  end

  def collect(_message, socket), do: {:cont, socket}
end
