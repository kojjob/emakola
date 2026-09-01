defmodule EmakolaWeb.Admin.SupplyToolLive do
  @moduledoc """
  The Earn tools workbench behind the Partners hub: every tool section on
  one page, reached from the hub's doors by anchor. Same data and the same
  events as the hub, so a merchant can act here and see it on the hub.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Admin.SupplyNetworkLive.{Components, Data, Events, Inputs}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(Inputs.default_assigns())
     |> assign(:page_title, "Earn tools")
     |> Data.load_all()}
  end

  @impl true
  def handle_event(event, params, socket), do: Events.handle_event(event, params, socket)

  @impl true
  def render(assigns), do: Components.workbench(assigns)
end
