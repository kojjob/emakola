defmodule EmakolaWeb.Admin.StoreAddressLive do
  @moduledoc """
  Merchant admin "Your storefront address" panel (SEO Phase 2).

  Lets a merchant claim a branded subdomain (`yourshop.makola.io`) for their
  store and choose whether it 301-redirects to the canonical `/s/:slug`
  subfolder (default, best for SEO) or serves the store in place.

  Branded subdomains are gated on `:store_subdomain_base`: until it's set
  (post wildcard-DNS/TLS cutover), the panel shows a "coming soon" notice so
  merchants don't claim an address that can't yet resolve.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Stores

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store
    base = Application.get_env(:emakola, :store_subdomain_base)
    domain = current_subdomain(store, socket)

    {:ok,
     assign(socket,
       page_title: "Storefront Address",
       active_nav: :settings,
       store: store,
       base: base,
       domain: domain,
       form: to_form(%{"label" => suggested_label(domain, store)}),
       error: nil
     )}
  end

  @impl true
  def handle_event("claim", %{"label" => label}, socket) do
    %{store: store, base: base} = socket.assigns
    host = "#{slugify(label)}.#{base}"

    attrs = %{store_id: store.id, host: host, type: :subdomain, primary?: true}

    case Stores.create_store_domain(attrs, actor: actor(socket)) do
      {:ok, domain} ->
        {:noreply,
         socket
         |> assign(domain: domain, error: nil)
         |> put_flash(:info, "Your storefront address is set to #{domain.host}.")}

      {:error, error} ->
        {:noreply, assign(socket, error: error_message(error))}
    end
  end

  def handle_event("toggle_serve", _params, socket) do
    domain = socket.assigns.domain

    {:ok, updated} =
      Stores.update_store_domain(domain, %{serve_in_place?: !domain.serve_in_place?},
        actor: actor(socket)
      )

    {:noreply, assign(socket, domain: updated)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold text-stone-900">Your storefront address</h1>
      <p class="mt-2 text-sm text-stone-600">
        Give your shop a branded web address. By default it sends visitors to your
        canonical store page so all your search-engine credit stays in one place.
      </p>

      <div :if={is_nil(@base)} class="mt-6 rounded-lg border border-amber-200 bg-amber-50 p-4">
        <p class="text-sm font-medium text-amber-800">Branded addresses are coming soon</p>
        <p class="mt-1 text-sm text-amber-700">
          You'll be able to claim a <span class="font-mono">yourshop</span> address here once
          we switch on custom web addresses.
        </p>
      </div>

      <div :if={@base} class="mt-6 space-y-6">
        <div :if={@domain} class="rounded-lg border border-stone-200 bg-white p-4">
          <p class="text-sm text-stone-500">Your current address</p>
          <p class="mt-1 font-mono text-lg text-stone-900">{@domain.host}</p>

          <div class="mt-4 flex items-center gap-3">
            <button
              type="button"
              phx-click="toggle_serve"
              class={[
                "relative inline-flex h-6 w-11 items-center rounded-full transition",
                @domain.serve_in_place? && "bg-emerald-600",
                !@domain.serve_in_place? && "bg-stone-300"
              ]}
              role="switch"
              aria-checked={to_string(@domain.serve_in_place?)}
            >
              <span class={[
                "inline-block h-4 w-4 transform rounded-full bg-white transition",
                @domain.serve_in_place? && "translate-x-6",
                !@domain.serve_in_place? && "translate-x-1"
              ]} />
            </button>
            <span class="text-sm text-stone-700">
              {if @domain.serve_in_place?,
                do: "Showing your shop on this address",
                else: "Redirecting to your main store page (recommended)"}
            </span>
          </div>
        </div>

        <.form for={@form} phx-submit="claim" class="space-y-3">
          <label class="block text-sm font-medium text-stone-700">
            {if @domain, do: "Change your address", else: "Claim your address"}
          </label>
          <div class="flex items-center">
            <input
              type="text"
              name="label"
              value={@form[:label].value}
              class="w-full rounded-l-lg border border-stone-300 px-3 py-2 font-mono text-sm focus:border-emerald-500 focus:ring-emerald-500"
              placeholder="yourshop"
            />
            <span class="rounded-r-lg border border-l-0 border-stone-300 bg-stone-50 px-3 py-2 font-mono text-sm text-stone-500">
              .{@base}
            </span>
          </div>

          <p :if={@error} class="text-sm text-red-600">{@error}</p>

          <button
            type="submit"
            class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
          >
            {if @domain, do: "Update address", else: "Claim address"}
          </button>
        </.form>
      </div>
    </div>
    """
  end

  # -- helpers --

  defp actor(socket), do: socket.assigns[:current_user] || socket.assigns[:current_merchant]

  # Reading the authenticated merchant's own current_store's domains is
  # inherently scoped to their store, so authorize?: false is safe here (the
  # StoreDomain read policy is tenant-based and this resource is non-tenant).
  # Mutations below still go through the actor policy.
  defp current_subdomain(store, _socket) do
    case Stores.list_store_domains(store.id, authorize?: false) do
      {:ok, domains} -> Enum.find(domains, &(&1.type == :subdomain))
      _ -> nil
    end
  end

  defp suggested_label(nil, store), do: store.slug

  defp suggested_label(domain, _store), do: domain.host |> String.split(".") |> List.first()

  defp slugify(label) do
    label
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]+/, "-")
    |> String.trim("-")
  end

  defp error_message(error) do
    case error do
      %Ash.Error.Invalid{errors: [first | _]} -> Exception.message(first)
      other -> Exception.message(other)
    end
  end
end
