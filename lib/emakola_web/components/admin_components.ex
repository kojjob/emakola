defmodule EmakolaWeb.AdminComponents do
  @moduledoc """
  Shared admin UI primitives — page headers, status badges, empty states.

  These are extracted from repeated inline markup across admin LiveViews
  (`product_live/index`, `order_live/{index,show}`, `customer_live/index`,
  `coupon_live`, `inventory_live`, etc.) so call sites no longer reinvent
  the title-row, status pill, and empty-state shapes.
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1]

  # ─────────────────────────────────────────────────────────────────────
  # admin_page_header/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the standard admin page header — title, optional subtitle, and
  optional right-side action.

  An action can be either a navigation link (`action_path`) or an event
  button (`action_event`). For richer right-side content use the inner
  block slot.

  ## Examples

      <.admin_page_header title="Products" subtitle="Manage your catalog"
                          action_label="+ New Product"
                          action_path={~p"/admin/products/new"} />

      <.admin_page_header title="Orders">
        <.search_input ... />
      </.admin_page_header>
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :action_label, :string, default: nil
  attr :action_path, :string, default: nil
  attr :action_event, :string, default: nil

  slot :inner_block

  def admin_page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-slate-500 mt-1">{@subtitle}</p>
      </div>

      <div class="flex items-center gap-3">
        <.link
          :if={@action_label && @action_path}
          href={@action_path}
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emakola-gold text-white text-sm font-semibold rounded-xl hover:bg-amber-600 transition-colors cursor-pointer"
        >
          {@action_label}
        </.link>

        <button
          :if={@action_label && @action_event && !@action_path}
          type="button"
          phx-click={@action_event}
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emakola-gold text-white text-sm font-semibold rounded-xl hover:bg-amber-600 transition-colors cursor-pointer"
        >
          {@action_label}
        </button>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # status_pill/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a colour-coded status pill.

  Variant determines the colour mapping:

  - `:order`     — pending, confirmed, processing, shipped, delivered, cancelled
  - `:payment`   — pending, success, failed, refunded
  - `:delivery`  — same colour family as :order with shipping-specific labels
  - `:product`   — active, draft, archived

  Status accepts both atoms and strings; unknown values fall back to slate.

  ## Examples

      <.status_pill status={@order.status} variant={:order} />
      <.status_pill status="pending" variant={:payment} />
  """
  attr :status, :any, required: true
  attr :variant, :atom, default: :order, values: [:order, :payment, :delivery, :product]

  def status_pill(assigns) do
    status_atom = normalise_status(assigns.status)
    color = status_color(assigns.variant, status_atom)

    assigns =
      assigns
      |> assign(:status_atom, status_atom)
      |> assign(:color_classes, color)

    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize",
      @color_classes
    ]}>
      {humanise(@status_atom)}
    </span>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # empty_state/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the standard "no items yet" empty state — icon, title, optional
  description, optional action link.

  ## Examples

      <.empty_state title="No orders yet"
                    description="When customers place orders they'll appear here" />

      <.empty_state title="No products"
                    icon="hero-cube"
                    action_label="Add product"
                    action_path={~p"/admin/products/new"} />
  """
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :action_label, :string, default: nil
  attr :action_path, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center text-center py-16 px-6 bg-white border border-dashed border-slate-200 rounded-2xl">
      <div class="w-16 h-16 rounded-2xl bg-slate-50 flex items-center justify-center mb-4">
        <.icon name={@icon} class="w-8 h-8 text-slate-400" />
      </div>
      <h3 class="text-base font-semibold text-slate-900">{@title}</h3>
      <p :if={@description} class="text-sm text-slate-500 mt-1 max-w-md">{@description}</p>
      <.link
        :if={@action_label && @action_path}
        href={@action_path}
        class="inline-flex items-center gap-2 mt-5 px-4 py-2.5 bg-emakola-gold text-white text-sm font-semibold rounded-xl hover:bg-amber-600 transition-colors cursor-pointer"
      >
        {@action_label}
      </.link>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Internals
  # ─────────────────────────────────────────────────────────────────────

  # Normalise a status to an atom WITHOUT String.to_atom (Iron Law:
  # never `to_atom` user input — atom-exhaustion DoS). Fall back to the
  # original value for unknown strings; status_color/2 handles unknowns.
  defp normalise_status(status) when is_atom(status), do: status

  defp normalise_status(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    ArgumentError -> status
  end

  defp normalise_status(other), do: other

  # ── Order statuses ─────────────────────────────────────────────────
  defp status_color(:order, :pending), do: "bg-amber-50 text-amber-700"
  defp status_color(:order, :confirmed), do: "bg-blue-50 text-blue-700"
  defp status_color(:order, :processing), do: "bg-indigo-50 text-indigo-700"
  defp status_color(:order, :shipped), do: "bg-purple-50 text-purple-700"
  defp status_color(:order, :delivered), do: "bg-emerald-50 text-emerald-700"
  defp status_color(:order, :cancelled), do: "bg-red-50 text-red-700"
  defp status_color(:order, :refunded), do: "bg-slate-50 text-slate-600"

  # ── Payment statuses ───────────────────────────────────────────────
  defp status_color(:payment, :pending), do: "bg-amber-50 text-amber-700"
  defp status_color(:payment, :success), do: "bg-emerald-50 text-emerald-700"
  defp status_color(:payment, :failed), do: "bg-red-50 text-red-700"
  defp status_color(:payment, :refunded), do: "bg-slate-50 text-slate-600"

  # ── Delivery statuses (alias of order) ─────────────────────────────
  defp status_color(:delivery, status), do: status_color(:order, status)

  # ── Product statuses ───────────────────────────────────────────────
  defp status_color(:product, :active), do: "bg-emerald-50 text-emerald-700"
  defp status_color(:product, :published), do: "bg-emerald-50 text-emerald-700"
  defp status_color(:product, :draft), do: "bg-slate-100 text-slate-700"
  defp status_color(:product, :archived), do: "bg-slate-200 text-slate-600"

  # ── Default ────────────────────────────────────────────────────────
  defp status_color(_variant, _status), do: "bg-slate-50 text-slate-700"

  defp humanise(atom) when is_atom(atom), do: atom |> Atom.to_string() |> String.replace("_", " ")
  defp humanise(other), do: to_string(other)
end
