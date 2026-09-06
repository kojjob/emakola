defmodule EmakolaWeb.Platform.AuditLogComponents do
  @moduledoc """
  Function components for the platform audit ledger: the header with the
  live counter, severity and range selects and the export link; the search
  and family-chip toolbar; the register with its day bands; the footer.
  Rows are `AuditLogEntryComponents.entry_row/1`.
  """
  use Phoenix.Component

  import EmakolaWeb.AdminComponents, only: [filter_tabs: 1]
  import EmakolaWeb.CoreComponents, only: [icon: 1]
  import EmakolaWeb.Platform.AuditLogEntryComponents, only: [entry_row: 1, ledger_grid: 0]
  import EmakolaWeb.PlatformComponents, only: [platform_empty_state: 1]

  alias Emakola.Accounts.PlatformAuditFamilies, as: Families
  alias Emakola.Accounts.PlatformAuditSearch, as: Search

  @select_class "rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400"

  attr :loaded?, :boolean, required: true
  attr :entries, :any, required: true
  attr :actors, :map, required: true
  attr :end_of_timeline?, :boolean, required: true
  attr :search, Search, required: true
  attr :counts, :map, required: true
  attr :loaded_count, :integer, required: true
  attr :new_count, :integer, required: true

  def audit_log_page(assigns) do
    %{search: search} = assigns

    assigns =
      assign(assigns,
        total: Map.get(assigns.counts, search.family, 0),
        filter_form:
          to_form(%{"severity" => to_string(search.severity), "range" => to_string(search.range)}),
        search_form: to_form(%{"q" => search.q})
      )

    ~H"""
    <div class="p-6 lg:p-8 max-w-6xl mx-auto">
      <div class="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Audit log</h1>
          <p class="text-sm text-gray-500 mt-1">
            Every action platform staff take. Append-only, kept forever.
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <.live_pill new_count={@new_count} />
          <.form
            for={@filter_form}
            id="audit-filters"
            phx-change="filter"
            class="flex items-center gap-2"
          >
            <select name="severity" aria-label="Severity" class={select_class()}>
              <option
                :for={{key, label} <- Search.severities()}
                value={key}
                selected={key == @search.severity}
              >
                {label}
              </option>
            </select>
            <select name="range" aria-label="Date range" class={select_class()}>
              <option
                :for={{key, label} <- Search.ranges()}
                value={key}
                selected={key == @search.range}
              >
                {label}
              </option>
            </select>
          </.form>
          <a
            id="audit-export"
            href={export_href(@search)}
            class="inline-flex items-center gap-2 rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 transition-colors"
          >
            <.icon name="hero-arrow-down-tray" class="size-4 text-gray-500" /> Export CSV
          </a>
        </div>
      </div>

      <p :if={!@loaded?} class="text-sm text-gray-500">Loading audit log…</p>

      <div :if={@loaded?}>
        <div class="mb-4 flex flex-col lg:flex-row lg:items-center gap-3">
          <.form
            for={@search_form}
            id="audit-search"
            phx-change="filter"
            phx-submit="filter"
            class="relative lg:w-72 shrink-0"
          >
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-slate-400 pointer-events-none"
            />
            <input
              type="search"
              name="q"
              value={@search.q}
              phx-debounce="300"
              autocomplete="off"
              placeholder="Actor, store, email or IP"
              class="w-full pl-9 pr-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
            />
          </.form>
          <.filter_tabs
            id="audit-families"
            tabs={family_tabs(@counts)}
            current={@search.family}
            event="filter"
            param="family"
          />
        </div>

        <.platform_empty_state
          :if={@loaded_count == 0}
          icon="hero-clipboard-document-list"
          title="No events match"
          description="Try a wider date range, another family, or clear the search."
        />

        <div
          :if={@loaded_count > 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden"
        >
          <div class={[
            "hidden lg:grid",
            ledger_grid(),
            "px-6 py-3 bg-gray-50 border-b border-gray-100 text-xs font-medium text-gray-500 uppercase tracking-wider"
          ]}>
            <span>Time</span>
            <span>Event</span>
            <span>Actor</span>
            <span>Target</span>
            <span>Details</span>
            <span>IP</span>
          </div>
          <ol id="audit-entries" phx-update="stream">
            <.ledger_item
              :for={{dom_id, item} <- @entries}
              dom_id={dom_id}
              item={item}
              actors={@actors}
            />
          </ol>
          <div class="flex items-center justify-between px-6 py-3.5 border-t border-gray-100">
            <span id="audit-total" class="text-sm text-gray-500 tabular-nums">
              Showing {@loaded_count} of {@total}
            </span>
            <button
              :if={!@end_of_timeline?}
              id="load-more"
              phx-click="load_more"
              class="rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors cursor-pointer"
            >
              Load 50 more
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :dom_id, :string, required: true
  attr :item, :map, required: true
  attr :actors, :map, required: true

  # A stream item is a day band or an entry; either way exactly one <li>
  # carrying the stream's dom id, which is what phx-update="stream" needs.
  defp ledger_item(%{item: %{kind: :band}} = assigns) do
    ~H"""
    <li id={@dom_id} class="flex items-center gap-3 px-6 py-2 bg-slate-50 border-b border-gray-100">
      <span class="text-xs font-semibold text-slate-700">{@item.label}</span>
    </li>
    """
  end

  defp ledger_item(assigns) do
    ~H"""
    <.entry_row dom_id={@dom_id} entry={@item.entry} actors={@actors} />
    """
  end

  attr :new_count, :integer, required: true

  defp live_pill(%{new_count: 0} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-700">
      <span class="h-1.5 w-1.5 rounded-full bg-emerald-500"></span> Live
    </span>
    """
  end

  defp live_pill(assigns) do
    ~H"""
    <button
      id="show-new"
      phx-click="show_new"
      class="inline-flex items-center gap-1.5 rounded-full bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-700 transition-colors cursor-pointer"
    >
      {@new_count} new · show
    </button>
    """
  end

  defp select_class, do: @select_class

  defp family_tabs(counts) do
    [
      %{key: :all, label: "All", count: counts[:all]}
      | for(
          {key, label} <- Families.families(),
          do: %{key: key, label: label, count: counts[key]}
        )
    ]
  end

  defp export_href(search) do
    case Search.to_params(search) do
      params when params == %{} -> "/platform/audit-log/export"
      params -> "/platform/audit-log/export?" <> URI.encode_query(params)
    end
  end
end
