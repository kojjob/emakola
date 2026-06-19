defmodule EmakolaWeb.Admin.PayoutsLive do
  @moduledoc """
  SP1 — lets a merchant connect a Mobile Money payout destination so their store
  can receive dropship split settlements. Connecting creates a verified gateway
  subaccount; until then the store falls back to the manual supplier ledger.
  """
  use EmakolaWeb, :live_view

  @providers [
    {"MTN MoMo", "mtn"},
    {"Vodafone Cash", "vodafone"},
    {"AirtelTigo Money", "airteltigo"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Payouts",
        active_nav: :payouts,
        store: store,
        providers: @providers
      )
      |> load_payout_account()

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_payout", %{"payout" => params}, socket) do
    store = socket.assigns.store

    attrs = %{
      provider: params["provider"],
      number: String.trim(params["number"] || ""),
      account_name: String.trim(params["account_name"] || "")
    }

    case Emakola.Stores.PayoutOnboarding.connect_momo(store, attrs) do
      {:ok, account} ->
        {:noreply,
         socket
         |> assign(payout_account: account)
         |> put_flash(
           :info,
           "Payout account verified — your store can now receive split settlements."
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> load_payout_account()
         |> put_flash(
           :error,
           "Could not verify the payout account. Check the details and try again."
         )}
    end
  end

  defp load_payout_account(socket) do
    account =
      case Emakola.Stores.get_payout_account(socket.assigns.store.id,
             not_found_error?: false,
             authorize?: false
           ) do
        {:ok, account} -> account
        _ -> nil
      end

    assign(socket, :payout_account, account)
  end

  defp verified?(%{verification_status: :verified}), do: true
  defp verified?(_), do: false

  defp provider_label(value) do
    Enum.find_value(@providers, value, fn {label, v} -> if v == value, do: label end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <div>
        <div class="flex items-center gap-2 mb-1">
          <.link navigate={~p"/admin/settings"} class="text-slate-400 hover:text-slate-600">
            <.icon name="hero-arrow-left" class="size-4" />
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Payouts</h1>
        </div>
        <p class="text-sm text-slate-500">
          Connect a Mobile Money account so customer payments for dropshipped items are paid
          directly to you and your suppliers — split automatically, never pooled in one account.
        </p>
      </div>

      <%!-- Status --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <div class="flex items-center justify-between">
          <h3 class="text-base font-bold text-slate-900">Payout status</h3>
          <span
            :if={verified?(@payout_account)}
            class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 text-xs font-semibold"
          >
            <.icon name="hero-check-badge" class="size-4" /> Verified
          </span>
          <span
            :if={!verified?(@payout_account)}
            class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-slate-100 text-slate-600 text-xs font-semibold"
          >
            <.icon name="hero-exclamation-circle" class="size-4" /> Not connected
          </span>
        </div>

        <div :if={@payout_account} class="mt-4 text-sm text-slate-600 space-y-1">
          <p>
            <span class="font-medium text-slate-800">
              {provider_label(@payout_account.payout_destination["provider"])}
            </span>
            — {@payout_account.payout_destination["number"]}
          </p>
          <p :if={@payout_account.payout_destination["account_name"] not in [nil, ""]}>
            Account name: {@payout_account.payout_destination["account_name"]}
          </p>
        </div>
      </div>

      <%!-- Connect form --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h3 class="text-base font-bold text-slate-900 mb-5">
          {if @payout_account, do: "Update payout account", else: "Connect Mobile Money"}
        </h3>

        <.form for={%{}} as={:payout} id="payout-form" phx-submit="connect_payout" class="space-y-5">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Provider</label>
              <select
                name="payout[provider]"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              >
                <option
                  :for={{label, value} <- @providers}
                  value={value}
                  selected={
                    @payout_account && @payout_account.payout_destination["provider"] == value
                  }
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">MoMo number</label>
              <input
                type="text"
                name="payout[number]"
                value={@payout_account && @payout_account.payout_destination["number"]}
                placeholder="0240000000"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Account name</label>
              <input
                type="text"
                name="payout[account_name]"
                value={@payout_account && @payout_account.payout_destination["account_name"]}
                placeholder="Registered MoMo name"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
          </div>

          <div class="flex justify-end pt-2">
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" />
              {if @payout_account, do: "Update payout account", else: "Connect payout account"}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
