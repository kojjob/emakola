defmodule EmakolaWeb.Platform.PaymentLive.Index do
  @moduledoc "Read-only platform payments & reconciliation overview."
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Payments") |> assign(:active_nav, :payments)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Payments</h1>
      <p class="text-sm text-gray-500 mt-1">Payments &amp; reconciliation across all stores</p>
    </div>
    """
  end
end
