defmodule EmakolaWeb.Storefront.AccountDownloadsLive do
  @moduledoc """
  Customer's digital downloads page (`/s/:slug/account/downloads`).

  Lists every `Emakola.Fulfillment.DownloadGrant` belonging to the
  current customer, most recent first. Each row renders:

    * file name and human-readable size
    * a status badge derived at render time (Active / Expired /
      Limit reached) — state is never written back to the DB
    * the downloads-used line ("3 of 5" or "3 downloads")
    * a download link to the `DownloadController`, disabled when the
      grant is not currently downloadable

  Auth: redirects to /login if `@current_customer` is nil (the
  `ResolveCustomer` on_mount hook in the storefront live_session sets
  this).
  """
  use EmakolaWeb, :live_view

  @max_grants 50

  @impl true
  def mount(%{"store_slug" => slug}, _session, socket) do
    case socket.assigns[:current_customer] do
      nil ->
        {:ok,
         socket
         |> put_flash(:info, "Please sign in to view your downloads")
         |> redirect(to: "/@#{slug}/login")}

      customer ->
        store = socket.assigns.store

        {:ok,
         socket
         |> assign(:page_title, "My Downloads - #{store.name}")
         |> assign(:cart_count, 0)
         |> assign(:grants, load_grants(customer.id, store.id))}
    end
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :downloads) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Downloads.render(assigns)
    end
  end

  # ── Data loading ────────────────────────────────────────────────

  defp load_grants(customer_id, store_id) do
    Emakola.Fulfillment.DownloadGrant
    |> Ash.Query.for_read(:list_by_customer, %{customer_id: customer_id, store_id: store_id})
    |> Ash.Query.limit(@max_grants)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end
end
