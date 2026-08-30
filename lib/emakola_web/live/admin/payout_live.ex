defmodule EmakolaWeb.Admin.PayoutLive do
  @moduledoc """
  Merchant page to register how they get paid (SP1 — payout onboarding).

      /admin/payouts

  Captures the merchant's payout destination (mobile money or bank) onto their
  `StorePayoutAccount`. The save records the details as `:unverified`, then
  enqueues `SubaccountCreationWorker` to create the matching Paystack subaccount
  asynchronously (revenue rails, slice 1) — the gateway call never blocks the
  save and retries on transient failure. Platform fee / money movement on normal
  orders is slice 2.

  Also the merchant's full money picture (money-surfaces PR-1): accrued
  internal balance, held-by-protection, legacy (un-split) outstanding, a
  per-role accrual breakdown, and recent payout history — loaded together in
  one `assign_async` so the page never shows a mix of loaded and unloaded
  numbers, and never a misleading zero while an amount is still loading.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Payments
  alias Emakola.Payments.PaymentSplit
  alias Emakola.Payments.PayoutService
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.Workers.SubaccountCreationWorker
  alias Emakola.Stores
  alias EmakolaWeb.Helpers.Currency

  # Fixed display order for the accrual breakdown card, independent of
  # whichever roles happen to have splits.
  @role_order [:merchant, :wholesaler, :dropshipper, :credit_partner, :affiliate]

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{} = store ->
        account = load_account(store)
        store_id = store.id

        {:ok,
         socket
         |> assign(:page_title, "Payouts")
         |> assign(:active_nav, :payouts)
         |> assign(:account, account)
         |> assign(:method, current_method(account))
         |> assign(:payout_form, payout_form(account))
         |> assign(:currency, store.currency || "GHS")
         |> assign_async(:money, fn -> load_money(store_id) end)}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  # ── The money picture: accrued + held + legacy outstanding + breakdown + history ──
  #
  # One combined async — every number and row on this page comes from the same
  # load, so none of them can show a stale mix of loaded/unloaded state against
  # the others.

  defp load_money(store_id) do
    {:ok, splits} = Payments.list_payable_internal_splits(store_id, authorize?: false)

    accrued = splits |> Enum.map(&PaymentSplit.frozen_paid_amount/1) |> Enum.sum()
    nudge? = accrued > 0 and not PayoutService.momo_destination?(store_id)

    held = ProtectionHolds.held_net_total(store_id)

    legacy =
      store_id
      |> PayoutService.outstanding_payments()
      |> Enum.map(&(&1.payable_amount || &1.amount))
      |> Enum.sum()

    {:ok, history} = Payments.list_store_payouts(store_id, authorize?: false)

    {:ok,
     %{
       money: %{
         accrued: accrued,
         nudge?: nudge?,
         held: held,
         legacy: legacy,
         breakdown: breakdown_by_role(splits),
         history: history
       }
     }}
  end

  # Per-role rows for the breakdown card — count + oldest accrual age, from
  # the same splits already loaded above (zero new queries).
  defp breakdown_by_role(splits) do
    by_role = Enum.group_by(splits, & &1.role)

    @role_order
    |> Enum.filter(&Map.has_key?(by_role, &1))
    |> Enum.map(fn role ->
      group = Map.fetch!(by_role, role)
      oldest = Enum.min_by(group, & &1.inserted_at, DateTime)

      %{role: role, count: length(group), oldest_inserted_at: oldest.inserted_at}
    end)
  end

  defp role_label(:merchant), do: "Your sales"
  defp role_label(:wholesaler), do: "Resales of your stock"
  defp role_label(:dropshipper), do: "Dropship margin"
  defp role_label(:credit_partner), do: "Credit repayment"
  defp role_label(:affiliate), do: "Commission you paid"

  defp order_word(1), do: "order"
  defp order_word(_), do: "orders"

  defp format_payout_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_payout_date(_), do: "—"

  @impl true
  def handle_event("validate", %{"payout" => %{"method" => method} = params}, socket) do
    {:noreply,
     assign(socket,
       method: normalize_method(method),
       payout_form: to_form(params, as: :payout)
     )}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("save", %{"payout" => params}, socket) do
    method = normalize_method(params["method"])
    destination = build_destination(method, params)

    case validate_destination(destination) do
      :ok ->
        case persist(socket.assigns.account, socket.assigns.current_store, destination) do
          {:ok, account} ->
            SubaccountCreationWorker.enqueue(socket.assigns.current_store.id)

            {:noreply,
             socket
             |> assign(:account, account)
             |> assign(:method, method)
             |> assign(:payout_form, payout_form(account))
             |> put_flash(:info, "Payout details saved.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save. Please try again.")}
        end

      {:error, message} ->
        {:noreply,
         socket
         |> assign(method: method, payout_form: to_form(params, as: :payout))
         |> put_flash(:error, message)}
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
    <section class="max-w-[1600px] mx-auto px-4 py-8 sm:px-6">
      <.admin_page_header
        title="Get paid"
        subtitle="Tell us where to send your sales. Stored securely."
        icon="hero-banknotes"
      />

      <%!-- Money on the left, the form that changes it on the right. The page
            used to be one max-w-2xl column, which left two thirds of a laptop
            screen empty and pushed the payout history below the fold. --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
        <div class="lg:col-span-2 space-y-6">
          <.async_result :let={money} assign={@money}>
            <:loading>
              <div id="payout-money-loading" class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
                <div id="payout-tile-accrued">
                  <.money_tile
                    label="Accrued balance"
                    icon="hero-banknotes"
                    icon_class="text-emerald-600"
                    tone={:success}
                    state={:loading}
                  />
                </div>
                <div id="payout-tile-held">
                  <.money_tile
                    label="Held by Buyer Protection"
                    icon="hero-lock-closed"
                    icon_class="text-amber-600"
                    state={:loading}
                  />
                </div>
                <div id="payout-tile-legacy">
                  <.money_tile
                    label="Legacy outstanding"
                    icon="hero-clock"
                    icon_class="text-slate-600"
                    state={:loading}
                  />
                </div>
              </div>
            </:loading>
            <:failed>
              <div id="payout-money-failed" class="mb-6 space-y-3">
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                  <div id="payout-tile-accrued">
                    <.money_tile
                      label="Accrued balance"
                      icon="hero-banknotes"
                      icon_class="text-emerald-600"
                      tone={:success}
                      state={:failed}
                    />
                  </div>
                  <div id="payout-tile-held">
                    <.money_tile
                      label="Held by Buyer Protection"
                      icon="hero-lock-closed"
                      icon_class="text-amber-600"
                      state={:failed}
                    />
                  </div>
                  <div id="payout-tile-legacy">
                    <.money_tile
                      label="Legacy outstanding"
                      icon="hero-clock"
                      icon_class="text-slate-600"
                      state={:failed}
                    />
                  </div>
                </div>
                <p class="text-sm text-slate-500">
                  Couldn't load your payout numbers. Refresh the page to try again.
                </p>
              </div>
            </:failed>

            <div class="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div id="payout-tile-accrued">
                <.money_tile
                  label="Accrued balance"
                  value={Currency.format_price(money.accrued, @currency)}
                  icon="hero-banknotes"
                  icon_class="text-emerald-600"
                  tone={:success}
                />
              </div>
              <div id="payout-tile-held">
                <.money_tile
                  label="Held by Buyer Protection"
                  value={Currency.format_price(money.held, @currency)}
                  icon="hero-lock-closed"
                  icon_class="text-amber-600"
                  tone={:warning}
                />
              </div>
              <div id="payout-tile-legacy">
                <.money_tile
                  label="Legacy outstanding"
                  value={Currency.format_price(money.legacy, @currency)}
                  icon="hero-clock"
                  icon_class="text-slate-600"
                />
              </div>
            </div>

            <%!-- The nudge used to live inside the first tile's grid cell, where it
              overflowed the row and printed on top of the card below. It is a
              message about the page, not about one tile — so it spans the row. --%>
            <div
              :if={money.nudge?}
              class="mb-6 flex items-center gap-3 rounded-card border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800"
            >
              <.icon name="hero-exclamation-triangle" class="size-6 shrink-0 text-amber-600" />
              Your balance is waiting — add your mobile money number to get paid out.
            </div>

            <div
              :if={money.breakdown != []}
              id="payout-breakdown"
              class="mb-6 rounded-lg border border-slate-200 bg-white p-5"
            >
              <h2 class="mb-3 text-sm font-semibold text-slate-700">Balance breakdown</h2>
              <div
                :for={row <- money.breakdown}
                class="flex items-center justify-between border-b border-slate-100 py-2 last:border-0"
              >
                <span class="text-sm text-slate-700">{role_label(row.role)}</span>
                <span class="text-xs text-slate-500">
                  {row.count} {order_word(row.count)} · oldest {Layouts.relative_time(
                    row.oldest_inserted_at
                  )} ago
                </span>
              </div>
            </div>

            <div id="payout-history" class="mb-6">
              <h2 class="mb-3 text-sm font-semibold text-slate-700">Recent payouts</h2>
              <.empty_state
                :if={money.history == []}
                icon="hero-banknotes"
                title="No payouts yet"
                description="Once Makola issues your first payout, it'll show up here."
              />
              <div
                :if={money.history != []}
                class="overflow-x-auto rounded-lg border border-slate-200 bg-white"
              >
                <table class="min-w-full divide-y divide-slate-100">
                  <thead>
                    <tr class="text-left text-xs font-medium uppercase tracking-wide text-slate-400">
                      <th class="px-4 py-2">Date</th>
                      <th class="px-4 py-2">Amount</th>
                      <th class="px-4 py-2">Basis</th>
                      <th class="px-4 py-2">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={payout <- money.history} class="border-t border-slate-100">
                      <td class="px-4 py-3 text-sm text-slate-500">
                        {format_payout_date(payout.inserted_at)}
                      </td>
                      <td class="px-4 py-3 text-sm font-medium tabular-nums text-slate-900">
                        {Currency.format_price(payout.amount, payout.currency)}
                      </td>
                      <td class="px-4 py-3">
                        <.pill
                          classes={basis_pill_classes(payout.basis)}
                          dot={basis_pill_dot(payout.basis)}
                          label={basis_pill_label(payout.basis)}
                        />
                      </td>
                      <td class="px-4 py-3">
                        <.pill
                          classes={status_pill_classes(payout.status)}
                          dot={status_pill_dot(payout.status)}
                          label={status_pill_label(payout.status)}
                        />
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </.async_result>
        </div>

        <div class="space-y-6 lg:sticky lg:top-6">
          <.destination_notice account={@account} />

          <.form
            for={@payout_form}
            id="payout-form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-5 rounded-lg border border-slate-200 bg-white p-6"
          >
            <div>
              <.input
                field={@payout_form[:method]}
                type="select"
                label="Payout method"
                options={[{"Mobile money", "mobile_money"}, {"Bank account", "bank"}]}
                class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
              />
            </div>

            <div :if={@method == "mobile_money"} class="space-y-4">
              <div>
                <.input
                  field={@payout_form[:provider]}
                  type="select"
                  label="Provider"
                  options={[
                    {"MTN MoMo", "mtn"},
                    {"Telecel / Telecel Cash", "vodafone"},
                    {"AirtelTigo Money", "airteltigo"}
                  ]}
                  class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                />
              </div>
              <.text_field
                field={@payout_form[:number]}
                label="Mobile money number"
              />
              <.text_field
                field={@payout_form[:account_name]}
                label="Account name"
              />
            </div>

            <div :if={@method == "bank"} class="space-y-4">
              <.text_field field={@payout_form[:bank_name]} label="Bank" />
              <.text_field
                field={@payout_form[:account_number]}
                label="Account number"
              />
              <.text_field
                field={@payout_form[:account_name]}
                label="Account name"
              />
            </div>

            <button
              type="submit"
              class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
            >
              {if @account, do: "Update payout details", else: "Save payout details"}
            </button>
          </.form>
        </div>
      </div>
    </section>
    """
  end

  # ── Money tile: shares one stat_card shell across loading/failed/ok ──────

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :icon, :string, required: true
  attr :icon_class, :string, required: true
  attr :tone, :atom, default: :neutral
  attr :state, :atom, default: :ok, values: [:ok, :loading, :failed]

  defp money_tile(%{state: :loading} = assigns) do
    ~H"""
    <.stat_card label={@label} value="" tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
      <:delta>
        <div class="mt-2 h-7 w-24 animate-pulse rounded bg-slate-200" aria-hidden="true"></div>
        <span class="sr-only">Loading {@label}</span>
      </:delta>
    </.stat_card>
    """
  end

  defp money_tile(%{state: :failed} = assigns) do
    ~H"""
    <.stat_card label={@label} value="—" tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
    </.stat_card>
    """
  end

  defp money_tile(assigns) do
    ~H"""
    <.stat_card label={@label} value={@value} tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
    </.stat_card>
    """
  end

  # ── Destination notice: state-driven copy, no fixed amber string ─────────

  attr :account, :any, default: nil

  defp destination_notice(%{account: nil} = assigns) do
    ~H"""
    <div class="mb-6 rounded-lg border border-slate-200 bg-slate-50 p-4 text-sm text-slate-700">
      Add your mobile money or bank details below so we know where to send your money.
    </div>
    """
  end

  defp destination_notice(%{account: %{verification_status: :verified}} = assigns) do
    ~H"""
    <div class="mb-6 rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
      Your payout destination is verified. You'll receive payouts here once Makola enables payouts in your region.
    </div>
    """
  end

  defp destination_notice(assigns) do
    ~H"""
    <div class="mb-6 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
      Payout details saved. You'll be able to receive payouts once Makola enables payouts in your region.
    </div>
    """
  end

  # ── Shared pill shell: basis ("Gateway"/"Ledger") and status pills ───────

  attr :classes, :string, required: true
  attr :dot, :string, required: true
  attr :label, :string, required: true

  defp pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-semibold",
      @classes
    ]}>
      <span class={["h-1.5 w-1.5 rounded-full", @dot]}></span>
      {@label}
    </span>
    """
  end

  defp basis_pill_classes(:allocations), do: "bg-violet-50 text-violet-700"
  defp basis_pill_classes(_payments), do: "bg-blue-50 text-blue-700"

  defp basis_pill_dot(:allocations), do: "bg-violet-500"
  defp basis_pill_dot(_payments), do: "bg-blue-500"

  defp basis_pill_label(:allocations), do: "Ledger"
  defp basis_pill_label(_payments), do: "Gateway"

  defp status_pill_classes(:paid), do: "bg-emerald-50 text-emerald-700"
  defp status_pill_classes(:processing), do: "bg-blue-50 text-blue-700"
  defp status_pill_classes(:failed), do: "bg-rose-50 text-rose-700"
  defp status_pill_classes(:reversed), do: "bg-amber-50 text-amber-700"
  defp status_pill_classes(_pending), do: "bg-slate-100 text-slate-600"

  defp status_pill_dot(:paid), do: "bg-emerald-500"
  defp status_pill_dot(:processing), do: "bg-blue-500"
  defp status_pill_dot(:failed), do: "bg-rose-500"
  defp status_pill_dot(:reversed), do: "bg-amber-500"
  defp status_pill_dot(_pending), do: "bg-slate-400"

  defp status_pill_label(:paid), do: "Paid"
  defp status_pill_label(:processing), do: "Processing"
  defp status_pill_label(:failed), do: "Failed"
  defp status_pill_label(:reversed), do: "Reversed"
  defp status_pill_label(_pending), do: "Pending"

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true

  defp text_field(assigns) do
    ~H"""
    <.input
      field={@field}
      type="text"
      label={@label}
      class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
    />
    """
  end

  defp payout_form(account) do
    to_form(
      %{
        "method" => current_method(account),
        "provider" => dest(account, "provider") || "mtn",
        "number" => dest(account, "number") || "",
        "account_name" => dest(account, "account_name") || "",
        "bank_name" => dest(account, "bank_name") || "",
        "account_number" => dest(account, "account_number") || ""
      },
      as: :payout
    )
  end
end
