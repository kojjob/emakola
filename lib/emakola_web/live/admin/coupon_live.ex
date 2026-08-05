defmodule EmakolaWeb.Admin.CouponLive do
  @moduledoc """
  Merchant admin page for managing coupon codes.

  Supports CRUD operations on `Emakola.Marketing.Coupon` resources:
  - List coupons with status indicators
  - Create coupons with type-specific value handling
  - Toggle active/inactive inline
  - Edit existing coupons

  Money conventions:
  - Percentage: input as whole number (10 = 10%), stored as basis points (1000)
  - Fixed amount: input as cedis (20.00), stored as pesewas (2000)
  - All min/max amounts follow the same cedis-to-pesewas conversion
  """

  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns[:current_store]

    case store do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Coupons", active_nav: :coupons)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        coupons = load_coupons(store.id)

        {:ok,
         socket
         |> assign(
           page_title: "Coupons",
           active_nav: :coupons,
           store: store,
           coupons: coupons,
           show_form: false,
           editing_coupon: nil,
           form_changeset: empty_form(),
           coupon_form: coupon_form(empty_form()),
           form_errors: %{},
           discount_type: "percentage"
         )}
    end
  end

  @impl true
  def handle_event("show_create_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       editing_coupon: nil,
       form_changeset: empty_form(),
       coupon_form: coupon_form(empty_form()),
       form_errors: %{},
       discount_type: "percentage"
     )}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_coupon: nil, form_errors: %{})}
  end

  @impl true
  def handle_event("edit_coupon", %{"id" => id}, socket) do
    coupon = Enum.find(socket.assigns.coupons, &(&1.id == id))

    if coupon do
      form =
        %{
          "code" => coupon.code,
          "description" => coupon.description || "",
          "discount_type" => to_string(coupon.discount_type),
          "discount_value" => format_value_for_input(coupon.discount_type, coupon.discount_value),
          "max_discount_amount" => format_pesewas_for_input(coupon.max_discount_amount),
          "minimum_order_amount" => format_pesewas_for_input(coupon.minimum_order_amount),
          "max_uses" => if(coupon.max_uses, do: to_string(coupon.max_uses), else: ""),
          "starts_at" => format_datetime_for_input(coupon.starts_at),
          "expires_at" => format_datetime_for_input(coupon.expires_at),
          "active" => to_string(coupon.active),
          "is_public" => to_string(coupon.is_public)
        }

      {:noreply,
       assign(socket,
         show_form: true,
         editing_coupon: coupon,
         form_changeset: form,
         coupon_form: coupon_form(form),
         form_errors: %{},
         discount_type: to_string(coupon.discount_type)
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_discount_type", %{"type" => type}, socket) do
    form = Map.put(socket.assigns.form_changeset, "discount_type", type)

    form =
      if type == "free_shipping" do
        Map.merge(form, %{"discount_value" => "", "max_discount_amount" => ""})
      else
        form
      end

    {:noreply,
     assign(socket, discount_type: type, form_changeset: form, coupon_form: coupon_form(form))}
  end

  @impl true
  def handle_event("validate_form", %{"coupon" => params}, socket) do
    form = Map.merge(socket.assigns.form_changeset, params)
    {:noreply, assign(socket, form_changeset: form, coupon_form: coupon_form(form))}
  end

  @impl true
  def handle_event("save_coupon", %{"coupon" => params}, socket) do
    store = socket.assigns.store

    attrs = build_attrs(params, store.id)

    result =
      case socket.assigns.editing_coupon do
        nil ->
          Emakola.Marketing.create_coupon(attrs, authorize?: false)

        coupon ->
          Emakola.Marketing.update_coupon(coupon, Map.delete(attrs, :store_id), authorize?: false)
      end

    case result do
      {:ok, _coupon} ->
        coupons = load_coupons(store.id)
        action = if socket.assigns.editing_coupon, do: "updated", else: "created"

        {:noreply,
         socket
         |> assign(coupons: coupons, show_form: false, editing_coupon: nil, form_errors: %{})
         |> put_flash(:info, "Coupon #{action} successfully")}

      {:error, changeset} ->
        errors = extract_errors(changeset)

        {:noreply,
         socket
         |> assign(form_errors: errors)
         |> put_flash(:error, "Failed to save coupon. Check the form for errors.")}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    coupon = Enum.find(socket.assigns.coupons, &(&1.id == id))

    if coupon do
      result =
        Emakola.Marketing.update_coupon(coupon, %{active: !coupon.active}, authorize?: false)

      case result do
        {:ok, _updated} ->
          coupons = load_coupons(socket.assigns.store.id)
          status = if coupon.active, do: "deactivated", else: "activated"

          {:noreply,
           socket
           |> assign(coupons: coupons)
           |> put_flash(:info, "Coupon #{coupon.code} #{status}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update coupon")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6">
      <.admin_page_header
        title="Coupons"
        subtitle="Create and manage coupon codes for your customers"
        action_label="+ Create Coupon"
        action_event="show_create_form"
      />

      <%!-- Summary Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <.admin_card
          padding={:none}
          class="p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300"
        >
          <div class="flex items-center justify-between mb-4">
            <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Active Coupons
            </span>
            <div class="w-9 h-9 bg-primary-soft rounded-control flex items-center justify-center">
              <svg
                class="w-[18px] h-[18px] text-primary"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z"
                />
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
              </svg>
            </div>
          </div>
          <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
            {count_active(@coupons)}
          </p>
          <p class="text-xs text-slate-400 mt-2">
            {length(@coupons)} total coupons
          </p>
        </.admin_card>

        <.admin_card
          padding={:none}
          class="p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300"
        >
          <div class="flex items-center justify-between mb-4">
            <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Total Uses
            </span>
            <div class="w-9 h-9 bg-violet-50 rounded-control flex items-center justify-center">
              <svg
                class="w-[18px] h-[18px] text-violet-600"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z"
                />
              </svg>
            </div>
          </div>
          <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
            {total_uses(@coupons)}
          </p>
          <p class="text-xs text-slate-400 mt-2">
            Across all coupons
          </p>
        </.admin_card>

        <.admin_card
          padding={:none}
          class="p-5 hover:shadow-md hover:border-slate-300 transition-all duration-300"
        >
          <div class="flex items-center justify-between mb-4">
            <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Expired / Maxed
            </span>
            <div class="w-9 h-9 bg-amber-50 rounded-control flex items-center justify-center">
              <svg
                class="w-[18px] h-[18px] text-amber-600"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                />
              </svg>
            </div>
          </div>
          <p class="text-3xl font-bold text-slate-900 font-mono tracking-tight">
            {count_expired_or_maxed(@coupons)}
          </p>
          <p class="text-xs text-slate-400 mt-2">
            Inactive coupons
          </p>
        </.admin_card>
      </div>

      <%!-- Create/Edit Form --%>
      <.admin_card :if={@show_form} class="mb-8">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-lg font-bold text-slate-900">
              {if @editing_coupon, do: "Edit Coupon", else: "Create New Coupon"}
            </h2>
            <p class="text-sm text-slate-500 mt-1">Configure your coupon code settings</p>
          </div>
          <button
            phx-click="close_form"
            class="w-8 h-8 flex items-center justify-center rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <.form
          for={@coupon_form}
          id="coupon-form"
          phx-submit="save_coupon"
          phx-change="validate_form"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%!-- Code --%>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Coupon Code <span class="text-red-500">*</span>
              </label>
              <.input
                field={@coupon_form[:code]}
                type="text"
                value={@form_changeset["code"]}
                placeholder="e.g. WELCOME10"
                class={"w-full px-3.5 py-2.5 rounded-control border text-sm transition-colors uppercase placeholder:normal-case #{if @form_errors[:code], do: "border-red-300 focus:border-red-500 focus:ring-red-500", else: "border-slate-200 focus:border-emerald-500 focus:ring-emerald-500"}"}
              />
              <p :if={@form_errors[:code]} class="mt-1 text-xs text-red-600">
                {@form_errors[:code]}
              </p>
            </div>

            <%!-- Description --%>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Description
              </label>
              <.input
                field={@coupon_form[:description]}
                type="text"
                value={@form_changeset["description"]}
                placeholder="Internal note (not shown to customers)"
                class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
              />
            </div>
          </div>

          <%!-- Discount Type --%>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-3">
              Discount Type <span class="text-red-500">*</span>
            </label>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <button
                type="button"
                phx-click="set_discount_type"
                phx-value-type="percentage"
                class={"flex items-center gap-3 p-3.5 rounded-control border-2 text-left transition-all cursor-pointer #{if @discount_type == "percentage", do: "border-emerald-500 bg-emerald-50", else: "border-slate-200 hover:border-slate-300"}"}
              >
                <div class={"w-8 h-8 rounded-lg flex items-center justify-center text-sm font-bold #{if @discount_type == "percentage", do: "bg-emerald-100 text-emerald-700", else: "bg-slate-100 text-slate-500"}"}>
                  %
                </div>
                <div>
                  <p class="text-sm font-semibold text-slate-900">Percentage</p>
                  <p class="text-xs text-slate-500">e.g. 10% off</p>
                </div>
              </button>

              <button
                type="button"
                phx-click="set_discount_type"
                phx-value-type="fixed_amount"
                class={"flex items-center gap-3 p-3.5 rounded-control border-2 text-left transition-all cursor-pointer #{if @discount_type == "fixed_amount", do: "border-emerald-500 bg-emerald-50", else: "border-slate-200 hover:border-slate-300"}"}
              >
                <div class={"w-8 h-8 rounded-lg flex items-center justify-center text-sm font-bold #{if @discount_type == "fixed_amount", do: "bg-emerald-100 text-emerald-700", else: "bg-slate-100 text-slate-500"}"}>
                  GH
                </div>
                <div>
                  <p class="text-sm font-semibold text-slate-900">Fixed Amount</p>
                  <p class="text-xs text-slate-500">e.g. GH 5.00 off</p>
                </div>
              </button>

              <button
                type="button"
                phx-click="set_discount_type"
                phx-value-type="free_shipping"
                class={"flex items-center gap-3 p-3.5 rounded-control border-2 text-left transition-all cursor-pointer #{if @discount_type == "free_shipping", do: "border-emerald-500 bg-emerald-50", else: "border-slate-200 hover:border-slate-300"}"}
              >
                <div class={"w-8 h-8 rounded-lg flex items-center justify-center #{if @discount_type == "free_shipping", do: "bg-emerald-100 text-emerald-700", else: "bg-slate-100 text-slate-500"}"}>
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12"
                    />
                  </svg>
                </div>
                <div>
                  <p class="text-sm font-semibold text-slate-900">Free Shipping</p>
                  <p class="text-xs text-slate-500">Waive delivery fee</p>
                </div>
              </button>
            </div>
            <.input field={@coupon_form[:discount_type]} type="hidden" value={@discount_type} />
          </div>

          <%!-- Discount Value (hidden for free_shipping) --%>
          <div :if={@discount_type != "free_shipping"} class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Discount Value <span class="text-red-500">*</span>
              </label>
              <div class="relative">
                <.input
                  field={@coupon_form[:discount_value]}
                  type="number"
                  value={@form_changeset["discount_value"]}
                  placeholder={if @discount_type == "percentage", do: "10", else: "5.00"}
                  step={if @discount_type == "percentage", do: "1", else: "0.01"}
                  min="0"
                  max={if @discount_type == "percentage", do: "100", else: nil}
                  class={"w-full px-3.5 py-2.5 rounded-control border text-sm transition-colors #{if @form_errors[:discount_value], do: "border-red-300 focus:border-red-500 focus:ring-red-500", else: "border-slate-200 focus:border-emerald-500 focus:ring-emerald-500"}"}
                />
                <span class="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                  {if @discount_type == "percentage", do: "%", else: "GHS"}
                </span>
              </div>
              <p :if={@form_errors[:discount_value]} class="mt-1 text-xs text-red-600">
                {@form_errors[:discount_value]}
              </p>
              <p class="mt-1 text-xs text-slate-400">
                {if @discount_type == "percentage",
                  do: "Enter as whole number (10 = 10%)",
                  else: "Enter in cedis (5.00 = GH 5.00)"}
              </p>
            </div>

            <%!-- Max discount (only for percentage) --%>
            <div :if={@discount_type == "percentage"}>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Max Discount Amount
              </label>
              <div class="relative">
                <.input
                  field={@coupon_form[:max_discount_amount]}
                  type="number"
                  value={@form_changeset["max_discount_amount"]}
                  placeholder="No limit"
                  step="0.01"
                  min="0"
                  class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
                />
                <span class="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                  GHS
                </span>
              </div>
              <p class="mt-1 text-xs text-slate-400">
                Caps the discount to prevent large orders getting too much off
              </p>
            </div>
          </div>

          <%!-- Minimum Order & Max Uses --%>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Minimum Order Amount
              </label>
              <div class="relative">
                <.input
                  field={@coupon_form[:minimum_order_amount]}
                  type="number"
                  value={@form_changeset["minimum_order_amount"]}
                  placeholder="No minimum"
                  step="0.01"
                  min="0"
                  class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
                />
                <span class="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-slate-400">
                  GHS
                </span>
              </div>
              <p class="mt-1 text-xs text-slate-400">
                Enter in cedis (e.g. 50.00)
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Max Uses
              </label>
              <.input
                field={@coupon_form[:max_uses]}
                type="number"
                value={@form_changeset["max_uses"]}
                placeholder="Unlimited"
                min="1"
                step="1"
                class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
              />
              <p class="mt-1 text-xs text-slate-400">
                Leave empty for unlimited uses
              </p>
            </div>
          </div>

          <%!-- Dates --%>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Start Date
              </label>
              <.input
                field={@coupon_form[:starts_at]}
                type="datetime-local"
                value={@form_changeset["starts_at"]}
                class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
              />
              <p class="mt-1 text-xs text-slate-400">
                Leave empty to start immediately
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Expiry Date
              </label>
              <.input
                field={@coupon_form[:expires_at]}
                type="datetime-local"
                value={@form_changeset["expires_at"]}
                class="w-full px-3.5 py-2.5 rounded-control shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500 transition-colors"
              />
              <p class="mt-1 text-xs text-slate-400">
                Leave empty for no expiration
              </p>
            </div>
          </div>

          <%!-- Active Toggle --%>
          <div class="flex items-center gap-6">
            <div class="flex items-center gap-3">
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  id="coupon-active"
                  type="checkbox"
                  name={@coupon_form[:active].name}
                  value="true"
                  checked={@form_changeset["active"] == "true"}
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-slate-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-emerald-100 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary">
                </div>
              </label>
              <span class="text-sm font-medium text-slate-700">Active</span>
            </div>

            <div class="flex items-center gap-3">
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  id="coupon-is-public"
                  type="checkbox"
                  name={@coupon_form[:is_public].name}
                  value="true"
                  checked={@form_changeset["is_public"] == "true"}
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-slate-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-amber-100 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-amber-500">
                </div>
              </label>
              <div>
                <span class="text-sm font-medium text-slate-700">Show on storefront</span>
                <p class="text-xs text-slate-400">Display as a promotion banner for customers</p>
              </div>
            </div>
          </div>

          <%!-- Submit --%>
          <div class="flex items-center gap-3 pt-4 border-t border-slate-100">
            <.admin_button
              type="submit"
              class="focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2"
            >
              {if @editing_coupon, do: "Update Coupon", else: "Create Coupon"}
            </.admin_button>
            <button
              type="button"
              phx-click="close_form"
              class="px-5 py-2.5 text-sm font-medium text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-control transition-colors cursor-pointer"
            >
              Cancel
            </button>
          </div>
        </.form>
      </.admin_card>

      <%!-- Coupons Table --%>
      <.admin_card padding={:none} class="overflow-hidden">
        <div class="px-6 py-4 border-b border-slate-100">
          <h2 class="text-base font-bold text-slate-900">All Coupons</h2>
          <p class="text-xs text-slate-500 mt-0.5">{length(@coupons)} coupon codes</p>
        </div>

        <div :if={@coupons == []} class="px-6 py-16 text-center">
          <div class="w-16 h-16 bg-slate-100 rounded-card flex items-center justify-center mx-auto mb-4">
            <svg
              class="w-8 h-8 text-slate-400"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z"
              />
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
            </svg>
          </div>
          <h3 class="text-base font-semibold text-slate-900 mb-1">No coupons yet</h3>
          <p class="text-sm text-slate-500 mb-4">
            Create your first coupon code to offer discounts to your customers.
          </p>
          <.admin_button phx-click="show_create_form">
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            Create Your First Coupon
          </.admin_button>
        </div>

        <%!-- Table (desktop) / Cards (mobile) --%>
        <div :if={@coupons != []}>
          <%!-- Desktop Table --%>
          <div class="hidden md:block overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="bg-slate-50">
                  <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Code
                  </th>
                  <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Type
                  </th>
                  <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Value
                  </th>
                  <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Uses
                  </th>
                  <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Status
                  </th>
                  <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wider px-6 py-3">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr :for={coupon <- @coupons} class="hover:bg-slate-50/50 transition-colors">
                  <td class="px-6 py-4">
                    <span class="font-mono text-sm font-bold text-slate-900 bg-slate-100 px-2 py-1 rounded-lg">
                      {coupon.code}
                    </span>
                    <p :if={coupon.description} class="text-xs text-slate-500 mt-1">
                      {coupon.description}
                    </p>
                  </td>
                  <td class="px-6 py-4">
                    <span class={"inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium #{type_badge_class(coupon.discount_type)}"}>
                      {type_label(coupon.discount_type)}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-slate-700">
                    {format_discount_value(coupon)}
                  </td>
                  <td class="px-6 py-4 text-sm text-slate-700">
                    {coupon.uses_count}/{if coupon.max_uses, do: coupon.max_uses, else: "unlimited"}
                  </td>
                  <td class="px-6 py-4">
                    <span class={"inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium #{status_badge_class(coupon_status(coupon))}"}>
                      {coupon_status(coupon) |> to_string() |> String.capitalize()}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <div class="flex items-center justify-end gap-2">
                      <button
                        phx-click="toggle_active"
                        phx-value-id={coupon.id}
                        class={"inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-medium transition-colors cursor-pointer #{if coupon.active, do: "bg-warning-soft text-warning hover:bg-amber-100", else: "bg-primary-soft text-primary hover:bg-emerald-100"}"}
                      >
                        {if coupon.active, do: "Deactivate", else: "Activate"}
                      </button>
                      <button
                        phx-click="edit_coupon"
                        phx-value-id={coupon.id}
                        class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-50 text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
                      >
                        Edit
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Mobile Cards --%>
          <div class="md:hidden divide-y divide-slate-100">
            <div :for={coupon <- @coupons} class="p-4 space-y-3">
              <div class="flex items-center justify-between">
                <span class="font-mono text-sm font-bold text-slate-900 bg-slate-100 px-2 py-1 rounded-lg">
                  {coupon.code}
                </span>
                <span class={"inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium #{status_badge_class(coupon_status(coupon))}"}>
                  {coupon_status(coupon) |> to_string() |> String.capitalize()}
                </span>
              </div>

              <div class="flex items-center gap-4 text-sm text-slate-600">
                <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{type_badge_class(coupon.discount_type)}"}>
                  {type_label(coupon.discount_type)}
                </span>
                <span>{format_discount_value(coupon)}</span>
                <span>
                  {coupon.uses_count}/{if coupon.max_uses, do: coupon.max_uses, else: "unlimited"} uses
                </span>
              </div>

              <div class="flex items-center gap-2">
                <button
                  phx-click="toggle_active"
                  phx-value-id={coupon.id}
                  class={"inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-medium transition-colors cursor-pointer #{if coupon.active, do: "bg-warning-soft text-warning hover:bg-amber-100", else: "bg-primary-soft text-primary hover:bg-emerald-100"}"}
                >
                  {if coupon.active, do: "Deactivate", else: "Activate"}
                </button>
                <button
                  phx-click="edit_coupon"
                  phx-value-id={coupon.id}
                  class="inline-flex items-center px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-50 text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
                >
                  Edit
                </button>
              </div>
            </div>
          </div>
        </div>
      </.admin_card>
    </div>
    """
  end

  # ── Private Helpers ──────────────────────────────────────────

  defp load_coupons(store_id) do
    case Emakola.Marketing.list_coupons_by_store(store_id, authorize?: false) do
      {:ok, coupons} -> coupons
      _ -> []
    end
  end

  defp empty_form do
    %{
      "code" => "",
      "description" => "",
      "discount_type" => "percentage",
      "discount_value" => "",
      "max_discount_amount" => "",
      "minimum_order_amount" => "",
      "max_uses" => "",
      "starts_at" => "",
      "expires_at" => "",
      "active" => "true",
      "is_public" => "false"
    }
  end

  defp coupon_form(params), do: to_form(params, as: :coupon)

  defp build_attrs(params, store_id) do
    discount_type =
      Emakola.SafeAtom.to_atom_in(
        params["discount_type"],
        [:percentage, :fixed_amount, :free_shipping],
        :percentage
      )

    attrs = %{
      store_id: store_id,
      code: String.trim(params["code"] || ""),
      description: blank_to_nil(params["description"]),
      discount_type: discount_type,
      discount_value: parse_discount_value(discount_type, params["discount_value"]),
      max_discount_amount: parse_pesewas(params["max_discount_amount"]),
      minimum_order_amount: parse_pesewas(params["minimum_order_amount"]),
      max_uses: parse_integer(params["max_uses"]),
      starts_at: parse_datetime(params["starts_at"]),
      expires_at: parse_datetime(params["expires_at"]),
      active: params["active"] == "true",
      is_public: params["is_public"] == "true"
    }

    # Remove nil values so Ash defaults are respected
    attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_discount_value(:free_shipping, _value), do: 0

  defp parse_discount_value(:percentage, value) do
    case parse_number(value) do
      nil -> 0
      num -> round(num * 100)
    end
  end

  defp parse_discount_value(:fixed_amount, value) do
    parse_pesewas(value) || 0
  end

  defp parse_pesewas(nil), do: nil
  defp parse_pesewas(""), do: nil

  defp parse_pesewas(value) do
    case parse_number(value) do
      nil -> nil
      num -> round(num * 100)
    end
  end

  defp parse_number(nil), do: nil
  defp parse_number(""), do: nil

  defp parse_number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value <> ":00Z") do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(str), do: String.trim(str)

  defp format_value_for_input(:percentage, value) when is_integer(value) do
    to_string(div(value, 100))
  end

  defp format_value_for_input(:fixed_amount, value) when is_integer(value) do
    :erlang.float_to_binary(value / 100, decimals: 2)
  end

  defp format_value_for_input(_type, _value), do: ""

  defp format_pesewas_for_input(nil), do: ""

  defp format_pesewas_for_input(value) when is_integer(value) do
    :erlang.float_to_binary(value / 100, decimals: 2)
  end

  defp format_datetime_for_input(nil), do: ""

  defp format_datetime_for_input(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%dT%H:%M")
  end

  defp format_discount_value(coupon) do
    case coupon.discount_type do
      :percentage ->
        pct = div(coupon.discount_value, 100)
        "#{pct}% off"

      :fixed_amount ->
        cedis = :erlang.float_to_binary(coupon.discount_value / 100, decimals: 2)
        "GH#{cedis} off"

      :free_shipping ->
        "Free shipping"
    end
  end

  defp type_label(:percentage), do: "Percentage"
  defp type_label(:fixed_amount), do: "Fixed Amount"
  defp type_label(:free_shipping), do: "Free Shipping"

  defp type_badge_class(:percentage), do: "bg-blue-50 text-blue-700"
  defp type_badge_class(:fixed_amount), do: "bg-purple-50 text-purple-700"
  defp type_badge_class(:free_shipping), do: "bg-teal-50 text-teal-700"

  defp coupon_status(coupon) do
    now = DateTime.utc_now()

    cond do
      not coupon.active -> :inactive
      coupon.expires_at && DateTime.compare(coupon.expires_at, now) == :lt -> :expired
      coupon.max_uses && coupon.uses_count >= coupon.max_uses -> :maxed
      coupon.starts_at && DateTime.compare(coupon.starts_at, now) == :gt -> :scheduled
      true -> :active
    end
  end

  defp status_badge_class(:active), do: "bg-success-soft text-success"
  defp status_badge_class(:inactive), do: "bg-slate-100 text-slate-600"
  defp status_badge_class(:expired), do: "bg-danger-soft text-danger"
  defp status_badge_class(:maxed), do: "bg-warning-soft text-warning"
  defp status_badge_class(:scheduled), do: "bg-info-soft text-info"

  defp count_active(coupons) do
    Enum.count(coupons, fn c -> coupon_status(c) == :active end)
  end

  defp total_uses(coupons) do
    Enum.reduce(coupons, 0, fn c, acc -> acc + (c.uses_count || 0) end)
  end

  defp count_expired_or_maxed(coupons) do
    Enum.count(coupons, fn c -> coupon_status(c) in [:expired, :maxed, :inactive] end)
  end

  defp extract_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.reduce(errors, %{}, fn
      %{field: field, message: msg}, acc when not is_nil(field) ->
        Map.put(acc, field, msg)

      _, acc ->
        acc
    end)
  end

  defp extract_errors(_), do: %{}
end
