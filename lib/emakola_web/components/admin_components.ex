defmodule EmakolaWeb.AdminComponents do
  @moduledoc """
  Shared admin UI primitives — page headers, status badges, stat tiles,
  table toolbars, empty states.

  These are extracted from repeated inline markup across admin LiveViews
  (`product_live/index`, `order_live/{index,show}`, `customer_live/index`,
  `coupon_live`, `inventory_live`, etc.) so call sites no longer reinvent
  the title-row, status badge, stat-tile, toolbar, and empty-state shapes.
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [icon: 1, input: 1]

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
    <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6 pt-2">
      <div>
        <h1 class="text-2xl sm:text-3xl font-bold text-text">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-text-muted mt-1">{@subtitle}</p>
      </div>

      <div class="flex items-center gap-3">
        <.link
          :if={@action_label && @action_path}
          href={@action_path}
          class={primary_action_classes()}
        >
          {@action_label}
        </.link>

        <.admin_button :if={@action_label && @action_event && !@action_path} phx-click={@action_event}>
          {@action_label}
        </.admin_button>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # admin_button/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the canonical admin button on semantic design tokens.

  Variants:

  - `:primary`   — emerald action button (default)
  - `:secondary` — bordered surface button for neutral actions
  - `:danger`    — destructive actions

  ## Examples

      <.admin_button phx-click="save">Save changes</.admin_button>
      <.admin_button variant={:secondary} phx-click="cancel">Cancel</.admin_button>
      <.admin_button variant={:danger} size={:sm} phx-click="delete">Delete</.admin_button>
      <.admin_button type="submit" disabled={!@form.source.valid?}>Create</.admin_button>
  """
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :danger]
  attr :size, :atom, default: :md, values: [:md, :sm]
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def admin_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center gap-2 font-semibold transition-colors",
        "rounded-control disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer",
        button_size(@size),
        button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_size(:md), do: "px-4 py-2.5 text-sm"
  defp button_size(:sm), do: "px-3 py-1.5 text-xs"

  defp button_variant(:primary), do: "bg-primary hover:bg-primary-hover text-white"

  defp button_variant(:secondary),
    do: "bg-surface hover:bg-surface-subtle text-text border border-border"

  defp button_variant(:danger), do: "bg-danger hover:bg-danger-hover text-white"

  # ─────────────────────────────────────────────────────────────────────
  # admin_card/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the canonical admin card container on semantic design tokens.

  Use `padding: :none` for flush content such as tables that manage their
  own cell padding.

  ## Examples

      <.admin_card>
        <h2>Store details</h2>
      </.admin_card>

      <.admin_card padding={:none}>
        <table>...</table>
      </.admin_card>
  """
  attr :padding, :atom, default: :default, values: [:default, :none]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def admin_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-surface rounded-card border border-border shadow-sm",
        @padding == :default && "p-6",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # stat_card/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a KPI stat tile — label, value, optional icon chip, and optional
  trend/delta row.

  The icon slot renders inside a coloured chip (`icon_bg`, defaults to the
  primary soft token); the delta slot renders under the value for trend
  indicators.

  ## Examples

      <.stat_card label="Revenue" value="GHS 1,200.00" />

      <.stat_card label="Low Stock" value="3" icon_bg="bg-amber-50">
        <:icon><.icon name="hero-exclamation-triangle" class="size-[18px] text-amber-600" /></:icon>
      </.stat_card>
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon_bg, :string, default: "bg-primary-soft"

  slot :icon
  slot :delta

  def stat_card(assigns) do
    ~H"""
    <.admin_card padding={:none} class="p-5 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-3">
        <span class="text-sm font-medium text-slate-500">{@label}</span>
        <div
          :if={@icon != []}
          class={["w-9 h-9 rounded-control flex items-center justify-center", @icon_bg]}
        >
          {render_slot(@icon)}
        </div>
      </div>
      <p class="text-2xl sm:text-3xl font-bold text-slate-900 tabular-nums">{@value}</p>
      {render_slot(@delta)}
    </.admin_card>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # table_toolbar/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the standard index-page toolbar — debounced search input with
  optional filter chips and right-side actions.

  ## Examples

      <.table_toolbar
        id="product-search-form"
        form={@search_form}
        search_query={@search_query}
        placeholder="Search products..."
      >
        <:filters>
          <.status_tab status={:all} current={@status_filter} label="All" />
        </:filters>
      </.table_toolbar>
  """
  attr :search_query, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, required: true
  attr :search_event, :string, default: "search"
  attr :placeholder, :string, default: "Search..."

  slot :filters
  slot :actions

  def table_toolbar(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row gap-3">
      <.form
        for={@form}
        id={@id}
        phx-change={@search_event}
        phx-debounce="300"
        class="flex-1"
      >
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-slate-400"
          />
          <.input
            field={@form[:search]}
            type="search"
            value={@search_query}
            placeholder={@placeholder}
            class="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-700
                   placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                   focus:border-emerald-500 transition-all"
            autocomplete="off"
          />
        </div>
      </.form>
      {render_slot(@filters)}
      <div :if={@actions != []} class="flex items-center gap-3">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # status_badge/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a colour-coded status badge.

  Variant determines the colour mapping:

  - `:order`     — pending, confirmed, processing, shipped, delivered, cancelled
  - `:payment`   — pending, success, failed, refunded
  - `:delivery`  — same colour family as :order with shipping-specific labels
  - `:product`   — active, draft, archived

  Status accepts both atoms and strings; unknown values fall back to slate.

  ## Examples

      <.status_badge status={@order.status} variant={:order} />
      <.status_badge status="pending" variant={:payment} />
  """
  attr :status, :any, required: true
  attr :variant, :atom, default: :order, values: [:order, :payment, :delivery, :product]

  def status_badge(assigns) do
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
  # supplier_stock_badge/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the reseller-facing supplier stock badge — status only, never the
  supplier's raw quantity. Callers compute `status` via
  `EmakolaWeb.Live.Admin.SupplyStockStatus.aggregate/1` over the offer's or
  listing's source variants.

  ## Examples

      <.supplier_stock_badge status={:in_stock} />
      <.supplier_stock_badge status={:low} />
      <.supplier_stock_badge status={:out} />
  """
  attr :status, :atom, required: true, values: [:in_stock, :low, :out]

  def supplier_stock_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-semibold",
      @status == :in_stock && "bg-emerald-50 text-emerald-700",
      @status == :low && "bg-amber-50 text-amber-700",
      @status == :out && "bg-rose-50 text-rose-700"
    ]}>
      <span class={[
        "size-1.5 rounded-full",
        @status == :in_stock && "bg-emerald-500",
        @status == :low && "bg-amber-500",
        @status == :out && "bg-rose-500"
      ]} />
      {supplier_stock_label(@status)}
    </span>
    """
  end

  defp supplier_stock_label(:in_stock), do: "In stock"
  defp supplier_stock_label(:low), do: "Low stock"
  defp supplier_stock_label(:out), do: "Out of stock"

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
    <div class="flex flex-col items-center justify-center text-center py-16 px-6 bg-surface border border-dashed border-border rounded-card">
      <div class="w-16 h-16 rounded-card bg-surface-subtle flex items-center justify-center mb-4">
        <.icon name={@icon} class="w-8 h-8 text-slate-400" />
      </div>
      <h3 class="text-base font-semibold text-text">{@title}</h3>
      <p :if={@description} class="text-sm text-text-muted mt-1 max-w-md">{@description}</p>
      <.link
        :if={@action_label && @action_path}
        href={@action_path}
        class={["mt-5", primary_action_classes()]}
      >
        {@action_label}
      </.link>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Internals
  # ─────────────────────────────────────────────────────────────────────

  defp primary_action_classes,
    do:
      "inline-flex items-center gap-2 px-4 py-2.5 bg-primary text-white " <>
        "text-sm font-semibold rounded-control hover:bg-primary-hover transition-colors cursor-pointer"

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
  # :processing/:shipped use indigo/purple — outside the semantic token
  # set, kept as literal Tailwind classes intentionally.
  defp status_color(:order, :pending), do: "bg-warning-soft text-warning"
  defp status_color(:order, :confirmed), do: "bg-info-soft text-info"
  defp status_color(:order, :processing), do: "bg-indigo-50 text-indigo-700"
  defp status_color(:order, :shipped), do: "bg-purple-50 text-purple-700"
  defp status_color(:order, :delivered), do: "bg-success-soft text-success"
  defp status_color(:order, :cancelled), do: "bg-danger-soft text-danger"
  defp status_color(:order, :refunded), do: "bg-slate-50 text-slate-600"

  # ── Payment statuses ───────────────────────────────────────────────
  defp status_color(:payment, :pending), do: "bg-warning-soft text-warning"
  defp status_color(:payment, :success), do: "bg-success-soft text-success"
  defp status_color(:payment, :failed), do: "bg-danger-soft text-danger"
  defp status_color(:payment, :refunded), do: "bg-slate-50 text-slate-600"

  # ── Delivery statuses (alias of order) ─────────────────────────────
  defp status_color(:delivery, status), do: status_color(:order, status)

  # ── Product statuses ───────────────────────────────────────────────
  defp status_color(:product, :active), do: "bg-success-soft text-success"
  defp status_color(:product, :published), do: "bg-success-soft text-success"
  defp status_color(:product, :draft), do: "bg-slate-100 text-slate-700"
  defp status_color(:product, :archived), do: "bg-slate-200 text-slate-600"

  # ── Default ────────────────────────────────────────────────────────
  defp status_color(_variant, _status), do: "bg-slate-50 text-slate-700"

  defp humanise(atom) when is_atom(atom), do: atom |> Atom.to_string() |> String.replace("_", " ")
  defp humanise(other), do: to_string(other)
end
