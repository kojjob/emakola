defmodule EmakolaWeb.Admin.DesignSectionsLive do
  @moduledoc """
  Section editor — reorder, show/hide, and publish the active theme's
  home-page sections (spec: docs/superpowers/specs/2026-07-11-section-editor-design.md).

  All mutations happen on a draft assign; nothing persists to the store
  until Publish. Add/remove section controls arrive in Task 4.

  The right-hand preview renders the DRAFT layout in-process through
  `Emakola.Themes.SectionRenderer.home/1` — see `render_preview/1`.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias Emakola.Themes.HomeSections
  alias Emakola.Themes.Sections
  alias Emakola.Themes.ThemeResolver

  @preview_product_limit 6

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Sections", active_nav: :design)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        resolved = ThemeResolver.resolve(store.theme_config || %{}, store)
        theme_module = ThemeResolver.theme_module(resolved.theme_id)

        # Preview storefront data (products/categories/delivery zones) is
        # only fetched on the connected mount — never the disconnected one
        # — so this admin-only page never doubles up on DB reads the way
        # the public storefront's SEO-driven mount intentionally does.
        {products, categories, delivery_zones} =
          if connected?(socket) do
            {load_preview_products(store), load_preview_categories(store),
             load_preview_delivery_zones(store)}
          else
            {[], [], []}
          end

        {:ok,
         assign(socket,
           page_title: "Sections",
           active_nav: :design,
           store: store,
           theme_module: theme_module,
           theme: resolved,
           draft: HomeSections.effective_layout(store, theme_module),
           dirty: false,
           products: products,
           categories: categories,
           delivery_zones: delivery_zones
         )}
    end
  end

  @impl true
  def handle_event("toggle_section", %{"id" => id}, socket) do
    draft =
      Enum.map(socket.assigns.draft, fn entry ->
        if entry["id"] == id, do: Map.update!(entry, "enabled", &(!&1)), else: entry
      end)

    {:noreply, assign(socket, draft: draft, dirty: true)}
  end

  @impl true
  def handle_event("move_section", %{"id" => id, "dir" => dir}, socket)
      when dir in ["up", "down"] do
    {:noreply, assign(socket, draft: swap_adjacent(socket.assigns.draft, id, dir), dirty: true)}
  end

  # An unrecognized direction (only reachable by tampering with the payload)
  # leaves the draft untouched rather than crashing the editor.
  def handle_event("move_section", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("publish", _params, socket) do
    %{store: store, theme_module: theme_module, draft: draft} = socket.assigns
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case HomeSections.put_layout(actor, store, theme_module.id(), draft) do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(store: updated_store, dirty: false)
         |> put_flash(:info, "Sections published to your live storefront.")}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(socket, :error, "You don't have permission to update this store's sections.")}

      {:error, :unknown_theme} ->
        {:noreply, put_flash(socket, :error, "Unknown theme — couldn't publish sections.")}

      {:error, _other} ->
        {:noreply, put_flash(socket, :error, "Couldn't publish your sections. Please try again.")}
    end
  end

  @impl true
  def handle_event("reset_layout", _params, socket) do
    %{store: store, theme_module: theme_module} = socket.assigns
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case HomeSections.clear_layout(actor, store, theme_module.id()) do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(
           store: updated_store,
           draft: HomeSections.default_layout(theme_module),
           dirty: false
         )
         |> put_flash(:info, "Sections reset to the theme's defaults.")}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(socket, :error, "You don't have permission to update this store's sections.")}

      {:error, :unknown_theme} ->
        {:noreply, put_flash(socket, :error, "Unknown theme — couldn't reset sections.")}

      {:error, _other} ->
        {:noreply, put_flash(socket, :error, "Couldn't reset your sections. Please try again.")}
    end
  end

  # ── Preview data loading ────────────────────────────────────────
  # Mirrors EmakolaWeb.Storefront.StoreLive's home mount (store_live.ex)
  # context calls, with a small limit — the preview doesn't need the full
  # catalog, just enough for every theme section to have real data to
  # render (grids, category pills/circles, delivery-zone copy).

  defp load_preview_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.limit(@preview_product_limit)
    |> Ash.read!(authorize?: false)
  end

  defp load_preview_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp load_preview_delivery_zones(store) do
    Emakola.Shipping.list_delivery_zones!(store.id)
    |> Enum.filter(& &1.active)
  rescue
    exception ->
      Logger.error(
        "[design_sections_live] loading delivery zones raised: #{Exception.message(exception)}"
      )

      []
  end

  # Reorder is a pure adjacent swap on the draft list; out-of-range moves
  # (first row "up", last row "down") are a no-op rather than an error.
  defp swap_adjacent(entries, id, dir) do
    index = Enum.find_index(entries, &(&1["id"] == id))
    target = if dir == "up", do: index && index - 1, else: index && index + 1

    if index && target && target >= 0 && target < length(entries) do
      entries
      |> List.replace_at(index, Enum.at(entries, target))
      |> List.replace_at(target, Enum.at(entries, index))
    else
      entries
    end
  end

  # Resolves each draft entry's display label from the section registry ONCE
  # per render (Sections.resolve/1 rebuilds the registry index on every call,
  # so the template must not call it per-attribute). Saved types that no
  # longer resolve (a theme's section list changed since the layout was
  # saved) are marked `missing?` and render as an inert row instead of
  # crashing the editor.
  defp rows(draft) do
    last_index = length(draft) - 1

    for {entry, index} <- Enum.with_index(draft) do
      {label, missing?} =
        case Sections.resolve(entry["type"]) do
          {:ok, {module, _meta}} -> {module.label(), false}
          :error -> {entry["type"] || entry["id"], true}
        end

      %{
        id: entry["id"],
        label: label,
        missing?: missing?,
        enabled?: entry["enabled"] == true,
        first?: index == 0,
        last?: index == last_index
      }
    end
  end

  # ── Live preview ────────────────────────────────────────────────
  # Renders the DRAFT layout — not the saved one — by swapping a
  # struct-copied store's theme_config into a preview store, mirroring
  # HomeSections.put_layout/4's own map construction: `home_sections` is
  # seeded with the envelope key when absent (put_in on a missing key
  # path would raise), then the active theme's entry is replaced with the
  # in-memory draft. This copy is never persisted — it exists only for
  # the duration of this render — so publishing remains the only way to
  # write the draft to the database.
  attr :store, :map, required: true
  attr :theme_module, :atom, required: true
  attr :theme, :map, required: true
  attr :draft, :list, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :delivery_zones, :list, required: true

  defp render_preview(assigns) do
    section_assigns = %{
      __changed__: nil,
      preview: true,
      store: preview_store(assigns.store, assigns.theme_module, assigns.draft),
      theme_module: assigns.theme_module,
      theme: assigns.theme,
      products: assigns.products,
      categories: assigns.categories,
      delivery_zones: assigns.delivery_zones
    }

    assigns =
      assigns
      |> assign(:section_assigns, section_assigns)
      |> assign(:frame_style, theme_style_vars(assigns.theme))

    ~H"""
    <div style={@frame_style} class="mx-auto max-w-[1280px] bg-white">
      {Emakola.Themes.SectionRenderer.home(@section_assigns)}
    </div>
    """
  end

  defp preview_store(store, theme_module, draft) do
    existing = store.theme_config || %{}
    section_map = Map.get(existing, "home_sections", %{"v" => 1})
    config = Map.put(existing, "home_sections", Map.put(section_map, theme_module.id(), draft))
    %{store | theme_config: config}
  end

  # Only the three CSS custom properties section templates actually
  # consume (`var(--theme-primary, …)` etc.) — no section or shared
  # component under lib/emakola/themes references the design-token
  # font/button-radius variables the storefront layout also defines, so
  # reproducing those here would be dead weight. Colors are merchant
  # input flowing into a style attribute, so they go through the same
  # hex-only allowlist the storefront layout uses.
  defp theme_style_vars(theme) do
    colors = Map.get(theme, :colors) || %{}

    primary = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:primary], "#6366F1")
    accent = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:accent], "#1E293B")
    background = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:background], "#FFFFFF")

    "--theme-primary: #{primary}; --theme-accent: #{accent}; --theme-bg: #{background};"
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :rows, rows(assigns.draft))

    ~H"""
    <div
      id="unsaved-guard"
      phx-hook="UnsavedChanges"
      data-dirty={to_string(@dirty)}
      class="max-w-[1600px] mx-auto px-4 sm:px-6 pb-16"
    >
      <.admin_page_header
        title="Sections"
        subtitle="Reorder, show, or hide sections on your store's home page"
      >
        <.admin_button
          variant={:secondary}
          phx-click="reset_layout"
          data-confirm="Reset to the theme's default sections? Any unpublished changes will be lost."
        >
          Reset to defaults
        </.admin_button>
        <.admin_button phx-click="publish" disabled={!@dirty}>
          Publish
        </.admin_button>
      </.admin_page_header>

      <div
        :if={@dirty}
        class="mb-5 flex items-center gap-2 rounded-control border border-warning/30 bg-warning-soft px-4 py-3 text-sm font-medium text-warning"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        You have unpublished changes — click Publish to make them live.
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-12 gap-5">
        <section class="lg:col-span-6">
          <.admin_card padding={:none} class="divide-y divide-border">
            <div
              :for={row <- @rows}
              class={["flex items-center gap-3 px-4 py-3.5", row.missing? && "opacity-60"]}
            >
              <.icon name="hero-bars-2" class="size-4 shrink-0 text-text-muted" />

              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-text">{row.label}</p>
              </div>

              <span
                :if={row.missing?}
                class="inline-flex items-center whitespace-nowrap rounded-full bg-danger-soft px-2.5 py-0.5 text-xs font-semibold text-danger"
              >
                Missing section
              </span>
              <span
                :if={!row.missing? && !row.enabled?}
                class="inline-flex items-center whitespace-nowrap rounded-full bg-surface-subtle px-2.5 py-0.5 text-xs font-semibold text-text-muted"
              >
                Hidden
              </span>

              <%!-- Missing sections render inert placeholders — no phx-click
              wiring at all, so a stale/removed section type can never
              trigger a handler. --%>
              <div :if={row.missing?} class="flex items-center gap-0.5 opacity-30">
                <span class="p-1.5">
                  <.icon name="hero-chevron-up" class="size-4 text-text-muted" />
                </span>
                <span class="p-1.5">
                  <.icon name="hero-chevron-down" class="size-4 text-text-muted" />
                </span>
              </div>
              <div :if={!row.missing?} class="flex items-center gap-0.5">
                <button
                  type="button"
                  phx-click="move_section"
                  phx-value-id={row.id}
                  phx-value-dir="up"
                  disabled={row.first?}
                  class="rounded-control p-1.5 text-text-muted transition-colors hover:bg-surface-subtle hover:text-text disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
                  aria-label={"Move #{row.label} up"}
                >
                  <.icon name="hero-chevron-up" class="size-4" />
                </button>
                <button
                  type="button"
                  phx-click="move_section"
                  phx-value-id={row.id}
                  phx-value-dir="down"
                  disabled={row.last?}
                  class="rounded-control p-1.5 text-text-muted transition-colors hover:bg-surface-subtle hover:text-text disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
                  aria-label={"Move #{row.label} down"}
                >
                  <.icon name="hero-chevron-down" class="size-4" />
                </button>
              </div>

              <span
                :if={row.missing?}
                aria-hidden="true"
                class="relative inline-flex h-6 w-11 shrink-0 items-center rounded-full border border-border bg-surface-subtle opacity-40"
              >
                <span class="inline-block size-4 translate-x-1 transform rounded-full bg-white shadow" />
              </span>
              <button
                :if={!row.missing?}
                type="button"
                phx-click="toggle_section"
                phx-value-id={row.id}
                role="switch"
                aria-checked={to_string(row.enabled?)}
                aria-label={"Toggle #{row.label}"}
                class={[
                  "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors",
                  if(row.enabled?,
                    do: "bg-primary",
                    else: "bg-surface-subtle border border-border"
                  )
                ]}
              >
                <span class={[
                  "inline-block size-4 transform rounded-full bg-white shadow transition-transform",
                  if(row.enabled?, do: "translate-x-6", else: "translate-x-1")
                ]} />
              </button>

              <button
                type="button"
                disabled
                class="p-1.5 text-text-muted opacity-30"
                aria-label="Section settings (coming soon)"
              >
                <.icon name="hero-chevron-right" class="size-4" />
              </button>
            </div>
          </.admin_card>
        </section>

        <aside class="lg:col-span-6 lg:sticky lg:top-4 lg:self-start">
          <.admin_card padding={:none} class="overflow-hidden">
            <div class="flex items-center gap-3 border-b border-border bg-surface-subtle px-4 py-2.5">
              <div class="flex items-center gap-1.5" aria-hidden="true">
                <span class="size-2.5 rounded-full bg-slate-300"></span>
                <span class="size-2.5 rounded-full bg-slate-300"></span>
                <span class="size-2.5 rounded-full bg-slate-300"></span>
              </div>
              <div class="flex-1 truncate rounded-control border border-border bg-surface px-3 py-1 text-center text-xs text-text-muted">
                {@store.slug}.makola.io
              </div>
              <span class="inline-flex shrink-0 items-center gap-1.5 text-xs font-medium text-text-muted">
                <span class="size-1.5 rounded-full bg-success"></span> Live preview
              </span>
            </div>
            <div class="max-h-[calc(100vh-14rem)] overflow-y-auto">
              <.render_preview
                store={@store}
                theme_module={@theme_module}
                theme={@theme}
                draft={@draft}
                products={@products}
                categories={@categories}
                delivery_zones={@delivery_zones}
              />
            </div>
          </.admin_card>
        </aside>
      </div>
    </div>
    """
  end
end
