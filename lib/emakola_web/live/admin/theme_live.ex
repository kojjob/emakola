defmodule EmakolaWeb.Admin.ThemeLive do
  @moduledoc """
  Theme customizer — visual, low-literacy friendly.
  Large theme preview cards, tap-to-select colors, visual toggles.
  Supports hero image uploads (up to 5) and carousel toggle.
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
    },
    %{
      id: "starter",
      name: "Starter",
      description: "Clean & modern",
      icon: "auto_awesome",
      colors: %{primary: "#6366F1", accent: "#1E293B", background: "#FFFFFF"},
      preview_bg: "bg-white",
      preview_accent: "bg-indigo-500"
    },
    %{
      id: "bold",
      name: "Bold",
      description: "Editorial & dramatic",
      icon: "newspaper",
      colors: %{primary: "#0F172A", accent: "#F59E0B", background: "#F8FAFC"},
      preview_bg: "bg-slate-50",
      preview_accent: "bg-slate-900"
    },
    %{
      id: "fresh",
      name: "Fresh",
      description: "Food & grocery",
      icon: "eco",
      colors: %{primary: "#059669", accent: "#92400E", background: "#FEFCE8"},
      preview_bg: "bg-yellow-50",
      preview_accent: "bg-emerald-600"
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

        hero_images = get_in(resolved, [:hero, :images]) || []
        hero_carousel = get_in(resolved, [:hero, :carousel]) || false

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
            accent_color: resolved.colors.accent,
            bg_color: resolved.colors.background,
            hero_image: get_in(resolved, [:hero, :image_url]) || "",
            hero_images: hero_images,
            hero_carousel: hero_carousel,
            hero_title: get_in(resolved, [:hero, :title]) || "",
            sections: %{
              hero: Map.get(resolved.sections, :hero, true),
              categories: Map.get(resolved.sections, :categories, true),
              featured_products: Map.get(resolved.sections, :featured_products, true),
              trust: Map.get(resolved.sections, :trust, true),
              brand_story: Map.get(resolved.sections, :brand_story, true),
              newsletter: Map.get(resolved.sections, :newsletter, true)
            },
            design_tokens: resolved.design_tokens,
            saving: false,
            saved: false
          )
          |> allow_upload(:hero_images,
            accept: ~w(.jpg .jpeg .png .webp),
            max_entries: 5,
            max_file_size: 5_000_000
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

      <%!-- STEP 2: Customize Colors --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">2</span>
          </div>
          <h2 class="text-lg font-bold text-slate-800">Customize Colors</h2>
        </div>

        <div class="bg-white rounded-2xl p-5 shadow-sm space-y-6">
          <%!-- Quick presets --%>
          <div>
            <p class="text-sm text-slate-500 mb-3">Quick presets</p>
            <div class="flex flex-wrap gap-3">
              <button
                :for={preset <- @color_presets}
                phx-click="select_color"
                phx-value-hex={preset.hex}
                class={[
                  "w-12 h-12 rounded-xl transition-all flex items-center justify-center",
                  preset.class,
                  if(preset.hex == @primary_color,
                    do: "ring-4 ring-offset-2 ring-emerald-500 scale-110",
                    else: "hover:scale-105 ring-1 ring-black/10"
                  )
                ]}
              >
                <span
                  :if={preset.hex == @primary_color}
                  class="material-symbols-outlined text-white text-lg"
                >
                  check
                </span>
              </button>
            </div>
          </div>

          <%!-- Custom color inputs --%>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Primary Color</label>
              <p class="text-xs text-slate-400 mb-2">Used for buttons, CTAs, and links</p>
              <div class="flex items-center gap-3">
                <input
                  type="color"
                  value={@primary_color}
                  name="value"
                  phx-change="update_color"
                  phx-value-field="primary"
                  class="w-10 h-10 rounded cursor-pointer border border-slate-200 p-0.5"
                />
                <input
                  type="text"
                  value={@primary_color}
                  name="value"
                  phx-change="update_color"
                  phx-debounce="500"
                  phx-value-field="primary"
                  placeholder="#2563EB"
                  class="flex-1 border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Accent Color</label>
              <p class="text-xs text-slate-400 mb-2">Used for highlights, badges, and text</p>
              <div class="flex items-center gap-3">
                <input
                  type="color"
                  value={@accent_color}
                  name="value"
                  phx-change="update_color"
                  phx-value-field="accent"
                  class="w-10 h-10 rounded cursor-pointer border border-slate-200 p-0.5"
                />
                <input
                  type="text"
                  value={@accent_color}
                  name="value"
                  phx-change="update_color"
                  phx-debounce="500"
                  phx-value-field="accent"
                  placeholder="#0F172A"
                  class="flex-1 border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Background Color</label>
              <p class="text-xs text-slate-400 mb-2">Page background color</p>
              <div class="flex items-center gap-3">
                <input
                  type="color"
                  value={@bg_color}
                  name="value"
                  phx-change="update_color"
                  phx-value-field="background"
                  class="w-10 h-10 rounded cursor-pointer border border-slate-200 p-0.5"
                />
                <input
                  type="text"
                  value={@bg_color}
                  name="value"
                  phx-change="update_color"
                  phx-debounce="500"
                  phx-value-field="background"
                  placeholder="#FFFFFF"
                  class="flex-1 border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </div>
            </div>
          </div>

          <%!-- Live preview swatch --%>
          <div
            class="rounded-xl p-4 border border-slate-200"
            style={"background-color: #{@bg_color};"}
          >
            <p class="text-xs text-slate-400 mb-2">Preview</p>
            <div class="flex items-center gap-3">
              <div
                class="w-8 h-8 rounded-full ring-1 ring-black/10"
                style={"background-color: #{@primary_color};"}
              >
              </div>
              <div
                class="w-8 h-8 rounded-full ring-1 ring-black/10"
                style={"background-color: #{@accent_color};"}
              >
              </div>
              <div class="flex-1">
                <span class="text-sm font-semibold" style={"color: #{@accent_color};"}>
                  Store Name
                </span>
              </div>
              <button
                type="button"
                class="px-3 py-1.5 rounded-lg text-xs font-semibold text-white"
                style={"background-color: #{@primary_color};"}
              >
                Shop Now
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- STEP 3: Hero Image + Title --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">3</span>
          </div>
          <h2 class="text-lg font-bold text-slate-800">Your Hero Banner</h2>
        </div>

        <div class="bg-white rounded-2xl p-5 shadow-sm space-y-4">
          <%!-- Hero preview --%>
          <div class="relative rounded-xl overflow-hidden h-40 bg-slate-200">
            <%= if first_hero_image(@hero_images, @hero_image) != "" do %>
              <img
                src={first_hero_image(@hero_images, @hero_image)}
                alt="Hero preview"
                class="w-full h-full object-cover"
              />
            <% else %>
              <div class="w-full h-full bg-gradient-to-br from-slate-700 to-slate-900 flex items-center justify-center">
                <span class="material-symbols-outlined text-4xl text-white/30">image</span>
              </div>
            <% end %>
            <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
            <div class="absolute bottom-3 left-4">
              <p class="text-white font-bold text-lg">
                {if @hero_title != "", do: @hero_title, else: "Your Store Title"}
              </p>
            </div>
            <%!-- Carousel badge --%>
            <div :if={@hero_carousel && length(@hero_images) > 1} class="absolute top-3 right-3">
              <span class="bg-black/50 text-white text-[10px] font-bold px-2 py-1 rounded-full uppercase tracking-wider">
                Carousel
              </span>
            </div>
          </div>

          <%!-- Uploaded hero images thumbnails --%>
          <div :if={@hero_images != []} id="hero-images-list" class="space-y-2">
            <label class="block text-xs font-medium text-slate-500">
              <span class="material-symbols-outlined text-sm align-middle mr-1">collections</span>
              Hero Images ({length(@hero_images)}/5)
            </label>
            <div class="flex flex-wrap gap-3">
              <div :for={{url, idx} <- Enum.with_index(@hero_images)} class="relative group">
                <img
                  src={url}
                  alt={"Hero image #{idx + 1}"}
                  class={"w-20 h-20 rounded-lg object-cover " <> if(idx == 0, do: "ring-2 ring-emerald-500", else: "ring-1 ring-slate-200")}
                />
                <%!-- Primary badge --%>
                <div
                  :if={idx == 0}
                  class="absolute -top-1 -left-1 w-4 h-4 bg-emerald-500 text-white rounded-full flex items-center justify-center"
                >
                  <span class="text-[8px] font-bold">1</span>
                </div>
                <%!-- Remove button --%>
                <button
                  type="button"
                  phx-click="remove_hero_image"
                  phx-value-index={idx}
                  class="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer"
                >
                  <span class="material-symbols-outlined text-xs">close</span>
                </button>
                <%!-- Move to front / swap buttons --%>
                <div
                  :if={idx > 0}
                  class="absolute bottom-0 left-0 right-0 bg-black/60 rounded-b-lg opacity-0 group-hover:opacity-100 transition-opacity flex justify-center py-0.5"
                >
                  <button
                    type="button"
                    phx-click="set_primary_hero_image"
                    phx-value-index={idx}
                    class="text-[9px] text-white font-medium cursor-pointer hover:text-emerald-300"
                  >
                    Set as main
                  </button>
                </div>
              </div>
            </div>
          </div>

          <%!-- File Upload --%>
          <div :if={length(@hero_images) < 5} id="hero-upload-section">
            <label class="block text-xs font-medium text-slate-500 mb-1.5">
              <span class="material-symbols-outlined text-sm align-middle mr-1">upload</span>
              Upload Hero Images
            </label>
            <form id="hero-upload-form" phx-change="validate_upload" phx-submit="save_hero_image">
              <div
                class="border-2 border-dashed border-slate-300 rounded-xl p-6 text-center hover:border-emerald-400 transition-colors cursor-pointer"
                phx-drop-target={@uploads.hero_images.ref}
              >
                <.live_file_input upload={@uploads.hero_images} class="sr-only" />
                <span class="material-symbols-outlined text-3xl text-slate-400">
                  add_photo_alternate
                </span>
                <p class="text-sm text-slate-500 mt-2">
                  Drag images here or
                  <label
                    for={@uploads.hero_images.ref}
                    class="text-emerald-600 font-medium cursor-pointer hover:underline"
                  >
                    browse
                  </label>
                </p>
                <p class="text-[11px] text-slate-400 mt-1">
                  JPG, PNG, WebP up to 5MB each (max 5 images)
                </p>
              </div>

              <%!-- Upload previews --%>
              <div :if={@uploads.hero_images.entries != []} class="mt-3 space-y-2">
                <div :for={entry <- @uploads.hero_images.entries} class="flex items-center gap-3">
                  <.live_img_preview entry={entry} class="w-12 h-12 rounded-lg object-cover" />
                  <div class="flex-1 min-w-0">
                    <p class="text-xs text-slate-600 truncate">{entry.client_name}</p>
                    <div class="w-full bg-slate-200 rounded-full h-1.5 mt-1">
                      <div
                        class="bg-emerald-500 h-1.5 rounded-full"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="text-slate-400 hover:text-red-500"
                  >
                    <span class="material-symbols-outlined text-sm">close</span>
                  </button>
                </div>
                <%!-- Upload errors --%>
                <p :for={err <- upload_errors(@uploads.hero_images)} class="text-xs text-red-500">
                  {upload_error_message(err)}
                </p>
              </div>

              <button
                :if={@uploads.hero_images.entries != []}
                type="submit"
                class="mt-3 px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors"
              >
                <span class="material-symbols-outlined text-sm align-middle mr-1">cloud_upload</span>
                Upload
              </button>
            </form>
          </div>

          <%!-- Carousel Toggle --%>
          <div
            :if={length(@hero_images) > 1}
            id="hero-carousel-toggle"
            class="flex items-center justify-between p-3 bg-slate-50 rounded-xl"
          >
            <div class="flex items-center gap-2">
              <span class="material-symbols-outlined text-lg text-slate-600">view_carousel</span>
              <div>
                <p class="text-sm font-medium text-slate-700">Carousel</p>
                <p class="text-[11px] text-slate-400">Auto-rotate hero images</p>
              </div>
            </div>
            <button
              type="button"
              phx-click="toggle_carousel"
              class={[
                "relative w-12 h-7 rounded-full transition-colors",
                if(@hero_carousel, do: "bg-emerald-500", else: "bg-slate-300")
              ]}
            >
              <span class={[
                "absolute top-0.5 w-6 h-6 bg-white rounded-full shadow transition-transform",
                if(@hero_carousel, do: "translate-x-5", else: "translate-x-0.5")
              ]}>
              </span>
            </button>
          </div>

          <%!-- Hero image URL fallback --%>
          <div>
            <label class="block text-xs font-medium text-slate-500 mb-1.5">
              <span class="material-symbols-outlined text-sm align-middle mr-1">link</span>
              Or paste an image URL
            </label>
            <input
              type="url"
              value={@hero_image}
              phx-change="update_hero_image"
              phx-debounce="500"
              name="hero_image"
              placeholder="https://images.unsplash.com/..."
              class="w-full bg-white border border-slate-300 rounded-xl px-4 py-3 text-sm text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
            <p class="text-[11px] text-slate-400 mt-1">
              Paste a link to your banner image (used when no uploaded images)
            </p>
          </div>

          <%!-- Hero title --%>
          <div>
            <label class="block text-xs font-medium text-slate-500 mb-1.5">
              <span class="material-symbols-outlined text-sm align-middle mr-1">title</span>
              Hero Title
            </label>
            <input
              type="text"
              value={@hero_title}
              phx-change="update_hero_title"
              phx-debounce="300"
              name="hero_title"
              placeholder="The New Essential"
              class="w-full bg-white border border-slate-300 rounded-xl px-4 py-3 text-sm text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
        </div>
      </div>

      <%!-- STEP 4: Show/Hide Sections — Visual toggles with icons --%>
      <div>
        <div class="flex items-center gap-2 mb-4">
          <div class="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center">
            <span class="text-sm font-bold text-emerald-700">4</span>
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
              icon="verified_user"
              label="Trust"
              enabled={@sections.trust}
              field="trust"
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

      <%!-- Design Style link --%>
      <div class="bg-white rounded-2xl p-5 shadow-sm">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-violet-100 flex items-center justify-center">
              <span class="material-symbols-outlined text-xl text-violet-600">palette</span>
            </div>
            <div>
              <p class="text-sm font-semibold text-slate-800">Design Style</p>
              <p class="text-xs text-slate-400">Customize buttons, cards, typography & layout</p>
            </div>
          </div>
          <a
            href="/admin/design"
            class="px-4 py-2 bg-slate-900 text-white text-sm font-medium rounded-xl hover:bg-slate-800 transition-colors"
          >
            Open Designer
          </a>
        </div>
      </div>

      <%!-- Design Tokens UI is at /admin/design --%>

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

  # ── Helpers ──

  defp first_hero_image(hero_images, fallback_url) do
    case hero_images do
      [first | _] -> first
      _ -> fallback_url || ""
    end
  end

  defp valid_hex_color?(value) when is_binary(value) do
    Regex.match?(~r/^#[0-9a-fA-F]{6}$/, value)
  end

  defp valid_hex_color?(_), do: false

  defp upload_error_message(:too_large), do: "File is too large (max 5MB)"
  defp upload_error_message(:not_accepted), do: "Invalid file type (use JPG, PNG, or WebP)"
  defp upload_error_message(:too_many_files), do: "Too many files (max 5)"
  defp upload_error_message(_), do: "Upload error"

  # ── Events ──

  @impl true
  def handle_event("select_theme", %{"theme-id" => theme_id}, socket) do
    theme_mod = ThemeResolver.theme_module(theme_id)
    defaults = theme_mod.defaults()

    {:noreply,
     assign(socket,
       theme_id: theme_id,
       primary_color: defaults.colors.primary,
       accent_color: defaults.colors.accent,
       bg_color: defaults.colors.background,
       saved: false
     )}
  end

  @impl true
  def handle_event("select_color", %{"hex" => hex}, socket) do
    {:noreply, assign(socket, primary_color: hex, saved: false)}
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => value}, socket) do
    if valid_hex_color?(value) do
      case field do
        "primary" -> {:noreply, assign(socket, primary_color: value, saved: false)}
        "accent" -> {:noreply, assign(socket, accent_color: value, saved: false)}
        "background" -> {:noreply, assign(socket, bg_color: value, saved: false)}
        _ -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    sections = Map.update!(socket.assigns.sections, section_atom, &(!&1))
    {:noreply, assign(socket, sections: sections, saved: false)}
  end

  @impl true
  def handle_event("update_hero_image", %{"hero_image" => url}, socket) do
    {:noreply, assign(socket, hero_image: url, saved: false)}
  end

  @impl true
  def handle_event("update_hero_title", %{"hero_title" => title}, socket) do
    {:noreply, assign(socket, hero_title: title, saved: false)}
  end

  @impl true
  def handle_event("toggle_carousel", _params, socket) do
    {:noreply, assign(socket, hero_carousel: !socket.assigns.hero_carousel, saved: false)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :hero_images, ref)}
  end

  @impl true
  def handle_event("save_hero_image", _params, socket) do
    store_id = socket.assigns.store.id

    uploaded_urls =
      consume_uploaded_entries(socket, :hero_images, fn %{path: path}, entry ->
        filename = "#{store_id}_#{System.os_time(:millisecond)}_#{entry.client_name}"
        # Sanitize filename
        filename = String.replace(filename, ~r/[^a-zA-Z0-9._-]/, "_")
        dest = Path.join(heroes_upload_dir(), filename)
        File.cp!(path, dest)
        {:ok, "/uploads/heroes/#{filename}"}
      end)

    existing = socket.assigns.hero_images
    # Cap at 5 total
    new_images = Enum.take(existing ++ uploaded_urls, 5)

    {:noreply, assign(socket, hero_images: new_images, saved: false)}
  end

  @impl true
  def handle_event("remove_hero_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    new_images = List.delete_at(socket.assigns.hero_images, index)

    # Turn off carousel if less than 2 images remain
    hero_carousel =
      if length(new_images) < 2, do: false, else: socket.assigns.hero_carousel

    {:noreply,
     assign(socket, hero_images: new_images, hero_carousel: hero_carousel, saved: false)}
  end

  @impl true
  def handle_event("set_primary_hero_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    images = socket.assigns.hero_images

    if index >= 0 && index < length(images) do
      # Move the selected image to the front
      image = Enum.at(images, index)
      new_images = [image | List.delete_at(images, index)]
      {:noreply, assign(socket, hero_images: new_images, saved: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_theme", _params, socket) do
    socket = assign(socket, saving: true)

    # Merge admin changes into existing config to preserve keys
    # not managed by this UI (trust, newsletter, nav, footer, etc.)
    existing = socket.assigns.store.theme_config || %{}

    existing_hero = Map.get(existing, "hero", %{})
    existing_sections = Map.get(existing, "sections", %{})

    theme_config =
      Map.merge(existing, %{
        "theme" => socket.assigns.theme_id,
        "colors" =>
          Map.merge(Map.get(existing, "colors", %{}), %{
            "primary" => socket.assigns.primary_color,
            "accent" => socket.assigns.accent_color,
            "background" => socket.assigns.bg_color
          }),
        "hero" =>
          Map.merge(existing_hero, %{
            "image_url" => socket.assigns.hero_image,
            "images" => socket.assigns.hero_images,
            "carousel" => socket.assigns.hero_carousel,
            "title" => socket.assigns.hero_title
          }),
        "sections" =>
          Map.merge(existing_sections, %{
            "hero" => socket.assigns.sections.hero,
            "categories" => socket.assigns.sections.categories,
            "featured_products" => socket.assigns.sections.featured_products,
            "trust" => socket.assigns.sections.trust,
            "brand_story" => socket.assigns.sections.brand_story,
            "newsletter" => socket.assigns.sections.newsletter
          }),
        "design_tokens" =>
          socket.assigns.design_tokens
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Map.new()
      })

    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case socket.assigns.store
         |> Ash.Changeset.for_update(:update_settings, %{theme_config: theme_config})
         |> Ash.update(actor: actor) do
      {:ok, updated_store} ->
        # Clear ETS cache so storefront picks up changes immediately
        try do
          Emakola.Cache.StoreCache.invalidate(updated_store.slug)
          Emakola.Cache.StoreCache.invalidate_store(updated_store.id)
        rescue
          _ -> :ok
        end

        # Broadcast so connected storefront LiveViews reload their store data
        Phoenix.PubSub.broadcast(
          Emakola.PubSub,
          "store:#{updated_store.id}:theme",
          {:theme_updated, updated_store}
        )

        # Reload all values from the saved config to ensure consistency
        saved_config = updated_store.theme_config || %{}
        saved_hero = Map.get(saved_config, "hero", %{})
        saved_colors = Map.get(saved_config, "colors", %{})

        {:noreply,
         socket
         |> assign(
           store: updated_store,
           primary_color: Map.get(saved_colors, "primary", "#2563EB"),
           accent_color: Map.get(saved_colors, "accent", "#0F172A"),
           bg_color: Map.get(saved_colors, "background", "#FFFFFF"),
           hero_images: Map.get(saved_hero, "images", []),
           hero_image: Map.get(saved_hero, "image_url", ""),
           hero_carousel: Map.get(saved_hero, "carousel", false),
           hero_title: Map.get(saved_hero, "title", ""),
           saving: false,
           saved: true
         )
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

  defp heroes_upload_dir do
    dir = Path.join([:code.priv_dir(:emakola), "static", "uploads", "heroes"])
    File.mkdir_p!(dir)
    dir
  end
end
