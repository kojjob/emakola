defmodule EmakolaWeb.Platform.MerchantLive.Index do
  @moduledoc "Platform directory of all merchants with a slide-over detail drawer."
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Merchants")
     |> assign(:active_nav, :merchants)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Merchants</h1>
      <p class="text-sm text-gray-500 mt-1">Everyone building on Emakola</p>
    </div>
    """
  end
end
