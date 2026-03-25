defmodule EmakolaWeb.Admin.ThemeLive do
  @moduledoc """
  Theme customizer — visual, low-literacy friendly.
  Large theme preview cards, tap-to-select colors, visual toggles.
  """

  use EmakolaWeb, :live_view

  alias Emakola.Themes.ThemeResolver

  @themes [
    %{
      id: "market",
      name: "Market",
      description: "Simple & clean",
      icon: "storefront",
      colors: %{primary: "#2563EB", accent: "#0F172A", background: "#FFFFFF"},
      preview_bg: "bg-white",
      preview_accent: "bg-blue-600"
    },
    %{
      id: "atelier",
      name: "Atelier",
      description: "Premium & elegant",
      icon: "diamond",
      colors: %{primary: "#CA8A04", accent: "#1C1917", background: "#FAFAF9"},
      preview_bg: "bg-stone-50",
      preview_accent: "bg-yellow-600"
    },
    %{
      id: "vibrant",
      name: "Vibrant",
      description: "Bold & colorful",
      icon: "palette",
      colors: %{primary: "#DC2626", accent: "#7C2D12", background: "#FFFBEB"},
      preview_bg: "bg-amber-50",
      preview_accent: "bg-red-600"
    }
  ]

  @color_presets [
    %{name: "Gold", hex: "#CA8A04", class: "bg-yellow-600"},
    %{name: "Blue", hex: "#2563EB", class: "bg-blue-600"},
    %{name: "Red", hex: "#DC2626", class: "bg-red-600"},
    %{name: "Green", hex: "#059669", class: "bg-emerald-600"},
    %{name: "Purple", hex: "#7C3AED", class: "bg-purple-600"},
    %{name: "Pink", hex: "#DB2777", class: "bg-pink-600"},
    %{name: "Orange", hex: "#EA580C", class: "bg-orange-600"},
    %{name: "Teal", hex: "#0D9488", class: "bg-teal-600"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Theme", active_nav: :theme)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        resolved = ThemeResolver.resolve(store.theme_config || %{})

        socket =
          socket
          |> assign(
            page_title: "Theme",
            active_nav: :theme,
            store: store,
            themes: @themes,
            color_presets: @color_presets,
            theme_id: resolved.theme_id,
            primary_color: resolved.colors.primary,
            sections: %{
              hero: Map.get(resolved.sections, :hero, true),
              categories: Map.get(resolved.sections, :categories, true),
              featured_products: Map.get(resolved.sections, :featured_products, true),
              brand_story: Map.get(resolved.sections, :brand_story, true),
              newsletter: Map.get(resolved.sections, :newsletter, true)
            },
            saving: false,
            saved: false
          )

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-8">
      <%!-- Header --%>
      <div class="text-center">
        <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Choose Your Look</h1>
        <p class="text-sm text-slate-500 mt-1">Pick a style for your store</p>
      </div>

      <%!-- STEP 1: Theme Selection — Large visual cards --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">1</span>
          </div>
          <h2 class="text-lg font-bold text-slate-800">Pick a Theme</h2>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <button
            :for={theme <- @themes}
            phx-click="select_theme"
            phx-value-theme-id={theme.id}
            class={[
              "group relative rounded-2xl overflow-hidden transition-all text-left",
              if(theme.id == @theme_id,
                do: "ring-4 ring-emerald-500 shadow-lg scale-[1.02]",
                else: "ring-1 ring-slate-200 hover:ring-slate-300 hover:shadow-md"
              )
            ]}
          >
            <%!-- Mini storefront preview mockup --%>
            <div class={"h-36 #{theme.preview_bg} relative p-3"}>
              <%!-- Mock nav --%>
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-1">
                  <div class={"w-4 h-4 rounded #{theme.preview_accent}"}></div>
                  <div class="w-12 h-2 bg-slate-300 rounded"></div>
                </div>
                <div class="flex gap-1">
                  <div class="w-3 h-3 rounded-full bg-slate-300"></div>
                  <div class="w-3 h-3 rounded-full bg-slate-300"></div>
                </div>
              </div>
              <%!-- Mock hero --%>
              <div class={"rounded-lg #{theme.preview_accent} h-12 mb-2 flex items-end p-2"}>
                <div class="w-16 h-1.5 bg-white/60 rounded"></div>
              </div>
              <%!-- Mock product grid --%>
              <div class="grid grid-cols-3 gap-1">
                <div class="bg-slate-200 rounded h-8"></div>
                <div class="bg-slate-200 rounded h-8"></div>
                <div class="bg-slate-200 rounded h-8"></div>
              </div>
            </div>

            <%!-- Theme info --%>
            <div class="p-4 bg-white">
              <div class="flex items-center gap-2 mb-1">
                <span
                  class="material-symbols-outlined text-lg"
                  style={"color: #{theme.colors.primary}"}
                >
                  {theme.icon}
                </span>
                <h3 class="text-base font-bold text-slate-900">{theme.name}</h3>
                <span
                  :if={theme.id == @theme_id}
                  class="ml-auto text-xs font-semibold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full"
                >
                  Active
                </span>
              </div>
              <p class="text-xs text-slate-500">{theme.description}</p>
              <%!-- Color dots --%>
              <div class="flex gap-1.5 mt-2">
                <div
                  class="w-5 h-5 rounded-full ring-1 ring-black/10"
                  style={"background: #{theme.colors.primary}"}
                >
                </div>
                <div
                  class="w-5 h-5 rounded-full ring-1 ring-black/10"
                  style={"background: #{theme.colors.accent}"}
                >
                </div>
                <div
                  class="w-5 h-5 rounded-full ring-1 ring-black/10"
                  style={"background: #{theme.colors.background}"}
                >
                </div>
              </div>
            </div>
          </button>
        </div>
      </div>

      <%!-- STEP 2: Pick Your Color — Tap to select from presets --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">2</span>
          </div>
          <h2 class="text-lg font-bold text-slate-800">Pick Your Color</h2>
        </div>

        <div class="bg-white rounded-2xl p-5 shadow-sm">
          <p class="text-sm text-slate-500 mb-4">Tap a color to change your store's look</p>
          <div class="flex flex-wrap gap-3">
            <button
              :for={preset <- @color_presets}
              phx-click="select_color"
              phx-value-hex={preset.hex}
              class={[
                "w-14 h-14 rounded-xl transition-all flex items-center justify-center",
                preset.class,
                if(preset.hex == @primary_color,
                  do: "ring-4 ring-offset-2 ring-emerald-500 scale-110",
                  else: "hover:scale-105 ring-1 ring-black/10"
                )
              ]}
            >
              <span
                :if={preset.hex == @primary_color}
                class="material-symbols-outlined text-white text-xl"
              >
                check
              </span>
            </button>
          </div>

          <%!-- Current color preview --%>
          <div class="flex items-center gap-3 mt-4 pt-4 border-t border-slate-100">
            <div
              class="w-10 h-10 rounded-xl ring-1 ring-black/10"
              style={"background: #{@primary_color}"}
            >
            </div>
            <div>
              <p class="text-xs text-slate-400">Your store color</p>
              <p class="text-sm font-mono font-semibold text-slate-700">{@primary_color}</p>
            </div>
          </div>
        </div>
      </div>

      <%!-- STEP 3: Show/Hide Sections — Visual toggles with icons --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">3</span>
          </div>
          <h2 class="text-lg font-bold text-slate-800">Show or Hide</h2>
        </div>

        <div class="bg-white rounded-2xl p-5 shadow-sm">
          <p class="text-sm text-slate-500 mb-4">Tap to turn sections on or off</p>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <.visual_toggle
              icon="image"
              label="Hero Banner"
              enabled={@sections.hero}
              field="hero"
            />
            <.visual_toggle
              icon="grid_view"
              label="Categories"
              enabled={@sections.categories}
              field="categories"
            />
            <.visual_toggle
              icon="star"
              label="Featured"
              enabled={@sections.featured_products}
              field="featured_products"
            />
            <.visual_toggle
              icon="auto_stories"
              label="Our Story"
              enabled={@sections.brand_story}
              field="brand_story"
            />
            <.visual_toggle
              icon="mail"
              label="Newsletter"
              enabled={@sections.newsletter}
              field="newsletter"
            />
          </div>
        </div>
      </div>

      <%!-- SAVE BUTTON — Big, obvious --%>
      <div class="sticky bottom-4 z-20">
        <button
          phx-click="save_theme"
          disabled={@saving}
          class={[
            "w-full py-4 rounded-2xl text-base font-bold shadow-lg transition-all active:scale-[0.98]",
            if(@saved,
              do: "bg-emerald-500 text-white",
              else: "bg-emerald-600 hover:bg-emerald-700 text-white"
            )
          ]}
        >
          <span :if={@saving} class="material-symbols-outlined animate-spin text-lg align-middle mr-2">
            progress_activity
          </span>
          {cond do
            @saving -> "Saving..."
            @saved -> "Saved!"
            true -> "Save Changes"
          end}
        </button>
      </div>

      <%!-- Store Preview Link --%>
      <div class="text-center pb-8">
        <a
          href={"/s/#{@store.slug}/"}
          target="_blank"
          class="inline-flex items-center gap-2 text-sm text-emerald-600 hover:text-emerald-700 font-medium"
        >
          <span class="material-symbols-outlined text-base">open_in_new</span> View your store
        </a>
      </div>
    </div>
    """
  end

  # ── Visual Toggle Component ──

  defp visual_toggle(assigns) do
    ~H"""
    <button
      phx-click="toggle_section"
      phx-value-section={@field}
      class={[
        "flex flex-col items-center gap-2 p-4 rounded-xl transition-all",
        if(@enabled,
          do: "bg-emerald-50 ring-2 ring-emerald-500",
          else: "bg-slate-50 ring-1 ring-slate-200 opacity-50"
        )
      ]}
    >
      <span class={[
        "material-symbols-outlined text-2xl",
        if(@enabled, do: "text-emerald-600", else: "text-slate-400")
      ]}>
        {@icon}
      </span>
      <span class={[
        "text-xs font-semibold",
        if(@enabled, do: "text-emerald-700", else: "text-slate-400")
      ]}>
        {@label}
      </span>
      <span class={[
        "text-[10px] font-bold uppercase tracking-wider",
        if(@enabled, do: "text-emerald-500", else: "text-slate-300")
      ]}>
        {if @enabled, do: "ON", else: "OFF"}
      </span>
    </button>
    """
  end

  # ── Events ──

  @impl true
  def handle_event("select_theme", %{"theme-id" => theme_id}, socket) do
    theme_mod = ThemeResolver.theme_module(theme_id)
    defaults = theme_mod.defaults()

    {:noreply,
     assign(socket,
       theme_id: theme_id,
       primary_color: defaults.colors.primary,
       saved: false
     )}
  end

  @impl true
  def handle_event("select_color", %{"hex" => hex}, socket) do
    {:noreply, assign(socket, primary_color: hex, saved: false)}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    sections = Map.update!(socket.assigns.sections, section_atom, &(!&1))
    {:noreply, assign(socket, sections: sections, saved: false)}
  end

  @impl true
  def handle_event("save_theme", _params, socket) do
    socket = assign(socket, saving: true)

    theme_config = %{
      "theme" => socket.assigns.theme_id,
      "colors" => %{
        "primary" => socket.assigns.primary_color
      },
      "sections" => %{
        "hero" => socket.assigns.sections.hero,
        "categories" => socket.assigns.sections.categories,
        "featured_products" => socket.assigns.sections.featured_products,
        "brand_story" => socket.assigns.sections.brand_story,
        "newsletter" => socket.assigns.sections.newsletter
      }
    }

    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case socket.assigns.store
         |> Ash.Changeset.for_update(:update_settings, %{theme_config: theme_config})
         |> Ash.update(actor: actor) do
      {:ok, updated_store} ->
        # Clear ETS cache so storefront picks up changes immediately
        try do
          Emakola.Cache.StoreCache.invalidate(updated_store.slug)
        rescue
          _ -> :ok
        end

        {:noreply,
         socket
         |> assign(store: updated_store, saving: false, saved: true)
         |> put_flash(:info, "Theme saved! View your store to see the changes.")}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(saving: false)
         |> put_flash(:error, "Could not save. Please try again.")}
    end
  end

  @impl true
  def handle_event("toggle_drawer", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_defaults", _params, socket) do
    {:noreply, socket}
  end
end
