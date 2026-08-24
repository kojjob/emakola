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

  attr :icon, :string,
    default: nil,
    doc: "Renders a tinted badge beside the title, as the reference dashboard does."

  slot :inner_block

  def admin_page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6 pt-2">
      <div class="flex items-center gap-4">
        <div
          :if={@icon}
          class="w-14 h-14 rounded-card bg-primary flex items-center justify-center shrink-0 shadow-sm"
        >
          <.icon name={@icon} class="size-7 text-white" />
        </div>
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-text">{@title}</h1>
          <p :if={@subtitle} class="text-sm text-text-muted mt-1">{@subtitle}</p>
        </div>
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
  attr :id, :string, default: nil

  attr :tone, :atom,
    default: :neutral,
    values: [:primary, :accent, :success, :info, :warning, :danger, :cyan, :neutral],
    doc: """
    The tile's meaning-colour. One attribute drives the card wash, the icon
    tile and the icon colour together, so tiles cannot drift apart page by
    page — pass the tone, not three classes.

    A row of tiles should read as a row of distinct hues, the way the
    payment-dashboard reference does — violet, green, blue, red, cyan.
    """

  slot :icon
  slot :delta

  def stat_card(assigns) do
    ~H"""
    <.admin_card
      id={@id}
      padding={:none}
      class={"p-5 h-full min-h-48 flex flex-col hover:shadow-md transition-shadow #{tone_wash(@tone)}"}
    >
      <div class="flex items-start justify-between gap-3 mb-3">
        <span class="text-sm font-medium text-slate-500">{@label}</span>
        <%!-- The icon slot inherits text-white, so call sites pass a bare
              <.icon> with no colour of their own. --%>
        <div
          :if={@icon != []}
          class={[
            "w-14 h-14 rounded-control flex items-center justify-center shrink-0 text-white",
            tone_tile(@tone)
          ]}
        >
          {render_slot(@icon)}
        </div>
      </div>
      <p class="text-2xl sm:text-3xl font-bold text-slate-900 tabular-nums">{@value}</p>
      <%!-- mt-auto floors the footnote, so a row of tiles lines up on both
            edges even when one label wraps to two lines and its neighbour
            has no footnote at all. --%>
      <div :if={@delta != []} class="mt-auto pt-2">{render_slot(@delta)}</div>
    </.admin_card>
    """
  end

  defp tone_wash(:primary), do: "bg-gradient-to-br from-primary-soft to-surface"
  defp tone_wash(:accent), do: "bg-gradient-to-br from-violet-50 to-surface"
  defp tone_wash(:success), do: "bg-gradient-to-br from-emerald-50 to-surface"
  defp tone_wash(:info), do: "bg-gradient-to-br from-info-soft to-surface"
  defp tone_wash(:warning), do: "bg-gradient-to-br from-warning-soft to-surface"
  defp tone_wash(:danger), do: "bg-gradient-to-br from-danger-soft to-surface"
  defp tone_wash(:cyan), do: "bg-gradient-to-br from-cyan-50 to-surface"
  defp tone_wash(_neutral), do: "bg-gradient-to-br from-slate-100 to-surface"

  defp tone_tile(:primary), do: "bg-primary"
  defp tone_tile(:accent), do: "bg-violet-600"
  defp tone_tile(:success), do: "bg-emerald-500"
  defp tone_tile(:info), do: "bg-info"
  defp tone_tile(:warning), do: "bg-warning"
  defp tone_tile(:danger), do: "bg-danger"
  defp tone_tile(:cyan), do: "bg-cyan-500"
  defp tone_tile(_neutral), do: "bg-slate-500"

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
  # filter_tabs/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders the unified segmented filter-tab group with per-tab counts.

  Each tab is `%{key: atom, label: String.t(), count: integer | nil}` —
  counts are store-wide, and a nil count renders no chip. Clicking a tab
  pushes `event` (default `"filter_status"`) with `phx-value-status` set
  to the tab key.

  ## Examples

      <.filter_tabs
        tabs={[%{key: :all, label: "All", count: 24}, %{key: :active, label: "Active", count: 18}]}
        current={@status_filter}
      />
  """
  attr :tabs, :list, required: true
  attr :current, :any, required: true
  attr :event, :string, default: "filter_status"
  attr :id, :string, default: nil

  attr :param, :string,
    default: "status",
    doc: "phx-value-* name. Defaults to status; date ranges pass \"range\"."

  def filter_tabs(assigns) do
    ~H"""
    <div id={@id} class="flex gap-1 bg-slate-100 rounded-control p-1 overflow-x-auto">
      <button
        :for={tab <- @tabs}
        phx-click={@event}
        {%{("phx-value-" <> @param) => tab.key}}
        class={[
          "inline-flex items-center gap-2 px-3 py-2 text-sm font-semibold rounded-lg",
          "transition-colors whitespace-nowrap cursor-pointer",
          if(tab.key == @current,
            do: "bg-white text-slate-900 shadow-sm",
            else: "text-slate-500 hover:text-slate-700"
          )
        ]}
      >
        {tab.label}
        <span
          :if={tab.count && tab.count > 0}
          class={[
            "tab-count text-[11px] font-bold px-1.5 py-0.5 rounded-full tabular-nums",
            if(tab.key == @current,
              do: "bg-primary-soft text-primary-hover",
              else: "bg-slate-200 text-slate-500"
            )
          ]}
        >
          {tab.count}
        </span>
      </button>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # stock_meter/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a small stock-level meter with the quantity beside it — color
  reads before text (out = red, under 10 = amber, healthy = emerald), so
  stock health scans without reading numbers.

  ## Examples

      <.stock_meter quantity={14} />
      <.stock_meter quantity={0} />
  """
  attr :quantity, :integer, required: true
  attr :max, :integer, default: 20

  def stock_meter(assigns) do
    {fill, text} =
      cond do
        assigns.quantity == 0 -> {"bg-red-500", "text-red-600"}
        assigns.quantity < 10 -> {"bg-amber-500", "text-amber-700"}
        true -> {"bg-emerald-500", "text-slate-700"}
      end

    pct = min(100, round(assigns.quantity / max(assigns.max, 1) * 100))

    assigns = assign(assigns, fill_class: fill, text_class: text, pct: pct)

    ~H"""
    <span class="inline-flex items-center gap-2">
      <span class="w-16 h-1.5 rounded-full bg-slate-100 overflow-hidden shrink-0">
        <span class={["block h-full rounded-full", @fill_class]} style={"width: #{@pct}%"}></span>
      </span>
      <span class={["font-mono text-xs font-semibold tabular-nums", @text_class]}>
        <%= if @quantity == 0 do %>
          Out
        <% else %>
          {@quantity}
        <% end %>
      </span>
    </span>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # product_thumb/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a product thumbnail — the image when a URL exists, else a photo
  placeholder. Products lead with their picture everywhere in the admin.

  ## Examples

      <.product_thumb url={image_url} alt={product.title} />
      <.product_thumb url={nil} alt={product.title} class="w-12 h-12" />
  """
  attr :url, :string, required: true
  attr :alt, :string, required: true
  attr :class, :string, default: "w-11 h-11"

  def product_thumb(assigns) do
    ~H"""
    <div class={[
      "rounded-[10px] bg-slate-100 flex items-center justify-center flex-shrink-0 overflow-hidden",
      @class
    ]}>
      <%= if @url do %>
        <img src={@url} alt={@alt} class="w-full h-full object-cover" loading="lazy" />
      <% else %>
        <.icon name="hero-photo" class="size-5 text-slate-400" />
      <% end %>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # payment_rail_chip/1
  # ─────────────────────────────────────────────────────────────────────

  @doc """
  Renders a payment rail chip in the rail's brand colour, so merchants
  recognize how they were paid by colour before reading a word.

  ## Examples

      <.payment_rail_chip rail={:mtn_momo} />
      <.payment_rail_chip id="payment-rail-chip" rail={:hubtel} />
  """
  attr :rail, :atom,
    required: true,
    values: [:mtn_momo, :telecel_cash, :airteltigo, :mobile_money, :card, :hubtel, :paystack]

  attr :id, :string, default: nil

  def payment_rail_chip(assigns) do
    ~H"""
    <span
      id={@id}
      class={[
        "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold whitespace-nowrap",
        rail_chip_class(@rail)
      ]}
    >
      <.icon name={rail_chip_icon(@rail)} class="size-3.5 shrink-0" />
      {rail_chip_label(@rail)}
    </span>
    """
  end

  defp rail_chip_class(:mtn_momo), do: "bg-[#FFCC08] text-slate-900"
  defp rail_chip_class(:telecel_cash), do: "bg-[#E60000] text-white"
  defp rail_chip_class(:airteltigo), do: "bg-blue-600 text-white"
  defp rail_chip_class(:mobile_money), do: "bg-emerald-600 text-white"
  defp rail_chip_class(:card), do: "bg-slate-800 text-white"
  defp rail_chip_class(:hubtel), do: "bg-teal-600 text-white"
  defp rail_chip_class(:paystack), do: "bg-sky-600 text-white"

  defp rail_chip_label(:mtn_momo), do: "MTN MoMo"
  defp rail_chip_label(:telecel_cash), do: "Telecel Cash"
  defp rail_chip_label(:airteltigo), do: "AT Money"
  defp rail_chip_label(:mobile_money), do: "Mobile Money"
  defp rail_chip_label(:card), do: "Card"
  defp rail_chip_label(:hubtel), do: "Hubtel"
  defp rail_chip_label(:paystack), do: "Paystack"

  defp rail_chip_icon(:card), do: "hero-credit-card"
  defp rail_chip_icon(_rail), do: "hero-device-phone-mobile"

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

  attr :variant, :atom,
    default: :order,
    values: [:order, :payment, :delivery, :product, :return, :payout, :campaign]

  def status_badge(assigns) do
    status_atom = normalise_status(assigns.status)
    color = status_color(assigns.variant, status_atom)

    assigns =
      assigns
      |> assign(:status_atom, status_atom)
      |> assign(:color_classes, color)
      |> assign(:icon_name, status_icon(assigns.variant, status_atom))

    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize",
      @color_classes
    ]}>
      <.icon :if={@icon_name} name={@icon_name} class="size-3.5 shrink-0" />
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
  attr :secondary_label, :string, default: nil
  attr :secondary_path, :string, default: nil

  attr :action_event, :string,
    default: nil,
    doc: "Use instead of action_path when the action opens a modal rather than navigating."

  attr :id, :string, default: nil

  attr :tone, :atom,
    default: :neutral,
    values: [:neutral, :primary, :info, :accent, :warning, :success],
    doc: "Tints the icon circle. A picture in colour, not a grey square."

  attr :action_icon, :string, default: nil
  attr :secondary_icon, :string, default: nil
  attr :external, :boolean, default: false, doc: "Primary action leaves the app (e.g. wa.me)."

  attr :show_tour, :boolean,
    default: false,
    doc: "Adds a link to the visual tour — for merchants who have nothing yet."

  def empty_state(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex flex-col items-center justify-center text-center py-16 px-6 bg-surface border border-dashed border-border rounded-card"
    >
      <%!-- The picture: a tinted circle, coloured for the page it fronts. --%>
      <div class={[
        "w-20 h-20 rounded-full flex items-center justify-center mb-4",
        tone_bg(@tone)
      ]}>
        <.icon name={@icon} class={["w-9 h-9", tone_fg(@tone)]} />
      </div>
      <h3 class="text-lg font-bold text-text">{@title}</h3>
      <p :if={@description} class="text-sm text-text-muted mt-1 max-w-xs">{@description}</p>

      <div class="flex flex-wrap items-center justify-center gap-3 mt-5">
        <.link
          :if={@action_label && @action_path}
          href={@action_path}
          target={if @external, do: "_blank"}
          rel={if @external, do: "noopener noreferrer"}
          class={primary_action_classes()}
        >
          <.icon :if={@action_icon} name={@action_icon} class="size-5 shrink-0" />
          {@action_label}
        </.link>
        <%!-- Some first actions open a modal rather than navigating. --%>
        <button
          :if={@action_label && @action_event && !@action_path}
          type="button"
          phx-click={@action_event}
          class={primary_action_classes()}
        >
          <.icon :if={@action_icon} name={@action_icon} class="size-5 shrink-0" />
          {@action_label}
        </button>
        <.link
          :if={@secondary_label && @secondary_path}
          href={@secondary_path}
          class="inline-flex items-center gap-2 px-4 py-2.5 border border-border bg-surface text-sm font-semibold rounded-control text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
        >
          <.icon :if={@secondary_icon} name={@secondary_icon} class="size-5 shrink-0" />
          {@secondary_label}
        </.link>
      </div>

      <%!-- The tour is the explainer for merchants who read slowly: pictures,
            not paragraphs. It only belongs on a genuinely empty page, never on
            a search that happened to match nothing. --%>
      <.link
        :if={@show_tour}
        href="/how-it-works/tour"
        class="mt-4 inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline"
      >
        <.icon name="hero-play-circle" class="size-4" /> See how selling works
      </.link>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # Internals
  # ─────────────────────────────────────────────────────────────────────

  defp tone_bg(:primary), do: "bg-primary-soft"
  defp tone_bg(:info), do: "bg-info-soft"
  defp tone_bg(:accent), do: "bg-violet-50"
  defp tone_bg(:warning), do: "bg-warning-soft"
  defp tone_bg(:success), do: "bg-success-soft"
  defp tone_bg(_), do: "bg-surface-subtle"

  defp tone_fg(:primary), do: "text-primary"
  defp tone_fg(:info), do: "text-info"
  defp tone_fg(:accent), do: "text-violet-600"
  defp tone_fg(:warning), do: "text-warning"
  defp tone_fg(:success), do: "text-success"
  defp tone_fg(_), do: "text-slate-400"

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

  # ── Payout statuses ────────────────────────────────────────────────
  # Money that left the platform. `:paid` is the good end state, so it reads
  # green — without this variant it fell to the neutral catch-all and a sent
  # payout looked the same as a stalled one.
  defp status_color(:payout, :pending), do: "bg-warning-soft text-warning"
  defp status_color(:payout, :processing), do: "bg-info-soft text-info"
  defp status_color(:payout, :paid), do: "bg-success-soft text-success"
  defp status_color(:payout, :failed), do: "bg-danger-soft text-danger"
  defp status_color(:payout, :reversed), do: "bg-slate-50 text-slate-600"

  # ── Campaign statuses ──────────────────────────────────────────────
  # A draft is grey, not amber: nothing is pending, the merchant simply has
  # not spent the money yet.
  defp status_color(:campaign, :draft), do: "bg-slate-100 text-slate-600"
  defp status_color(:campaign, :sending), do: "bg-info-soft text-info"
  defp status_color(:campaign, :sent), do: "bg-success-soft text-success"
  defp status_color(:campaign, :failed), do: "bg-danger-soft text-danger"

  # ── Delivery statuses (alias of order) ─────────────────────────────
  defp status_color(:delivery, status), do: status_color(:order, status)

  # ── Product statuses ───────────────────────────────────────────────
  defp status_color(:product, :active), do: "bg-success-soft text-success"
  defp status_color(:product, :published), do: "bg-success-soft text-success"
  defp status_color(:product, :draft), do: "bg-slate-100 text-slate-700"
  defp status_color(:product, :archived), do: "bg-slate-200 text-slate-600"

  # ── Return statuses ────────────────────────────────────────────────
  defp status_color(:return, :requested), do: "bg-warning-soft text-warning"
  defp status_color(:return, :approved), do: "bg-success-soft text-success"
  defp status_color(:return, :denied), do: "bg-danger-soft text-danger"
  defp status_color(:return, :refunded), do: "bg-info-soft text-info"

  # ── Default ────────────────────────────────────────────────────────
  defp status_color(_variant, _status), do: "bg-slate-50 text-slate-700"

  # ── Status icons ───────────────────────────────────────────────────
  # Every known status carries a glyph so state reads by shape as well as
  # color — many merchants scan icons faster than they read labels.
  defp status_icon(:delivery, status), do: status_icon(:order, status)

  # Variant-pinned, and deliberately above the `_variant` clauses below: a
  # generic `:paid` icon added later would otherwise shadow this one.
  defp status_icon(:payout, :paid), do: "hero-paper-airplane"

  defp status_icon(_variant, :pending), do: "hero-clock"
  defp status_icon(_variant, :confirmed), do: "hero-check"
  defp status_icon(_variant, :processing), do: "hero-arrow-path"
  defp status_icon(_variant, :shipped), do: "hero-truck"
  defp status_icon(_variant, :delivered), do: "hero-check-circle"
  defp status_icon(_variant, :cancelled), do: "hero-x-mark"
  defp status_icon(_variant, :refunded), do: "hero-arrow-uturn-left"
  defp status_icon(_variant, :success), do: "hero-check"
  defp status_icon(_variant, :failed), do: "hero-x-mark"
  defp status_icon(_variant, :active), do: "hero-check"
  defp status_icon(_variant, :published), do: "hero-check"
  defp status_icon(_variant, :draft), do: "hero-pencil"
  defp status_icon(_variant, :archived), do: "hero-archive-box"
  defp status_icon(_variant, :requested), do: "hero-clock"
  defp status_icon(_variant, :approved), do: "hero-check"
  defp status_icon(_variant, :denied), do: "hero-x-mark"
  defp status_icon(_variant, _status), do: nil

  defp humanise(atom) when is_atom(atom), do: atom |> Atom.to_string() |> String.replace("_", " ")
  defp humanise(other), do: to_string(other)
end
