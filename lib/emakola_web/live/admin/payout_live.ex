defmodule EmakolaWeb.Admin.PayoutLive do
  @moduledoc """
  Merchant page to register how they get paid (SP1 — payout onboarding).

      /admin/payouts

  Captures the merchant's payout destination (mobile money or bank) onto their
  `StorePayoutAccount`. This is the path-independent slice: it stores the
  details only — it does NOT create a Paystack subaccount, apply a platform fee,
  or move money (those settlement pieces await the Paystack-Ghana MoMo ops
  decision). `verification_status` stays `:unverified` here.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Stores

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{} = store ->
        account = load_account(store)

        {:ok,
         socket
         |> assign(:page_title, "Payouts")
         |> assign(:active_nav, :payouts)
         |> assign(:account, account)
         |> assign(:method, current_method(account))}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("validate", %{"payout" => %{"method" => method}}, socket) do
    {:noreply, assign(socket, :method, normalize_method(method))}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("save", %{"payout" => params}, socket) do
    method = normalize_method(params["method"])
    destination = build_destination(method, params)

    case validate_destination(destination) do
      :ok ->
        case persist(socket.assigns.account, socket.assigns.current_store, destination) do
          {:ok, account} ->
            {:noreply,
             socket
             |> assign(:account, account)
             |> assign(:method, method)
             |> put_flash(:info, "Payout details saved.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save. Please try again.")}
        end

      {:error, message} ->
        {:noreply, socket |> assign(:method, method) |> put_flash(:error, message)}
    end
  end

  # ── Persistence ─────────────────────────────────────────────────

  defp persist(nil, store, destination) do
    Stores.create_payout_account(%{store_id: store.id, payout_destination: destination},
      authorize?: false
    )
  end

  defp persist(account, _store, destination) do
    Stores.update_payout_account(account, %{payout_destination: destination}, authorize?: false)
  end

  defp load_account(store) do
    case Stores.get_payout_account(store.id, authorize?: false, not_found_error?: false) do
      {:ok, account} -> account
      _ -> nil
    end
  end

  # ── Destination building / validation (kept as a string-keyed jsonb map) ──

  defp build_destination("bank", p) do
    %{
      "method" => "bank",
      "bank_name" => trim(p["bank_name"]),
      "account_number" => trim(p["account_number"]),
      "account_name" => trim(p["account_name"])
    }
  end

  defp build_destination(_mobile_money, p) do
    %{
      "method" => "mobile_money",
      "provider" => normalize_provider(p["provider"]),
      "number" => trim(p["number"]),
      "account_name" => trim(p["account_name"])
    }
  end

  defp validate_destination(%{"method" => "bank"} = d) do
    if blank?(d["bank_name"]) or blank?(d["account_number"]) or blank?(d["account_name"]),
      do: {:error, "Please fill in every field."},
      else: :ok
  end

  defp validate_destination(%{"method" => "mobile_money"} = d) do
    if blank?(d["number"]) or blank?(d["account_name"]),
      do: {:error, "Please fill in every field."},
      else: :ok
  end

  defp normalize_method("bank"), do: "bank"
  defp normalize_method(_), do: "mobile_money"

  defp normalize_provider(p) when p in ["mtn", "vodafone", "airteltigo"], do: p
  defp normalize_provider(_), do: "mtn"

  defp trim(nil), do: ""
  defp trim(value) when is_binary(value), do: String.trim(value)

  defp blank?(value), do: trim(value) == ""

  defp current_method(%{payout_destination: %{"method" => "bank"}}), do: "bank"
  defp current_method(_), do: "mobile_money"

  defp dest(%{payout_destination: %{} = d}, key), do: d[key]
  defp dest(_account, _key), do: nil

  # ── Render ──────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <header class="mb-6">
        <h1 class="text-2xl font-semibold text-slate-900">Get paid</h1>
        <p class="mt-1 text-sm text-slate-500">
          Tell us where to send your sales. Stored securely.
        </p>
      </header>

      <div
        :if={@account}
        class="mb-6 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800"
      >
        Payout details saved. You'll be able to receive payouts once Makola enables payouts in your region.
      </div>

      <form
        id="payout-form"
        phx-submit="save"
        phx-change="validate"
        class="space-y-5 rounded-lg border border-slate-200 bg-white p-6"
      >
        <div>
          <label class="block text-sm font-medium text-slate-700">Payout method</label>
          <select
            name="payout[method]"
            class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
          >
            <option value="mobile_money" selected={@method == "mobile_money"}>Mobile money</option>
            <option value="bank" selected={@method == "bank"}>Bank account</option>
          </select>
        </div>

        <div :if={@method == "mobile_money"} class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700">Provider</label>
            <select
              name="payout[provider]"
              class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
            >
              <option value="mtn" selected={dest(@account, "provider") == "mtn"}>MTN MoMo</option>
              <option value="vodafone" selected={dest(@account, "provider") == "vodafone"}>
                Telecel / Vodafone Cash
              </option>
              <option value="airteltigo" selected={dest(@account, "provider") == "airteltigo"}>
                AirtelTigo Money
              </option>
            </select>
          </div>
          <.text_field
            name="payout[number]"
            label="Mobile money number"
            value={dest(@account, "number")}
          />
          <.text_field
            name="payout[account_name]"
            label="Account name"
            value={dest(@account, "account_name")}
          />
        </div>

        <div :if={@method == "bank"} class="space-y-4">
          <.text_field name="payout[bank_name]" label="Bank" value={dest(@account, "bank_name")} />
          <.text_field
            name="payout[account_number]"
            label="Account number"
            value={dest(@account, "account_number")}
          />
          <.text_field
            name="payout[account_name]"
            label="Account name"
            value={dest(@account, "account_name")}
          />
        </div>

        <button
          type="submit"
          class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {if @account, do: "Update payout details", else: "Save payout details"}
        </button>
      </form>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, default: nil

  defp text_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-slate-700">{@label}</label>
      <input
        type="text"
        name={@name}
        value={@value}
        class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
      />
    </div>
    """
  end
end
