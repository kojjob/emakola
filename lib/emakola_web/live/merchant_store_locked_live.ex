defmodule EmakolaWeb.MerchantStoreLockedLive do
  @moduledoc """
  Interstitial shown to a merchant whose store the platform has suspended,
  blocked, or archived. Reached via the `RequireActiveStore` hook. Unlike the
  public `/store-unavailable` page, this one tells the merchant WHY (they're
  entitled to the reason) and points them at support.

  Lives outside the `RequireActiveStore` hook (its own live_session) to avoid a
  redirect loop. A merchant with a live store is bounced back to the dashboard.
  """
  use EmakolaWeb, :live_view

  @locked_statuses [:suspended, :blocked, :archived]

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{status: status} when status in @locked_statuses ->
        {:ok, assign(socket, page_title: "Store unavailable"), layout: false}

      _ ->
        {:ok, redirect(socket, to: "/dashboard")}
    end
  end

  @impl true
  def render(assigns) do
    store = assigns.current_store
    assigns = assign(assigns, status: store.status, reason: store.status_reason)

    ~H"""
    <main class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div class="max-w-lg text-center">
        <h1 class="text-2xl font-semibold text-gray-900">{heading(@status)}</h1>
        <p class="mt-3 text-gray-600">{body(@status)}</p>

        <div :if={@reason} class="mt-6 rounded-lg border border-gray-200 bg-white p-4 text-left">
          <p class="text-sm font-medium text-gray-500">Reason</p>
          <p class="mt-1 text-gray-900">{@reason}</p>
        </div>

        <p class="mt-8 text-sm text-gray-500">
          Questions? Contact support at
          <a href="mailto:support@makola.io" class="font-medium text-emerald-700 hover:underline">
            support@makola.io
          </a>
        </p>
      </div>
    </main>
    """
  end

  defp heading(:archived), do: "Your store has been removed"
  defp heading(_), do: "Your store is currently unavailable"

  defp body(:suspended),
    do: "Your store has been temporarily suspended, so customers can't see it right now."

  defp body(:blocked),
    do: "Your store has been blocked and is not visible to customers."

  defp body(:archived),
    do: "Your store has been removed from Makola and is no longer accessible to customers."

  defp body(_), do: "Your store is not visible to customers right now."
end
