defmodule EmakolaWeb.StoreUnavailableLive do
  @moduledoc """
  Neutral interstitial shown when a storefront is requested for a store that
  exists but is not publicly live (suspended or blocked by the platform, or
  closed by the merchant).

  Archived and never-existed stores redirect home / 404 instead — this page
  deliberately never reveals WHY a store is unavailable.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Store unavailable — Makola",
       meta_description: "This store is currently unavailable."
     ), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div class="max-w-md text-center">
        <h1 class="text-2xl font-semibold text-gray-900">
          This store is currently unavailable
        </h1>
        <p class="mt-3 text-gray-600">
          The shop you're looking for isn't open right now. Please check back later.
        </p>
        <.link
          navigate={~p"/stores"}
          class="mt-8 inline-block rounded-lg bg-emerald-600 px-5 py-3 font-medium text-white hover:bg-emerald-700"
        >
          Browse other stores
        </.link>
      </div>
    </main>
    """
  end
end
