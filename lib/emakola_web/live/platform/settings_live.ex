defmodule EmakolaWeb.Platform.SettingsLive do
  @moduledoc "Platform-level feature flag management (project owner only)."
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:active_nav, :settings)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
      <p class="text-sm text-gray-500 mt-1">Platform feature flags</p>
    </div>
    """
  end
end
