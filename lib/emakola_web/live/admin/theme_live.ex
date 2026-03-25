defmodule EmakolaWeb.Admin.ThemeLive do
  @moduledoc """
  Theme customizer admin page with full-screen preview and floating drawer.

  Layout: Full-screen with a floating drawer on the right (320px, slides in/out).
  The preview area renders the storefront in an iframe that reloads after saving.
  """

  use EmakolaWeb, :live_view

  alias Emakola.Themes.ThemeResolver

  @themes [
    %{
      id: "market",
      name: "Market",
      description: "Clean, modern commerce",
      colors: %{primary: "#2563EB", accent: "#0F172A", background: "#FFFFFF"}
    },
    %{
      id: "atelier",
      name: "Atelier",
      description: "Premium editorial fashion",
      colors: %{primary: "#CA8A04", accent: "#1C1917", background: "#FAFAF9"}
    },
    %{
      id: "vibrant",
      name: "Vibrant",
      description: "Bold, energetic West African",
      colors: %{primary: "#DC2626", accent: "#7C2D12", background: "#FFFBEB"}
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store
    resolved = ThemeResolver.resolve(store.theme_config)

    socket =
      socket
      |> assign(
        page_title: "Theme",
        active_nav: :theme,
        store: store,
        themes: @themes,
        drawer_open: true,
        iframe_key: 0,
        theme_id: resolved.theme_id,
        colors: %{
          primary: resolved.colors.primary,
          accent: resolved.colors.accent,
          background: resolved.colors.background
        },
        hero: %{
          title: resolved.hero.title,
          subtitle: resolved.hero.subtitle,
          cta_text: resolved.hero.cta_text
        },
        sections: %{
          hero: resolved.sections.hero,
          categories: resolved.sections.categories,
          featured_products: resolved.sections.featured_products,
          brand_story: resolved.sections.brand_story,
          instagram: Map.get(resolved.sections, :instagram, false),
          newsletter: Map.get(resolved.sections, :newsletter, true)
        },
        saved: false
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-72px)] relative" id="theme-customizer">
      <%!-- Preview iframe --%>
      <div class={[
        "flex-1 bg-slate-100 p-4 transition-all duration-300",
        if(@drawer_open, do: "mr-80", else: "")
      ]}>
        <div class="flex items-center justify-between mb-3">
          <h1 class="text-lg font-bold text-slate-800">Theme Customizer</h1>
          <button
            phx-click="toggle_drawer"
            class="flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-slate-600 bg-white rounded-lg border border-slate-200 hover:bg-slate-50 transition-colors"
          >
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
                d={
                  if @drawer_open,
                    do: "M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3",
                    else: "M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"
                }
              />
            </svg>
            {if @drawer_open, do: "Hide Panel", else: "Customize"}
          </button>
        </div>
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden h-[calc(100%-48px)]">
          <iframe
            id={"preview-frame-#{@iframe_key}"}
            src={"/s/#{@store.slug}/"}
            class="w-full h-full border-0"
            title="Storefront preview"
          >
          </iframe>
        </div>
      </div>

      <%!-- Floating drawer --%>
      <div
        id="theme-drawer"
        class={[
          "fixed right-0 top-[72px] bottom-0 w-80 bg-white border-l border-slate-200 shadow-xl overflow-y-auto transition-transform duration-300 z-30",
          if(@drawer_open, do: "translate-x-0", else: "translate-x-full")
        ]}
      >
        <div class="p-5 space-y-6">
          <%!-- Theme selector --%>
          <div>
            <h2 class="text-sm font-semibold text-slate-700 mb-3">Theme</h2>
            <div class="space-y-2">
              <button
                :for={theme <- @themes}
                phx-click="select_theme"
                phx-value-theme-id={theme.id}
                class={[
                  "w-full flex items-center gap-3 p-3 rounded-xl border-2 transition-all text-left",
                  if(theme.id == @theme_id,
                    do: "border-emerald-500 bg-emerald-50/50 ring-1 ring-emerald-500/20",
                    else: "border-slate-200 hover:border-slate-300 bg-white"
                  )
                ]}
              >
                <div class="flex gap-1 shrink-0">
                  <div class="w-4 h-4 rounded-full" style={"background: #{theme.colors.primary}"}>
                  </div>
                  <div class="w-4 h-4 rounded-full" style={"background: #{theme.colors.accent}"}>
                  </div>
                  <div
                    class="w-4 h-4 rounded-full border border-slate-200"
                    style={"background: #{theme.colors.background}"}
                  >
                  </div>
                </div>
                <div class="min-w-0">
                  <p class="text-sm font-semibold text-slate-800">{theme.name}</p>
                  <p class="text-xs text-slate-500 truncate">{theme.description}</p>
                </div>
              </button>
            </div>
          </div>

          <%!-- Colors --%>
          <div>
            <h2 class="text-sm font-semibold text-slate-700 mb-3">Colors</h2>
            <div class="space-y-3">
              <.color_input label="Primary" field="primary" value={@colors.primary} />
              <.color_input label="Accent" field="accent" value={@colors.accent} />
              <.color_input label="Background" field="background" value={@colors.background} />
            </div>
          </div>

          <%!-- Hero settings --%>
          <div>
            <h2 class="text-sm font-semibold text-slate-700 mb-3">Hero</h2>
            <div class="space-y-3">
              <div>
                <label class="block text-xs font-medium text-slate-500 mb-1">Title</label>
                <input
                  type="text"
                  value={@hero.title}
                  phx-change="update_hero"
                  phx-debounce="300"
                  name="title"
                  class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-500 mb-1">Subtitle</label>
                <input
                  type="text"
                  value={@hero.subtitle}
                  phx-change="update_hero"
                  phx-debounce="300"
                  name="subtitle"
                  class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-slate-500 mb-1">CTA Text</label>
                <input
                  type="text"
                  value={@hero.cta_text}
                  phx-change="update_hero"
                  phx-debounce="300"
                  name="cta_text"
                  class="w-full bg-white border border-slate-300 rounded-lg px-3 py-2 text-sm text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>
          </div>

          <%!-- Section toggles --%>
          <div>
            <h2 class="text-sm font-semibold text-slate-700 mb-3">Sections</h2>
            <div class="space-y-2">
              <.section_toggle label="Hero" field="hero" enabled={@sections.hero} />
              <.section_toggle label="Categories" field="categories" enabled={@sections.categories} />
              <.section_toggle
                label="Featured Products"
                field="featured_products"
                enabled={@sections.featured_products}
              />
              <.section_toggle
                label="Brand Story"
                field="brand_story"
                enabled={@sections.brand_story}
              />
              <.section_toggle label="Instagram" field="instagram" enabled={@sections.instagram} />
              <.section_toggle label="Newsletter" field="newsletter" enabled={@sections.newsletter} />
            </div>
          </div>

          <%!-- Actions --%>
          <div class="space-y-2 pt-2 border-t border-slate-200">
            <button
              phx-click="save_theme"
              class="w-full px-4 py-2.5 text-sm font-semibold text-white bg-emerald-600 hover:bg-emerald-700 rounded-xl transition-colors active:scale-[0.98]"
            >
              {if @saved, do: "Saved!", else: "Save Changes"}
            </button>
            <button
              phx-click="reset_defaults"
              class="w-full px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 hover:bg-slate-100 rounded-xl transition-colors"
            >
              Reset to Default
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  defp color_input(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="w-8 h-8 rounded-lg border border-slate-200 shrink-0" style={"background: #{@value}"}>
      </div>
      <div class="flex-1">
        <label class="block text-xs font-medium text-slate-500 mb-0.5">{@label}</label>
        <input
          type="text"
          value={@value}
          phx-change="update_color"
          phx-debounce="300"
          name={@field}
          maxlength="7"
          class="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-sm text-slate-800 font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
        />
      </div>
    </div>
    """
  end

  defp section_toggle(assigns) do
    ~H"""
    <label class="flex items-center justify-between p-2.5 rounded-lg hover:bg-slate-50 cursor-pointer group">
      <span class="text-sm text-slate-700 font-medium">{@label}</span>
      <div class="relative">
        <input
          type="checkbox"
          checked={@enabled}
          phx-click="toggle_section"
          phx-value-section={@field}
          class="sr-only peer"
        />
        <div class="w-9 h-5 bg-slate-300 peer-checked:bg-emerald-500 rounded-full transition-colors">
        </div>
        <div class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow-sm transition-transform peer-checked:translate-x-4">
        </div>
      </div>
    </label>
    """
  end

  # ── Events ──

  @impl true
  def handle_event("select_theme", %{"theme-id" => theme_id}, socket) do
    theme_mod = ThemeResolver.theme_module(theme_id)
    defaults = theme_mod.defaults()

    socket =
      socket
      |> assign(
        theme_id: theme_id,
        colors: %{
          primary: defaults.colors.primary,
          accent: defaults.colors.accent,
          background: defaults.colors.background
        },
        hero: %{
          title: defaults.hero.title,
          subtitle: defaults.hero.subtitle,
          cta_text: defaults.hero.cta_text
        },
        sections: %{
          hero: defaults.sections[:hero] || true,
          categories: defaults.sections[:categories] || true,
          featured_products:
            defaults.sections[:featured_products] || defaults.sections[:featured] || true,
          brand_story: defaults.sections[:brand_story] || defaults.sections[:about] || true,
          instagram: defaults.sections[:instagram] || false,
          newsletter: defaults.sections[:newsletter] || true
        },
        saved: false
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_color", params, socket) do
    colors = socket.assigns.colors

    colors =
      Enum.reduce(["primary", "accent", "background"], colors, fn field, acc ->
        case Map.get(params, field) do
          nil -> acc
          value -> Map.put(acc, String.to_existing_atom(field), value)
        end
      end)

    {:noreply, assign(socket, colors: colors, saved: false)}
  end

  @impl true
  def handle_event("update_hero", params, socket) do
    hero = socket.assigns.hero

    hero =
      Enum.reduce(["title", "subtitle", "cta_text"], hero, fn field, acc ->
        case Map.get(params, field) do
          nil -> acc
          value -> Map.put(acc, String.to_existing_atom(field), value)
        end
      end)

    {:noreply, assign(socket, hero: hero, saved: false)}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    sections = Map.update!(socket.assigns.sections, section_atom, &(!&1))
    {:noreply, assign(socket, sections: sections, saved: false)}
  end

  @impl true
  def handle_event("save_theme", _params, socket) do
    theme_config = %{
      "theme" => socket.assigns.theme_id,
      "colors" => %{
        "primary" => socket.assigns.colors.primary,
        "accent" => socket.assigns.colors.accent,
        "background" => socket.assigns.colors.background
      },
      "hero" => %{
        "title" => socket.assigns.hero.title,
        "subtitle" => socket.assigns.hero.subtitle,
        "cta_text" => socket.assigns.hero.cta_text
      },
      "sections" => %{
        "hero" => socket.assigns.sections.hero,
        "categories" => socket.assigns.sections.categories,
        "featured_products" => socket.assigns.sections.featured_products,
        "brand_story" => socket.assigns.sections.brand_story,
        "instagram" => socket.assigns.sections.instagram,
        "newsletter" => socket.assigns.sections.newsletter
      }
    }

    case socket.assigns.store
         |> Ash.Changeset.for_update(:update_settings, %{theme_config: theme_config})
         |> Ash.update() do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(store: updated_store, saved: true, iframe_key: socket.assigns.iframe_key + 1)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to save theme changes.")}
    end
  end

  @impl true
  def handle_event("reset_defaults", _params, socket) do
    theme_mod = ThemeResolver.theme_module(socket.assigns.theme_id)
    defaults = theme_mod.defaults()

    socket =
      socket
      |> assign(
        colors: %{
          primary: defaults.colors.primary,
          accent: defaults.colors.accent,
          background: defaults.colors.background
        },
        hero: %{
          title: defaults.hero.title,
          subtitle: defaults.hero.subtitle,
          cta_text: defaults.hero.cta_text
        },
        sections: %{
          hero: defaults.sections[:hero] || true,
          categories: defaults.sections[:categories] || true,
          featured_products:
            defaults.sections[:featured_products] || defaults.sections[:featured] || true,
          brand_story: defaults.sections[:brand_story] || defaults.sections[:about] || true,
          instagram: defaults.sections[:instagram] || false,
          newsletter: defaults.sections[:newsletter] || true
        },
        saved: false
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_drawer", _params, socket) do
    {:noreply, assign(socket, drawer_open: !socket.assigns.drawer_open)}
  end
end
