defmodule EmakolaWeb.Platform.BillingLive do
  @moduledoc "Read-only platform billing overview (plans, subscriptions, invoices)."
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Billing")
     |> assign(:active_nav, :billing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Billing</h1>
      <p class="text-sm text-gray-500 mt-1">Platform plans, subscriptions & invoices</p>
    </div>
    """
  end
end
