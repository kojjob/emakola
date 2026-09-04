defmodule EmakolaWeb.SidebarComponents do
  @moduledoc "Premium sidebar link component with icon map and badge support."
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: EmakolaWeb.Endpoint,
    router: EmakolaWeb.Router,
    statics: EmakolaWeb.static_paths()

  alias Phoenix.LiveView.JS

  @sidebar_icons %{
    "grid" =>
      "M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z",
    "package" =>
      "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z",
    "inventory" =>
      "M21 7.5l-2.25-1.313M21 7.5v2.25m0-2.25l-2.25 1.313M3 7.5l2.25-1.313M3 7.5l2.25 1.313M3 7.5v2.25m9 3l2.25-1.313M12 12.75l-2.25-1.313M12 12.75V15m0 6.75l2.25-1.313M12 21.75V19.5m0 2.25l-2.25-1.313m0-16.875L12 2.25l2.25 1.313M21 14.25v2.25l-2.25 1.313m-13.5 0L3 16.5v-2.25",
    "bag" =>
      "M15.75 10.5V6a3.75 3.75 0 10-7.5 0v4.5m11.356-1.993l1.263 12c.07.665-.45 1.243-1.119 1.243H4.25a1.125 1.125 0 01-1.12-1.243l1.264-12A1.125 1.125 0 015.513 7.5h12.974c.576 0 1.059.435 1.119 1.007zM8.625 10.5a.375.375 0 11-.75 0 .375.375 0 01.75 0zm7.5 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z",
    "truck" =>
      "M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h1.125c.621 0 1.129-.504 1.09-1.124a17.902 17.902 0 00-3.213-9.193 2.056 2.056 0 00-1.58-.86H14.25M16.5 18.75h-2.25m0-11.177v-.958c0-.568-.422-1.048-.987-1.106a48.554 48.554 0 00-10.026 0 1.106 1.106 0 00-.987 1.106v7.635m12-6.677v6.677m0 4.5v-4.5m0 0h-12",
    "users" =>
      "M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z",
    "folder" =>
      "M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z",
    "tag" =>
      "M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z",
    "megaphone" =>
      "M10.34 15.84c-.688-.06-1.386-.09-2.09-.09H7.5a4.5 4.5 0 110-9h.75c.704 0 1.402-.03 2.09-.09m0 9.18c.253.962.584 1.892.985 2.783.247.55.06 1.21-.463 1.511l-.657.38c-.551.318-1.26.117-1.527-.461a20.845 20.845 0 01-1.44-4.282m3.102.069a18.03 18.03 0 01-.59-4.59c0-1.586.205-3.124.59-4.59m0 9.18a23.848 23.848 0 018.835 2.535M10.34 6.66a23.847 23.847 0 008.835-2.535m0 0A23.74 23.74 0 0018.795 3m.38 1.125a23.91 23.91 0 011.014 5.395m-1.014 8.855c-.118.38-.245.754-.38 1.125m.38-1.125a23.91 23.91 0 001.014-5.395m0-3.46c.495.413.811 1.035.811 1.73 0 .695-.316 1.317-.811 1.73m0-3.46a24.347 24.347 0 010 3.46",
    "chart" =>
      "M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z",
    "currency" =>
      "M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z",
    "palette" =>
      "M4.098 19.902a3.75 3.75 0 005.304 0l6.401-6.402M6.75 21A3.75 3.75 0 013 17.25V4.125C3 3.504 3.504 3 4.125 3h5.25c.621 0 1.125.504 1.125 1.125v4.072M6.75 21a3.75 3.75 0 003.75-3.75V8.197M6.75 21h13.125c.621 0 1.125-.504 1.125-1.125v-5.25c0-.621-.504-1.125-1.125-1.125h-4.072M10.5 8.197l2.88-2.88c.438-.439 1.15-.439 1.59 0l3.712 3.713c.44.44.44 1.152 0 1.59l-2.88 2.88M6.75 17.25h.008v.008H6.75v-.008z",
    "payments" =>
      "M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z",
    "returns" => "M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3",
    "gear" =>
      "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z",
    "pencil-square" =>
      "M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10",
    "photo" =>
      "M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z",
    "shield" =>
      "M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z",
    "chat" =>
      "M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"
  }

  @sidebar_icons_secondary %{
    "tag" => "M6 6h.008v.008H6V6z",
    "gear" => "M15 12a3 3 0 11-6 0 3 3 0 016 0z"
  }

  attr :href, :string, required: true
  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false
  attr :badge, :string, default: nil
  attr :badge_color, :string, default: "emerald"

  def sidebar_link(assigns) do
    assigns = assign(assigns, :icon_path, Map.get(@sidebar_icons, assigns.icon, ""))
    assigns = assign(assigns, :icon_path2, Map.get(@sidebar_icons_secondary, assigns.icon))

    ~H"""
    <a href={@href} title={@title} class={"sidebar-link" <> if(@active, do: " active", else: "")}>
      <svg
        class="link-icon"
        width="20"
        height="20"
        fill="none"
        stroke="currentColor"
        stroke-width="1.8"
        viewBox="0 0 24 24"
        aria-hidden="true"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d={@icon_path} />
        <%= if @icon_path2 do %>
          <path stroke-linecap="round" stroke-linejoin="round" d={@icon_path2} />
        <% end %>
      </svg>
      <span class="nav-label">{@title}</span>
      <%= if @badge do %>
        <span class={"sidebar-badge nav-label sidebar-badge-" <> @badge_color}>{@badge}</span>
      <% end %>
    </a>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # admin_sidebar/1 — the full admin shell sidebar: mobile overlay, aside
  # (logo, store selector, nav, user card), plus the user popover/backdrop
  # that deliberately live OUTSIDE the aside (overflow-hidden + transform
  # would clip them). Markup extracted verbatim from layouts/app.html.heex.
  # ─────────────────────────────────────────────────────────────────────

  attr :active_nav, :atom, default: nil
  attr :current_user, :any, default: nil
  attr :current_merchant, :any, default: nil
  attr :current_store, :any, default: nil
  attr :pending_order_count, :any, default: nil
  attr :unread_message_count, :integer, default: 0

  def admin_sidebar(assigns) do
    ~H"""
    <%!-- ═══════════════════════════════════════════ --%>
    <%!-- MOBILE OVERLAY                              --%>
    <%!-- ═══════════════════════════════════════════ --%>
    <div
      id="sidebar-overlay"
      class="sidebar-overlay fixed inset-0 bg-black/60 backdrop-blur-sm z-40 lg:hidden"
      phx-click={JS.remove_class("mobile-open", to: "#admin-shell")}
      aria-hidden="true"
    >
    </div>

    <%!-- ═══════════════════════════════════════════ --%>
    <%!-- SIDEBAR                                     --%>
    <%!-- ═══════════════════════════════════════════ --%>
    <aside
      id="sidebar"
      class="sidebar fixed lg:relative z-50 flex flex-col h-full bg-emakola-emerald overflow-hidden shrink-0"
    >
      <%!-- ── LOGO + COLLAPSE TOGGLE ── --%>
      <div class="sidebar-header flex items-center h-[72px] border-b border-white/[0.06] shrink-0 px-5">
        <a href="/dashboard" class="flex items-center gap-3 min-w-0">
          <div class="sidebar-icon-box w-9 h-9 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shrink-0 shadow-lg shadow-emerald-500/20">
            <svg
              class="w-5 h-5 text-white"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M4 20l5-8 5 4 6-11" />
            </svg>
          </div>
          <div class="nav-label min-w-0">
            <span class="text-[15px] font-bold text-white tracking-tight leading-tight block">
              Makola
            </span>
            <span class="text-[10px] text-emerald-400/60 font-medium leading-tight block">
              Merchant Portal
            </span>
          </div>
        </a>
        <%!-- Collapse toggle (desktop only) --%>
        <button
          id="collapse-btn"
          class="collapse-btn hidden lg:flex ml-auto w-7 h-7 items-center justify-center rounded-lg hover:bg-white/[0.06] transition-colors cursor-pointer"
          data-toggle-sidebar
          aria-label="Toggle sidebar"
        >
          <svg
            class="collapse-icon w-4 h-4 text-white/40 transition-transform duration-300"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </button>
        <%!-- Close button (mobile) --%>
        <button
          class="lg:hidden ml-auto p-1.5 rounded-lg hover:bg-white/[0.06] transition-colors cursor-pointer"
          phx-click={JS.remove_class("mobile-open", to: "#admin-shell")}
          aria-label="Close sidebar"
        >
          <svg
            class="w-5 h-5 text-white/50"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <%!-- ── STORE SELECTOR ── --%>
      <div class="store-selector mx-3 mt-4 mb-2 px-3 py-2.5 rounded-xl bg-white/[0.04] border border-white/[0.06] cursor-pointer hover:bg-white/[0.07] transition-colors group">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-emerald-500/20 flex items-center justify-center shrink-0">
            <span class="text-xs font-bold text-emerald-400">
              {if assigns[:current_store],
                do: assigns[:current_store].name |> String.first() |> String.upcase(),
                else: "E"}
            </span>
          </div>
          <div class="nav-label min-w-0 flex-1">
            <p class="text-[13px] font-semibold text-white truncate leading-tight">
              {if assigns[:current_store], do: assigns[:current_store].name, else: "My Store"}
            </p>
            <p class="text-[10px] text-white/30 truncate leading-tight">
              <span class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400 mr-1 align-middle"></span>Live
            </p>
          </div>
          <svg
            class="nav-label w-4 h-4 text-white/20 group-hover:text-white/40 transition-colors shrink-0"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M8.25 15L12 18.75 15.75 15m-7.5-6L12 5.25 15.75 9"
            />
          </svg>
        </div>
      </div>

      <%!-- ── NAVIGATION ── --%>
      <nav class="sidebar-nav flex-1 px-3 py-3 overflow-y-auto" aria-label="Admin navigation">
        <%!-- Main --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mb-1.5">
          Main
        </p>

        <.sidebar_link
          href="/dashboard"
          title="Dashboard"
          icon="grid"
          active={@active_nav == :dashboard}
        />
        <%!-- Sell --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mt-6 mb-1.5">
          Sell
        </p>

        <.sidebar_link
          href="/admin/products"
          title="Products"
          icon="package"
          active={@active_nav == :products}
        />
        <.sidebar_link
          href="/admin/inventory"
          title="Inventory"
          icon="inventory"
          active={@active_nav == :inventory}
        />
        <.sidebar_link
          href="/admin/categories"
          title="Categories"
          icon="folder"
          active={@active_nav == :categories}
        />
        <.sidebar_link
          href="/admin/orders"
          title="Orders"
          icon="bag"
          active={@active_nav == :orders}
          badge={if @pending_order_count > 0, do: to_string(@pending_order_count)}
        />
        <.sidebar_link
          href="/admin/returns"
          title="Returns"
          icon="returns"
          active={@active_nav == :returns}
        />
        <%!-- Delivery lived only inside Settings, so a merchant changing a
             fee had to remember where it was. It is fulfilment, and it sits
             with fulfilment. --%>
        <.sidebar_link
          href="/admin/settings/delivery"
          title="Delivery"
          icon="truck"
          active={@active_nav == :delivery}
        />

        <%!-- Marketplace --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mt-6 mb-1.5">
          Marketplace
        </p>

        <.sidebar_link
          href="/admin/supply/catalog"
          title="Browse Suppliers"
          icon="package"
          active={@active_nav == :supply_catalog}
        />
        <.sidebar_link
          href="/admin/supply/offers"
          title="My Offers"
          icon="tag"
          active={@active_nav == :supply_offers}
        />
        <.sidebar_link
          href="/admin/settings/supply-network"
          title="Partners"
          icon="users"
          active={@active_nav == :supply_network}
        />
        <.sidebar_link
          href="/admin/settings/suppliers"
          title="My Contacts"
          icon="truck"
          active={@active_nav == :suppliers}
        />

        <%!-- Customers & Marketing --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mt-6 mb-1.5">
          Customers & Marketing
        </p>

        <%!-- First in the group: a buyer waiting on a reply is the most
              time-sensitive thing on this list. --%>
        <.sidebar_link
          href="/admin/messages"
          title="Messages"
          icon="chat"
          active={@active_nav == :messages}
          badge={if @unread_message_count > 0, do: to_string(@unread_message_count)}
        />
        <.sidebar_link
          href="/admin/customers"
          title="Customers"
          icon="users"
          active={@active_nav == :customers}
        />
        <.sidebar_link
          href="/admin/payments"
          title="Payments"
          icon="payments"
          active={@active_nav == :payments}
        />
        <.sidebar_link
          href="/admin/coupons"
          title="Discounts"
          icon="tag"
          active={@active_nav in [:coupons, :discounts]}
        />
        <.sidebar_link
          href="/admin/campaigns"
          title="Campaigns"
          icon="megaphone"
          active={@active_nav == :campaigns}
        />
        <.sidebar_link
          href="/admin/pay-links"
          title="Pay Links"
          icon="payments"
          active={@active_nav == :pay_links}
        />

        <%!-- Content & Design --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mt-6 mb-1.5">
          Content & Design
        </p>

        <.sidebar_link
          href="/admin/theme"
          title="Theme"
          icon="palette"
          active={@active_nav == :theme}
        />
        <.sidebar_link
          href="/admin/design"
          title="Design"
          icon="pencil-square"
          active={@active_nav == :design}
        />
        <.sidebar_link
          href="/admin/content/posts"
          title="Blog & Pages"
          icon="pencil-square"
          active={@active_nav == :content}
        />
        <.sidebar_link
          href="/admin/content/media"
          title="Media"
          icon="photo"
          active={@active_nav == :media}
        />
        <.sidebar_link
          href="/admin/content/pages"
          title="Store Pages"
          icon="document-text"
          active={@active_nav == :page_content}
        />

        <%!-- Insights --%>
        <p class="nav-section-label px-3 text-[10px] font-semibold text-white/25 uppercase tracking-[0.12em] mt-6 mb-1.5">
          Insights
        </p>

        <.sidebar_link
          href="/admin/reports"
          title="Reports"
          icon="chart"
          active={@active_nav == :reports}
        />
        <.sidebar_link
          href="/admin/revenue"
          title="Revenue"
          icon="currency"
          active={@active_nav == :revenue}
        />
      </nav>

      <%!-- ── FOOTER ── --%>
      <div class="sidebar-footer px-3 py-3 border-t border-white/[0.06] shrink-0 space-y-2">
        <.sidebar_link
          href="/admin/settings"
          title="Settings"
          icon="gear"
          active={@active_nav == :settings}
        />
        <.sidebar_link
          href="/admin/verification"
          title="Business details"
          icon="folder"
          active={@active_nav == :verification}
        />
        <.sidebar_link
          href="/admin/earnings"
          title="Earnings"
          icon="currency"
          active={@active_nav == :earnings}
        />
        <.sidebar_link
          href="/admin/payouts"
          title="Payouts"
          icon="payments"
          active={@active_nav == :payouts}
        />

        <%!-- User card with popover --%>
        <% sidebar_user = @current_merchant || @current_user %>
        <div
          class="sidebar-user relative"
          id="sidebar-user-menu"
        >
          <button
            phx-click={
              JS.toggle(to: "#sidebar-user-popover") |> JS.toggle(to: "#sidebar-user-backdrop")
            }
            class="w-full flex items-center gap-3 px-3 py-2.5 bg-white/[0.04] rounded-xl cursor-pointer hover:bg-white/[0.07] transition-colors"
          >
            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-[11px] font-bold text-white ring-2 ring-emerald-500/20 shrink-0 overflow-hidden">
              <%= if sidebar_user && Map.get(sidebar_user, :avatar_url) do %>
                <img src={sidebar_user.avatar_url} alt="" class="w-full h-full object-cover" />
              <% else %>
                {EmakolaWeb.LayoutHelpers.user_initials(sidebar_user)}
              <% end %>
            </div>
            <div class="nav-label min-w-0 flex-1 text-left">
              <p class="text-[13px] font-semibold text-white truncate leading-tight">
                {if sidebar_user && Map.get(sidebar_user, :name),
                  do: sidebar_user.name,
                  else: "Merchant"}
              </p>
              <p class="text-[10px] text-white/30 truncate leading-tight">
                {if sidebar_user, do: sidebar_user.email, else: "merchant@makola.io"}
              </p>
            </div>
            <svg
              class="nav-label w-4 h-4 text-white/20 shrink-0"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.25 15L12 18.75 15.75 15m-7.5-6L12 5.25 15.75 9"
              />
            </svg>
          </button>
        </div>
      </div>
    </aside>

    <%!-- Backdrop to close user popover on outside click --%>
    <div
      id="sidebar-user-backdrop"
      phx-click={JS.hide(to: "#sidebar-user-popover") |> JS.hide(to: "#sidebar-user-backdrop")}
      class="hidden fixed inset-0 z-[199]"
    >
    </div>

    <%!-- User popover menu — OUTSIDE sidebar to avoid overflow-hidden + transform clipping --%>
    <div
      id="sidebar-user-popover"
      class="hidden fixed bottom-20 left-3 w-56 bg-[#1a2e22] rounded-xl border border-white/[0.08] shadow-2xl overflow-hidden z-[200]"
    >
      <%!-- Store info --%>
      <%= if @current_store do %>
        <div class="px-4 py-3 border-b border-white/[0.06]">
          <div class="flex items-center gap-2">
            <div class="w-7 h-7 rounded-lg bg-emerald-500/20 flex items-center justify-center shrink-0">
              <span class="text-[10px] font-bold text-emerald-400">
                {@current_store.name |> String.first() |> String.upcase()}
              </span>
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-xs font-semibold text-white truncate">{@current_store.name}</p>
              <p class="text-[10px] text-white/30">{@current_store.currency} store</p>
            </div>
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
          </div>
        </div>
      <% end %>

      <%!-- Quick links --%>
      <div class="py-1">
        <a
          href="/admin/settings"
          class="flex items-center gap-2.5 px-4 py-2 text-[12px] text-white/70 hover:text-white hover:bg-white/[0.06] transition-colors"
        >
          <span class="material-symbols-outlined text-sm">person</span> Profile & Account
        </a>
        <%= if @current_store do %>
          <a
            href={EmakolaWeb.Storefront.Path.store_path(@current_store.slug, "/")}
            target="_blank"
            class="flex items-center gap-2.5 px-4 py-2 text-[12px] text-white/70 hover:text-white hover:bg-white/[0.06] transition-colors"
          >
            <span class="material-symbols-outlined text-sm">storefront</span>
            View Storefront
            <span class="material-symbols-outlined text-[10px] text-white/30 ml-auto">
              open_in_new
            </span>
          </a>
        <% end %>
        <a
          href="#"
          class="flex items-center gap-2.5 px-4 py-2 text-[12px] text-white/70 hover:text-white hover:bg-white/[0.06] transition-colors"
        >
          <span class="material-symbols-outlined text-sm">help</span> Help & Support
        </a>
      </div>

      <div class="mx-3 border-t border-white/[0.06]"></div>

      <%!-- Sign out --%>
      <div class="py-1">
        <.link
          href="/auth/session"
          method="delete"
          class="flex items-center gap-2.5 px-4 py-2 text-[12px] text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 transition-colors"
        >
          <span class="material-symbols-outlined text-sm">logout</span> Sign out
        </.link>
      </div>
    </div>
    """
  end

  # ─────────────────────────────────────────────────────────────────────
  # admin_topbar/1 — search, quick add, notifications dropdown, user
  # dropdown. Markup extracted verbatim from layouts/app.html.heex.
  # ─────────────────────────────────────────────────────────────────────

  attr :current_user, :any, default: nil
  attr :current_merchant, :any, default: nil
  attr :current_store, :any, default: nil
  attr :current_plan, :any, default: nil
  attr :order_count, :any, default: nil
  attr :product_count, :any, default: nil
  attr :customer_count, :any, default: nil
  attr :notifications, :any, default: nil
  attr :unread_notification_count, :any, default: nil

  def admin_topbar(assigns) do
    ~H"""
    <%!-- TOP BAR --%>
    <header class="topbar bg-white/80 backdrop-blur-xl border-b border-slate-200/80 h-[72px] flex items-center px-4 sm:px-8 shrink-0 gap-4 sticky top-0 z-30">
      <%!-- Mobile menu toggle --%>
      <button
        class="lg:hidden p-2 -ml-2 rounded-xl hover:bg-slate-100 cursor-pointer transition-colors"
        phx-click={JS.add_class("mobile-open", to: "#admin-shell")}
        aria-label="Open sidebar"
      >
        <svg
          class="w-5 h-5 text-slate-500"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
          />
        </svg>
      </button>

      <%!-- Search --%>
      <div class="flex-1 max-w-lg relative">
        <svg
          class="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
          />
        </svg>
        <input
          type="search"
          placeholder="Search anything..."
          class="w-full pl-10 pr-4 py-2.5 bg-slate-50/80 border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-400 focus:bg-white transition-all"
          aria-label="Search"
        />
        <kbd class="hidden sm:flex absolute right-3 top-1/2 -translate-y-1/2 items-center gap-0.5 text-[10px] text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded-md border border-slate-200 font-mono">
          ⌘K
        </kbd>
      </div>

      <div class="flex-1"></div>

      <%!-- Right actions --%>
      <div class="flex items-center gap-2">
        <%!-- Quick add --%>
        <.link
          navigate={~p"/admin/products/new"}
          class="hidden md:flex items-center gap-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-medium px-3.5 py-2 rounded-xl transition-colors shadow-sm shadow-emerald-600/20 cursor-pointer"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          <span>New</span>
        </.link>

        <div class="hidden md:block w-px h-8 bg-slate-200/60"></div>

        <%!-- ═══ NOTIFICATIONS DROPDOWN ═══ --%>
        <% notifs = assigns[:notifications] || [] %>
        <% unread_count = assigns[:unread_notification_count] || 0 %>
        <div
          id="notifications-dropdown"
          class="relative"
          phx-click-away={JS.hide(to: "#notif-panel")}
        >
          <button
            phx-click={JS.toggle(to: "#notif-panel") |> JS.hide(to: "#user-panel")}
            class="relative p-2.5 rounded-xl hover:bg-slate-100 transition-colors cursor-pointer"
            aria-label="Notifications"
          >
            <svg
              class="w-5 h-5 text-slate-500"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0"
              />
            </svg>
            <%= if unread_count > 0 do %>
              <span class="absolute top-1.5 right-1.5 min-w-[18px] h-[18px] flex items-center justify-center bg-rose-500 text-white text-[10px] font-bold rounded-full ring-2 ring-white px-1">
                {if unread_count > 9, do: "9+", else: unread_count}
              </span>
            <% end %>
          </button>

          <div
            id="notif-panel"
            class="hidden absolute right-0 top-full mt-2 w-80 max-h-[420px] bg-white rounded-2xl shadow-2xl shadow-slate-200/80 border border-slate-200/80 overflow-hidden z-50"
          >
            <div class="flex items-center justify-between px-5 py-4 border-b border-slate-100">
              <div class="flex items-center gap-2">
                <h3 class="text-sm font-bold text-slate-900">Notifications</h3>
                <%= if unread_count > 0 do %>
                  <span class="min-w-[20px] h-5 flex items-center justify-center bg-rose-500 text-white text-[10px] font-bold rounded-full px-1.5">
                    {unread_count}
                  </span>
                <% end %>
              </div>
              <%= if unread_count > 0 do %>
                <button
                  phx-click="mark_all_notifications_read"
                  class="text-xs font-medium text-emerald-600 hover:text-emerald-700 transition-colors cursor-pointer"
                >
                  Mark all read
                </button>
              <% end %>
            </div>
            <div class="overflow-y-auto max-h-[360px] divide-y divide-slate-50">
              <%= if length(notifs) > 0 do %>
                <%= for notif <- notifs do %>
                  <button
                    type="button"
                    id={"notification-#{notif.id}"}
                    phx-click="open_notification"
                    phx-value-id={notif.id}
                    class={"w-full text-left flex gap-3 px-5 py-3.5 hover:bg-slate-50/80 transition-colors cursor-pointer #{if is_nil(notif.read_at), do: "bg-emerald-50/30", else: ""}"}
                  >
                    <div class={"shrink-0 w-9 h-9 rounded-xl bg-gradient-to-br flex items-center justify-center #{EmakolaWeb.LayoutHelpers.notification_icon_bg_class(notif.type)}"}>
                      <span class={"material-symbols-outlined text-lg #{EmakolaWeb.LayoutHelpers.notification_icon_color_class(notif.type)}"}>
                        {EmakolaWeb.LayoutHelpers.notification_icon(notif.type)}
                      </span>
                    </div>
                    <div class="min-w-0 flex-1">
                      <div class="flex items-start justify-between gap-2">
                        <p class={"text-sm leading-snug #{if is_nil(notif.read_at), do: "font-semibold text-slate-900", else: "font-medium text-slate-600"}"}>
                          {notif.title}
                        </p>
                        <%= if is_nil(notif.read_at) do %>
                          <span class="shrink-0 w-2 h-2 mt-1.5 rounded-full bg-emerald-500"></span>
                        <% end %>
                      </div>
                      <%= if notif.body do %>
                        <p class="text-xs text-slate-500 mt-0.5 line-clamp-2 leading-relaxed">
                          {notif.body}
                        </p>
                      <% end %>
                      <p class="text-[10px] text-slate-400 mt-1 font-medium">
                        {EmakolaWeb.LayoutHelpers.relative_time(notif.inserted_at)}
                      </p>
                    </div>
                  </button>
                <% end %>
              <% else %>
                <div class="px-5 py-10 text-center">
                  <span class="material-symbols-outlined text-3xl text-slate-300">
                    notifications_off
                  </span>
                  <p class="text-sm text-slate-400 mt-2">No notifications yet</p>
                </div>
              <% end %>
            </div>
            <div class="border-t border-slate-100 px-5 py-3 flex items-center justify-between">
              <a
                href="/admin/messages"
                class="text-xs font-bold text-emerald-600 hover:text-emerald-700 transition-colors"
              >
                View all messages
              </a>
              <a
                href="/admin/settings"
                class="text-xs font-medium text-slate-500 hover:text-emerald-600 transition-colors"
              >
                Settings
              </a>
            </div>
          </div>
        </div>

        <%!-- ═══ USER DROPDOWN ═══ --%>
        <% active_user = @current_merchant || @current_user %>
        <div id="user-dropdown" class="relative" phx-click-away={JS.hide(to: "#user-panel")}>
          <button
            phx-click={JS.toggle(to: "#user-panel") |> JS.hide(to: "#notif-panel")}
            class="flex items-center gap-2 p-1.5 pr-2 rounded-xl hover:bg-slate-100 transition-colors cursor-pointer"
          >
            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-xs font-bold text-white ring-2 ring-emerald-500/20 overflow-hidden">
              <%= if active_user && Map.get(active_user, :avatar_url) do %>
                <img src={active_user.avatar_url} alt="" class="w-full h-full object-cover" />
              <% else %>
                {EmakolaWeb.LayoutHelpers.user_initials(active_user)}
              <% end %>
            </div>
            <span class="hidden sm:block text-sm font-medium text-slate-700 max-w-[120px] truncate">
              {if active_user && Map.get(active_user, :name),
                do: active_user.name |> String.split(" ") |> List.first(),
                else: "Account"}
            </span>
            <svg
              class="hidden sm:block w-4 h-4 text-slate-400"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 8.25l-7.5 7.5-7.5-7.5"
              />
            </svg>
          </button>

          <div
            id="user-panel"
            class={
              [
                "hidden absolute right-0 top-full mt-2 w-80 bg-white rounded-2xl",
                "shadow-2xl shadow-slate-200/80 border border-slate-200/80 z-50",
                # The admin shell is `h-screen` so the page itself never scrolls.
                # Without a viewport cap this panel runs past the fold and its
                # last item ("Sign out") becomes unclickable at 1280x800.
                "max-h-[calc(100vh-5rem)] overflow-y-auto overscroll-contain"
              ]
            }
          >
            <%!-- Profile header --%>
            <div class="px-5 pt-5 pb-4 bg-gradient-to-br from-slate-50 to-white border-b border-slate-100">
              <div class="flex items-start gap-3">
                <div class="w-12 h-12 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-sm font-bold text-white ring-2 ring-emerald-500/20 overflow-hidden shrink-0">
                  <%= if active_user && Map.get(active_user, :avatar_url) do %>
                    <img src={active_user.avatar_url} alt="" class="w-full h-full object-cover" />
                  <% else %>
                    {EmakolaWeb.LayoutHelpers.user_initials(active_user)}
                  <% end %>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-bold text-slate-900 truncate">
                    {if active_user && Map.get(active_user, :name),
                      do: active_user.name,
                      else: "Merchant"}
                  </p>
                  <p class="text-xs text-slate-500 truncate">
                    {if active_user, do: active_user.email, else: ""}
                  </p>
                  <%= if active_user && Map.get(active_user, :phone) do %>
                    <p class="text-xs text-slate-400 truncate mt-0.5">{active_user.phone}</p>
                  <% end %>
                </div>
                <a
                  href="/admin/settings"
                  class="shrink-0 p-1.5 rounded-lg hover:bg-slate-100 transition-colors"
                  title="Edit profile"
                >
                  <span class="material-symbols-outlined text-base text-slate-400">edit</span>
                </a>
              </div>

              <%!-- Store + Plan badges --%>
              <div class="flex items-center gap-2 mt-3">
                <%= if @current_store do %>
                  <div class="flex items-center gap-1.5 bg-emerald-50 text-emerald-700 text-[11px] font-semibold px-2.5 py-1 rounded-lg">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                    {@current_store.name}
                  </div>
                <% end %>
                <div class="flex items-center gap-1 bg-amber-50 text-amber-700 text-[11px] font-semibold px-2.5 py-1 rounded-lg">
                  <span class="material-symbols-outlined text-xs">workspace_premium</span>
                  {if assigns[:current_plan], do: @current_plan.name, else: "Growth"}
                </div>
              </div>
            </div>

            <%!-- Quick stats --%>
            <div class="grid grid-cols-3 divide-x divide-slate-100 border-b border-slate-100">
              <div class="px-3 py-3 text-center">
                <p class="text-base font-bold text-slate-900">
                  {if assigns[:product_count], do: @product_count, else: "-"}
                </p>
                <p class="text-[10px] text-slate-400 font-medium">Products</p>
              </div>
              <div class="px-3 py-3 text-center">
                <p class="text-base font-bold text-slate-900">
                  {if assigns[:order_count], do: @order_count, else: "-"}
                </p>
                <p class="text-[10px] text-slate-400 font-medium">Orders</p>
              </div>
              <div class="px-3 py-3 text-center">
                <p class="text-base font-bold text-slate-900">
                  {if assigns[:customer_count], do: @customer_count, else: "-"}
                </p>
                <p class="text-[10px] text-slate-400 font-medium">Customers</p>
              </div>
            </div>

            <%!-- Navigation --%>
            <div class="py-1.5">
              <p class="px-5 pt-2 pb-1 text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
                Manage
              </p>
              <a
                href="/dashboard"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">dashboard</span>
                Dashboard
              </a>
              <a
                href="/admin/products"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">inventory_2</span>
                Products
              </a>
              <a
                href="/admin/orders"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">receipt_long</span>
                Orders
              </a>
              <a
                href="/admin/customers"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">group</span> Customers
              </a>
              <a
                href="/admin/revenue"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">payments</span> Revenue
              </a>
            </div>

            <div class="mx-4 border-t border-slate-100"></div>

            <%!-- Settings & Tools --%>
            <div class="py-1.5">
              <p class="px-5 pt-2 pb-1 text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
                Settings
              </p>
              <a
                href="/admin/settings"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">settings</span>
                Store Settings
              </a>
              <a
                href="/admin/settings"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">person</span>
                Profile & Account
              </a>
              <a
                href="/admin/settings/notifications"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">
                  notifications
                </span>
                Notification Preferences
              </a>
              <%= if @current_store do %>
                <a
                  href={EmakolaWeb.Storefront.Path.store_path(@current_store.slug, "/")}
                  target="_blank"
                  class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
                >
                  <span class="material-symbols-outlined text-lg text-slate-400">storefront</span>
                  View Storefront
                  <span class="material-symbols-outlined text-sm text-slate-300 ml-auto">
                    open_in_new
                  </span>
                </a>
              <% end %>
            </div>

            <div class="mx-4 border-t border-slate-100"></div>

            <%!-- Help & Support --%>
            <div class="py-1.5">
              <a
                href="#"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">help</span>
                Help & Support
              </a>
              <a
                href="#"
                class="flex items-center gap-3 px-5 py-2 text-sm text-slate-700 hover:bg-slate-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg text-slate-400">keyboard</span>
                Keyboard Shortcuts
                <kbd class="ml-auto text-[10px] text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded border border-slate-200 font-mono">
                  ?
                </kbd>
              </a>
            </div>

            <div class="mx-4 border-t border-slate-100"></div>

            <%!-- Sign out --%>
            <div class="py-1.5">
              <.link
                href="/auth/session"
                method="delete"
                class="flex items-center gap-3 px-5 py-2.5 text-sm text-rose-600 hover:bg-rose-50 transition-colors"
              >
                <span class="material-symbols-outlined text-lg">logout</span> Sign out
              </.link>
            </div>

            <%!-- Store footer --%>
            <%= if @current_store do %>
              <div class="px-5 py-3 bg-slate-50/80 border-t border-slate-100">
                <div class="flex items-center gap-2">
                  <div class="w-7 h-7 rounded-lg bg-emerald-600 flex items-center justify-center">
                    <span class="text-[11px] font-bold text-white">
                      {@current_store.name |> String.first() |> String.upcase()}
                    </span>
                  </div>
                  <div class="min-w-0 flex-1">
                    <p class="text-xs font-semibold text-slate-700 truncate">
                      {@current_store.name}
                    </p>
                    <p class="text-[10px] text-slate-400">
                      {@current_store.currency} store
                      <%= if @current_store.city do %>
                        <span class="mx-1">-</span> {@current_store.city}
                      <% end %>
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </header>
    """
  end
end
