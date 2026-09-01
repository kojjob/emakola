defmodule EmakolaWeb.Admin.SupplyNetworkLive do
  @moduledoc """
  The Partners hub: what a merchant's supply network is doing and one door
  per Earn tool. Every event is handled in `SupplyNetworkLive.Events`,
  shared with the tool pages.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Admin.SupplyNetworkLive.{Components, Data, Events, Inputs}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(Inputs.default_assigns()) |> Data.load_all()}
  end

  @impl true
  def handle_event(event, params, socket), do: Events.handle_event(event, params, socket)

  @impl true
  def render(assigns), do: Components.page(assigns)
end
