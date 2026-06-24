defmodule EmakolaWeb.Platform.ModerationLive.Index do
  @moduledoc """
  Platform content-moderation queue: search products across all stores and take
  them down (hide from customers) or reinstate them.

  Gated by RequirePermission (:manage_stores). No DB queries during the
  disconnected render. Takedown/reinstate run with `authorize?: false` (the
  Product policy forbids actor-based calls), re-check the permission per event,
  record a platform audit entry, and notify the merchant.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Catalog
  alias Emakola.Notifications.Workers.ProductModerationNotificationWorker

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Moderation")
      |> assign(:active_nav, :moderation)
      |> assign(:search, "")
      |> assign(:filter, :all)
      |> assign(:takedown_id, nil)
      |> assign(:products, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply, socket |> assign(:search, query) |> load()}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    filter = if filter == "taken_down", do: :taken_down, else: :all
    {:noreply, socket |> assign(:filter, filter) |> load()}
  end

  def handle_event("open_takedown_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :takedown_id, id)}
  end

  def handle_event("cancel_modal", _params, socket) do
    {:noreply, assign(socket, :takedown_id, nil)}
  end

  def handle_event("confirm_takedown", %{"reason" => reason}, socket) do
    authorized(socket, fn socket ->
      reason = String.trim(reason || "")
      product = find_product(socket, socket.assigns.takedown_id)

      cond do
        is_nil(product) ->
          {:noreply, assign(socket, :takedown_id, nil)}

        reason == "" ->
          {:noreply, put_flash(socket, :error, "A reason is required.")}

        true ->
          run(socket, Catalog.take_down_product(product, %{reason: reason}, authorize?: false),
            product: product,
            event: :product_taken_down,
            reason: reason,
            flash: "Product taken down."
          )
      end
    end)
  end

  def handle_event("reinstate", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      case find_product(socket, id) do
        nil ->
          {:noreply, socket}

        product ->
          run(socket, Catalog.reinstate_product(product, %{}, authorize?: false),
            product: product,
            event: :product_reinstated,
            reason: nil,
            flash: "Product reinstated."
          )
      end
    end)
  end

  defp run(socket, {:ok, _updated}, opts) do
    product = Keyword.fetch!(opts, :product)
    event = Keyword.fetch!(opts, :event)
    reason = Keyword.get(opts, :reason)

    PlatformAudit.log(event, socket.assigns.current_user, audit_metadata(product, reason))
    ProductModerationNotificationWorker.enqueue(product.id, event)

    {:noreply,
     socket
     |> assign(:takedown_id, nil)
     |> load()
     |> put_flash(:info, Keyword.fetch!(opts, :flash))}
  end

  defp run(socket, {:error, _}, _opts) do
    {:noreply, put_flash(socket, :error, "Could not update the product.")}
  end

  defp audit_metadata(product, reason) do
    base = %{
      "product_id" => product.id,
      "product_title" => product.title,
      "store_id" => product.store_id
    }

    if reason, do: Map.put(base, "reason", reason), else: base
  end

  defp find_product(socket, id), do: Enum.find(socket.assigns.products || [], &(&1.id == id))

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_stores) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to moderate content.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket) do
    search = String.trim(socket.assigns.search)
    moderation = if socket.assigns.filter == :taken_down, do: :taken_down, else: nil

    products =
      case Catalog.list_products_for_moderation(%{search: search, moderation: moderation},
             authorize?: false
           ) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, :products, products)
  rescue
    _ -> assign(socket, :products, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Moderation</h1>
        <p class="text-sm text-gray-500 mt-1">
          Search products across all stores and take down policy violations.
        </p>
      </div>

      <div class="mb-4 flex items-center gap-3 flex-wrap">
        <form phx-change="search" class="relative flex-1 min-w-[220px] max-w-sm">
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search products by title or slug…"
            phx-debounce="300"
            class="w-full px-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"
          />
        </form>
        <div class="flex gap-1.5">
          <button
            :for={{label, value} <- [{"All", "all"}, {"Taken down", "taken_down"}]}
            type="button"
            phx-click="filter"
            phx-value-filter={value}
            class={[
              "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
              if(to_string(@filter) == value,
                do: "bg-gray-900 text-white",
                else: "bg-white text-gray-600 border border-gray-200 hover:bg-gray-50"
              )
            ]}
          >
            {label}
          </button>
        </div>
      </div>

      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
              <th class="px-6 py-3">Product</th>
              <th class="px-6 py-3">Store</th>
              <th class="px-6 py-3">Status</th>
              <th class="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr :if={is_nil(@products)}>
              <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">Loading…</td>
            </tr>
            <tr :if={@products == []}>
              <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">
                No products found
              </td>
            </tr>
            <tr :for={p <- @products || []} class="hover:bg-gray-50 transition-colors">
              <td class="px-6 py-4">
                <div class="flex items-center gap-3">
                  <img
                    :if={thumb(p)}
                    src={thumb(p)}
                    alt=""
                    class="w-10 h-10 rounded-lg object-cover bg-gray-100 shrink-0"
                  />
                  <div class="min-w-0">
                    <p class="font-medium text-gray-900 truncate">{p.title}</p>
                    <a
                      href={"/s/#{p.store && p.store.slug}/products/#{p.slug}"}
                      target="_blank"
                      class="text-xs text-blue-600 hover:text-blue-700"
                    >
                      View storefront
                    </a>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 text-sm text-gray-600">{p.store && p.store.name}</td>
              <td class="px-6 py-4">
                <span class={[
                  "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                  if(p.moderation_status == :taken_down,
                    do: "bg-red-100 text-red-700",
                    else: "bg-green-100 text-green-700"
                  )
                ]}>
                  {if p.moderation_status == :taken_down, do: "Taken down", else: "OK"}
                </span>
              </td>
              <td class="px-6 py-4 text-right">
                <button
                  :if={p.moderation_status == :ok}
                  type="button"
                  phx-click="open_takedown_modal"
                  phx-value-id={p.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-red-100 text-red-700 hover:bg-red-200"
                >
                  Take down
                </button>
                <button
                  :if={p.moderation_status == :taken_down}
                  type="button"
                  phx-click="reinstate"
                  phx-value-id={p.id}
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-green-100 text-green-700 hover:bg-green-200"
                >
                  Reinstate
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        :if={@takedown_id}
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      >
        <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl" phx-click-away="cancel_modal">
          <h3 class="text-lg font-semibold text-gray-900">Take down product</h3>
          <p class="mt-1 text-sm text-gray-500">
            The product is hidden from customers immediately. The reason is shown to the merchant.
          </p>
          <form phx-submit="confirm_takedown" class="mt-4">
            <label class="block text-sm font-medium text-gray-700">Reason (required)</label>
            <textarea
              name="reason"
              rows="3"
              class="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-blue-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
            ></textarea>
            <div class="mt-4 flex justify-end gap-2">
              <button
                type="button"
                phx-click="cancel_modal"
                class="px-3 py-1.5 rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-100"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-3 py-1.5 rounded-lg text-sm font-medium bg-gray-900 text-white hover:bg-gray-800"
              >
                Take down
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp thumb(%{images: [%{url: url} | _]}) when is_binary(url), do: url
  defp thumb(_), do: nil
end
