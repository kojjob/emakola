defmodule EmakolaWeb.Admin.ThemeLive do
  @moduledoc """
  Theme customizer — visual, low-literacy friendly.
  Large theme preview cards, tap-to-select colors, visual toggles.
  Supports hero image uploads (up to 5) and carousel toggle.
  """

  use EmakolaWeb, :live_view

  alias Emakola.Themes.ThemeResolver

  # Visual metadata for each theme. Colors are derived at runtime from each
  # theme module's defaults() so the picker stays in sync with what
  # `select_theme` actually applies — no hardcoded color duplication.
  @theme_metadata [
    %{
      id: "akoma",
      name: "Akoma",
      description: "Clean & modern (Be Yours)",
      icon: "deployed_code"
    },
    %{id: "market", name: "Market", description: "Simple & clean", icon: "storefront"},
    %{id: "atelier", name: "Atelier", description: "Premium & elegant", icon: "diamond"},
    %{id: "vibrant", name: "Vibrant", description: "Bold & colorful", icon: "palette"},
    %{id: "starter", name: "Starter", description: "Clean & modern", icon: "auto_awesome"},
    %{id: "bold", name: "Bold", description: "Editorial & dramatic", icon: "newspaper"},
    %{id: "fresh", name: "Fresh", description: "Food & grocery", icon: "eco"},
    %{
      id: "pharmacy",
      name: "Pharmacy",
      description: "Wellness & medicines",
      icon: "medical_services"
    },
    %{
      id: "beauty",
      name: "Beauty",
      description: "Skincare & cosmetics",
      icon: "spa"
    },
    %{
      id: "home_living",
      name: "Home Living",
      description: "Furniture & home goods",
      icon: "chair"
    },
    %{
      id: "electronics",
      name: "Electronics",
      description: "Phones, audio & gadgets",
      icon: "devices"
    },
    %{
      id: "fashion",
      name: "Fashion",
      description: "Editorial boutique",
      icon: "checkroom"
    },
    %{
      id: "heritage",
      name: "Heritage",
      description: "Artisan crafts & heirloom",
      icon: "auto_stories"
    },
    %{id: "spotlight", name: "Spotlight", description: "Single-product showcase", icon: "star"}
  ]

  @color_presets [
    %{name: "Gold", hex: "#CA8A04", class: "bg-yellow-600"},
    %{name: "Blue", hex: "#2563EB", class: "bg-blue-600"},
    %{name: "Red", hex: "#DC2626", class: "bg-red-600"},
    %{name: "Green", hex: "#059669", class: "bg-primary"},
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
        resolved = ThemeResolver.resolve(store.theme_config || %{}, store)

        hero_images = get_in(resolved, [:hero, :images]) || []
        hero_carousel = get_in(resolved, [:hero, :carousel]) || false

        socket =
          socket
          |> assign(
            page_title: "Theme",
            active_nav: :theme,
            store: store,
            themes: build_themes(),
            color_presets: @color_presets,
            preview_categories: load_preview_categories(store.id),
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
              testimonials: Map.get(resolved.sections, :testimonials, true),
              faq: Map.get(resolved.sections, :faq, false),
              featured_in: Map.get(resolved.sections, :featured_in, false),
              closing_cta: Map.get(resolved.sections, :closing_cta, true),
              newsletter: Map.get(resolved.sections, :newsletter, true)
            },
            trust_config: resolved.trust,
            newsletter_config: resolved.newsletter,
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
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3 mb-6 pt-2">
        <div>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Choose Your Look</h1>
          <p class="text-sm text-slate-500 mt-1">Pick a theme, customize colors, and preview live</p>
        </div>
        <a
          href={"/s/#{@store.slug}/"}
          target="_blank"
          class="inline-flex items-center gap-2 text-sm text-primary hover:text-primary-hover font-medium self-start sm:self-auto"
        >
          <span class="material-symbols-outlined text-base">open_in_new</span> View live store
        </a>
      </div>

      <%!-- 3-COLUMN LAYOUT — themes | preview | customize --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-5 pb-32">
        <%!-- ═══ LEFT: THEMES ═══ --%>
        <aside class="lg:col-span-3 lg:max-h-[calc(100vh-9rem)] lg:overflow-y-auto lg:sticky lg:top-4 lg:pr-1">
          <.admin_card padding={:none} class="p-4">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-primary">style</span>
              <h2 class="text-base font-bold text-slate-800">Themes</h2>
            </div>
            <div class="space-y-3">
              <button
                :for={theme <- @themes}
                phx-click="select_theme"
                phx-value-theme-id={theme.id}
                class={[
                  "group relative rounded-control overflow-hidden transition-all text-left w-full block",
                  if(theme.id == @theme_id,
                    do: "ring-2 ring-emerald-500 shadow-md",
                    else: "ring-1 ring-slate-200 hover:ring-slate-300 hover:shadow-sm"
                  )
                ]}
              >
                <%!-- Mini storefront mock — colors driven by theme defaults --%>
                <div class="h-20 relative p-2" style={"background-color: #{theme.colors.background};"}>
                  <div class="flex items-center justify-between mb-1.5">
                    <div class="w-3 h-3 rounded" style={"background-color: #{theme.colors.primary};"}>
                    </div>
                    <div class="flex gap-1">
                      <div class="w-2 h-2 rounded-full bg-slate-300"></div>
                      <div class="w-2 h-2 rounded-full bg-slate-300"></div>
                    </div>
                  </div>
                  <div class="rounded h-6 mb-1.5" style={"background-color: #{theme.colors.primary};"}>
                  </div>
                  <div class="grid grid-cols-3 gap-1">
                    <div class="rounded h-4" style={"background-color: #{theme.colors.accent}22;"}>
                    </div>
                    <div class="rounded h-4" style={"background-color: #{theme.colors.accent}22;"}>
                    </div>
                    <div class="rounded h-4" style={"background-color: #{theme.colors.accent}22;"}>
                    </div>
                  </div>
                </div>
                <%!-- Info row --%>
                <div class="px-3 py-2.5 bg-white flex items-center gap-2">
                  <span
                    class="material-symbols-outlined text-base"
                    style={"color: #{theme.colors.primary}"}
                  >
                    {theme.icon}
                  </span>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-semibold text-slate-900 truncate">{theme.name}</p>
                    <p class="text-[11px] text-slate-500 truncate">{theme.description}</p>
                  </div>
                  <span
                    :if={theme.id == @theme_id}
                    class="material-symbols-outlined text-emerald-500 text-base shrink-0"
                  >
                    check_circle
                  </span>
                </div>
              </button>
            </div>
          </.admin_card>

          <%!-- Design Style CTA --%>
          <.admin_card padding={:none} class="mt-4 p-4">
            <div class="flex items-start gap-3">
              <div class="w-9 h-9 rounded-control bg-violet-100 flex items-center justify-center shrink-0">
                <span class="material-symbols-outlined text-lg text-violet-600">palette</span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-slate-800">Design Style</p>
                <p class="text-[11px] text-slate-400 mb-2">
                  Buttons, cards, typography & layout
                </p>
                <a
                  href="/admin/design"
                  class="inline-block px-3 py-1.5 bg-slate-900 text-white text-xs font-medium rounded-lg hover:bg-slate-800 transition-colors"
                >
                  Open Designer
                </a>
              </div>
            </div>
          </.admin_card>
        </aside>

        <%!-- ═══ CENTER: LIVE PREVIEW ═══ --%>
        <section class="lg:col-span-6">
          <div class="lg:sticky lg:top-4 space-y-4">
            <%!-- Preview header --%>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-primary">preview</span>
                <h2 class="text-base font-bold text-slate-800">Live Preview</h2>
              </div>
              <span class="inline-flex items-center gap-1 text-[11px] font-medium text-primary bg-primary-soft px-2 py-1 rounded-full">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                Updates as you edit
              </span>
            </div>

            <%!-- Storefront mock — uses live values --%>
            <div
              class="rounded-card overflow-hidden shadow-sm ring-1 ring-slate-200"
              style={"background-color: #{@bg_color};"}
            >
              <%!-- Mock browser chrome --%>
              <div class="flex items-center gap-1.5 px-3 py-2 bg-slate-100 border-b border-slate-200">
                <div class="w-2.5 h-2.5 rounded-full bg-red-400"></div>
                <div class="w-2.5 h-2.5 rounded-full bg-yellow-400"></div>
                <div class="w-2.5 h-2.5 rounded-full bg-green-400"></div>
                <div class="ml-3 text-[10px] text-slate-500 font-mono truncate">
                  /s/{@store.slug}
                </div>
              </div>

              <%!-- Mock nav --%>
              <div
                class="flex items-center justify-between px-5 py-3 border-b border-black/5"
                style={"background-color: #{@bg_color};"}
              >
                <span class="text-base font-bold tracking-tight" style={"color: #{@accent_color};"}>
                  {@store.name}
                </span>
                <div class="flex items-center gap-3 text-xs" style={"color: #{@accent_color};"}>
                  <span class="hidden sm:inline">Shop</span>
                  <span class="hidden sm:inline">About</span>
                  <span class="material-symbols-outlined text-base">shopping_bag</span>
                </div>
              </div>

              <%!-- Mock hero --%>
              <div :if={@sections.hero} class="relative h-56 sm:h-64 overflow-hidden">
                <%= if first_hero_image(@hero_images, @hero_image) != "" do %>
                  <img
                    src={first_hero_image(@hero_images, @hero_image)}
                    alt="Hero"
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <div class="w-full h-full bg-gradient-to-br from-slate-700 to-slate-900 flex items-center justify-center">
                    <span class="material-symbols-outlined text-5xl text-white/30">image</span>
                  </div>
                <% end %>
                <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/30 to-transparent">
                </div>
                <div class="absolute inset-0 flex flex-col items-start justify-end p-5 sm:p-8">
                  <h3 class="text-white text-2xl sm:text-3xl font-bold mb-3 max-w-md">
                    {if @hero_title != "", do: @hero_title, else: "Your Store Title"}
                  </h3>
                  <button
                    type="button"
                    class="px-5 py-2.5 rounded-lg text-sm font-semibold text-white shadow-lg transition-transform hover:scale-105"
                    style={"background-color: #{@primary_color};"}
                  >
                    Shop Now
                  </button>
                </div>
                <div :if={@hero_carousel && length(@hero_images) > 1} class="absolute top-3 right-3">
                  <span class="bg-black/50 text-white text-[10px] font-bold px-2 py-1 rounded-full uppercase tracking-wider">
                    Carousel
                  </span>
                </div>
              </div>

              <%!-- Mock categories — uses real categories from the store --%>
              <div :if={@sections.categories} class="px-5 py-5 border-b border-black/5">
                <p
                  class="text-xs font-semibold uppercase tracking-wider mb-3"
                  style={"color: #{@accent_color};"}
                >
                  Shop by category
                </p>
                <div :if={@preview_categories != []} class="flex flex-wrap gap-2">
                  <span
                    :for={category <- @preview_categories}
                    class="px-3 py-1.5 rounded-full text-xs font-medium ring-1 shrink-0"
                    style={"color: #{@accent_color}; background-color: #{@bg_color}; border-color: #{@accent_color}33;"}
                  >
                    {category.name}
                  </span>
                </div>
                <p
                  :if={@preview_categories == []}
                  class="text-xs italic"
                  style={"color: #{@accent_color}99;"}
                >
                  Add categories to see them here
                </p>
              </div>

              <%!-- Mock featured products --%>
              <div :if={@sections.featured_products} class="px-5 py-5 border-b border-black/5">
                <div class="flex items-center justify-between mb-3">
                  <p class="text-sm font-semibold" style={"color: #{@accent_color};"}>
                    Featured Products
                  </p>
                  <a
                    href={"/s/#{@store.slug}/products"}
                    target="_blank"
                    rel="noopener"
                    class="text-xs font-medium hover:underline"
                    style={"color: #{@primary_color};"}
                    title="Open products page on your storefront"
                  >
                    See all →
                  </a>
                </div>
                <div class="grid grid-cols-3 gap-3">
                  <div :for={_ <- 1..3} class="space-y-2">
                    <div class="aspect-square rounded-lg bg-black/5"></div>
                    <div class="h-2 rounded bg-black/10 w-3/4"></div>
                    <div class="h-2.5 rounded w-1/2" style={"background-color: #{@primary_color};"}>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Mock trust badges — driven by theme trust config --%>
              <div :if={@sections.trust} class="px-5 py-4 border-b border-black/5">
                <p
                  :if={trust_title(@trust_config) != ""}
                  class="text-xs font-semibold uppercase tracking-wider mb-3 text-center"
                  style={"color: #{@accent_color};"}
                >
                  {trust_title(@trust_config)}
                </p>
                <div class="grid grid-cols-3 gap-2 text-center">
                  <div :for={badge <- preview_trust_badges()} class="space-y-1">
                    <span
                      class="material-symbols-outlined text-base"
                      style={"color: #{@primary_color};"}
                    >
                      {badge.icon}
                    </span>
                    <p class="text-[10px] font-semibold" style={"color: #{@accent_color};"}>
                      {badge.label}
                    </p>
                    <p class="text-[9px]" style={"color: #{@accent_color}99;"}>
                      {badge.subtitle}
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Mock brand story — uses store description --%>
              <div :if={@sections.brand_story} class="px-5 py-5 border-b border-black/5">
                <p
                  class="text-xs font-semibold uppercase tracking-wider mb-2"
                  style={"color: #{@accent_color};"}
                >
                  Our Story
                </p>
                <p
                  :if={story_text(@store) != ""}
                  class="text-xs leading-relaxed line-clamp-3"
                  style={"color: #{@accent_color}cc;"}
                >
                  {story_text(@store)}
                </p>
                <div :if={story_text(@store) == ""} class="space-y-1.5">
                  <div class="h-2 rounded bg-black/10 w-full"></div>
                  <div class="h-2 rounded bg-black/10 w-5/6"></div>
                  <div class="h-2 rounded bg-black/10 w-2/3"></div>
                </div>
                <p
                  :if={story_text(@store) == ""}
                  class="mt-2 text-[10px] italic"
                  style={"color: #{@accent_color}80;"}
                >
                  Add a store description to populate this section
                </p>
              </div>

              <%!-- Mock newsletter — uses theme newsletter config --%>
              <div
                :if={@sections.newsletter}
                class="px-5 py-5 text-center"
                style={"background-color: #{@accent_color};"}
              >
                <p class="text-xs font-semibold mb-2 text-white/90">
                  {newsletter_title(@newsletter_config)}
                </p>
                <div class="flex items-center gap-2 max-w-xs mx-auto">
                  <div class="flex-1 h-8 rounded-lg bg-white/10 ring-1 ring-white/20"></div>
                  <button
                    type="button"
                    class="px-3 py-1.5 rounded-lg text-xs font-semibold text-white"
                    style={"background-color: #{@primary_color};"}
                  >
                    {newsletter_button(@newsletter_config)}
                  </button>
                </div>
              </div>
            </div>

            <p class="text-[11px] text-slate-400 text-center">
              This is a simplified preview. Open your store to see the full version.
            </p>
          </div>
        </section>

        <%!-- ═══ RIGHT: CUSTOMIZE ═══ --%>
        <aside class="lg:col-span-3 space-y-4">
          <%!-- Colors --%>
          <.admin_card padding={:none} class="p-4">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-primary">palette</span>
              <h2 class="text-base font-bold text-slate-800">Colors</h2>
            </div>

            <%!-- Quick presets --%>
            <p class="text-[11px] text-slate-500 mb-2 uppercase tracking-wider font-medium">
              Quick presets
            </p>
            <div class="flex flex-wrap gap-2 mb-4">
              <button
                :for={preset <- @color_presets}
                phx-click="select_color"
                phx-value-hex={preset.hex}
                title={preset.name}
                class={[
                  "w-9 h-9 rounded-lg transition-all flex items-center justify-center",
                  preset.class,
                  if(preset.hex == @primary_color,
                    do: "ring-2 ring-offset-1 ring-emerald-500 scale-110",
                    else: "hover:scale-105 ring-1 ring-black/10"
                  )
                ]}
              >
                <span
                  :if={preset.hex == @primary_color}
                  class="material-symbols-outlined text-white text-sm"
                >
                  check
                </span>
              </button>
            </div>

            <%!-- Custom color inputs --%>
            <div class="space-y-3">
              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">
                  Primary <span class="text-slate-400 font-normal">(buttons, links)</span>
                </label>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    value={@primary_color}
                    name="value"
                    phx-change="update_color"
                    phx-value-field="primary"
                    class="w-9 h-9 rounded cursor-pointer border border-slate-200 p-0.5 shrink-0"
                  />
                  <input
                    type="text"
                    value={@primary_color}
                    name="value"
                    phx-change="update_color"
                    phx-debounce="500"
                    phx-value-field="primary"
                    class="flex-1 min-w-0 border border-slate-300 rounded-lg px-2.5 py-1.5 text-xs font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">
                  Accent <span class="text-slate-400 font-normal">(text, badges)</span>
                </label>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    value={@accent_color}
                    name="value"
                    phx-change="update_color"
                    phx-value-field="accent"
                    class="w-9 h-9 rounded cursor-pointer border border-slate-200 p-0.5 shrink-0"
                  />
                  <input
                    type="text"
                    value={@accent_color}
                    name="value"
                    phx-change="update_color"
                    phx-debounce="500"
                    phx-value-field="accent"
                    class="flex-1 min-w-0 border border-slate-300 rounded-lg px-2.5 py-1.5 text-xs font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label class="block text-xs font-medium text-slate-700 mb-1">
                  Background <span class="text-slate-400 font-normal">(page)</span>
                </label>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    value={@bg_color}
                    name="value"
                    phx-change="update_color"
                    phx-value-field="background"
                    class="w-9 h-9 rounded cursor-pointer border border-slate-200 p-0.5 shrink-0"
                  />
                  <input
                    type="text"
                    value={@bg_color}
                    name="value"
                    phx-change="update_color"
                    phx-debounce="500"
                    phx-value-field="background"
                    class="flex-1 min-w-0 border border-slate-300 rounded-lg px-2.5 py-1.5 text-xs font-mono focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  />
                </div>
              </div>
            </div>
          </.admin_card>

          <%!-- Hero --%>
          <.admin_card padding={:none} class="p-4">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-primary">image</span>
              <h2 class="text-base font-bold text-slate-800">Hero Banner</h2>
            </div>

            <%!-- Hero title --%>
            <div class="mb-3">
              <label class="block text-xs font-medium text-slate-700 mb-1">Title</label>
              <input
                type="text"
                value={@hero_title}
                phx-change="update_hero_title"
                phx-debounce="300"
                name="hero_title"
                placeholder="The New Essential"
                class="w-full bg-white border border-slate-300 rounded-lg px-2.5 py-1.5 text-xs text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <%!-- Uploaded thumbnails --%>
            <div :if={@hero_images != []} id="hero-images-list" class="mb-3">
              <p class="text-xs font-medium text-slate-600 mb-2">
                Images ({length(@hero_images)}/5)
              </p>
              <div class="flex flex-wrap gap-2">
                <div :for={{url, idx} <- Enum.with_index(@hero_images)} class="relative group">
                  <img
                    src={url}
                    alt={"Hero #{idx + 1}"}
                    class={"w-14 h-14 rounded-lg object-cover " <> if(idx == 0, do: "ring-2 ring-emerald-500", else: "ring-1 ring-slate-200")}
                  />
                  <div
                    :if={idx == 0}
                    class="absolute -top-1 -left-1 w-3.5 h-3.5 bg-emerald-500 text-white rounded-full flex items-center justify-center text-[8px] font-bold"
                  >
                    1
                  </div>
                  <button
                    type="button"
                    phx-click="remove_hero_image"
                    phx-value-index={idx}
                    class="absolute -top-1.5 -right-1.5 w-4 h-4 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer"
                  >
                    <span class="material-symbols-outlined text-[10px]">close</span>
                  </button>
                  <button
                    :if={idx > 0}
                    type="button"
                    phx-click="set_primary_hero_image"
                    phx-value-index={idx}
                    class="absolute bottom-0 inset-x-0 bg-black/60 rounded-b-lg opacity-0 group-hover:opacity-100 transition-opacity text-[8px] text-white font-medium py-0.5 cursor-pointer hover:text-emerald-300"
                  >
                    Set main
                  </button>
                </div>
              </div>
            </div>

            <%!-- File upload --%>
            <div :if={length(@hero_images) < 5} id="hero-upload-section" class="mb-3">
              <form id="hero-upload-form" phx-change="validate_upload" phx-submit="save_hero_image">
                <div
                  class="border-2 border-dashed border-slate-300 rounded-lg p-3 text-center hover:border-emerald-400 transition-colors cursor-pointer"
                  phx-drop-target={@uploads.hero_images.ref}
                >
                  <.live_file_input upload={@uploads.hero_images} class="sr-only" />
                  <span class="material-symbols-outlined text-xl text-slate-400">
                    add_photo_alternate
                  </span>
                  <p class="text-[11px] text-slate-500 mt-1">
                    <label
                      for={@uploads.hero_images.ref}
                      class="text-primary font-medium cursor-pointer hover:underline"
                    >
                      Browse
                    </label>
                    or drag (max 5)
                  </p>
                </div>

                <div :if={@uploads.hero_images.entries != []} class="mt-2 space-y-1.5">
                  <div :for={entry <- @uploads.hero_images.entries} class="flex items-center gap-2">
                    <.live_img_preview entry={entry} class="w-8 h-8 rounded object-cover shrink-0" />
                    <div class="flex-1 min-w-0">
                      <p class="text-[10px] text-slate-600 truncate">{entry.client_name}</p>
                      <div class="w-full bg-slate-200 rounded-full h-1 mt-0.5">
                        <div
                          class="bg-emerald-500 h-1 rounded-full"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-slate-400 hover:text-red-500 cursor-pointer"
                    >
                      <span class="material-symbols-outlined text-xs">close</span>
                    </button>
                  </div>
                  <p
                    :for={err <- upload_errors(@uploads.hero_images)}
                    class="text-[10px] text-red-500"
                  >
                    {upload_error_message(err)}
                  </p>
                </div>

                <.admin_button
                  :if={@uploads.hero_images.entries != []}
                  type="submit"
                  size={:sm}
                  class="mt-2 w-full"
                >
                  Upload
                </.admin_button>
              </form>
            </div>

            <%!-- URL fallback --%>
            <div class="mb-3">
              <label class="block text-xs font-medium text-slate-700 mb-1">
                Or paste image URL
              </label>
              <input
                type="url"
                value={@hero_image}
                phx-change="update_hero_image"
                phx-debounce="500"
                name="hero_image"
                placeholder="https://..."
                class="w-full bg-white border border-slate-300 rounded-lg px-2.5 py-1.5 text-xs text-slate-800 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
              />
            </div>

            <%!-- Carousel toggle --%>
            <div
              :if={length(@hero_images) > 1}
              id="hero-carousel-toggle"
              class="flex items-center justify-between p-2.5 bg-slate-50 rounded-lg"
            >
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-base text-slate-600">view_carousel</span>
                <p class="text-xs font-medium text-slate-700">Carousel</p>
              </div>
              <button
                type="button"
                phx-click="toggle_carousel"
                class={[
                  "relative w-10 h-5.5 rounded-full transition-colors",
                  if(@hero_carousel, do: "bg-emerald-500", else: "bg-slate-300")
                ]}
                style="height: 1.375rem;"
              >
                <span class={[
                  "absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform",
                  if(@hero_carousel, do: "translate-x-5", else: "translate-x-0.5")
                ]}>
                </span>
              </button>
            </div>
          </.admin_card>

          <%!-- Sections — comprehensive panel grouped into Essentials,
               Social Proof, and Engagement so merchants can scan quickly. --%>
          <.admin_card padding={:none} class="p-4">
            <div class="flex items-center justify-between gap-2 mb-1">
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-xl text-primary">view_module</span>
                <h2 class="text-base font-bold text-slate-800">Sections</h2>
              </div>
              <span class="text-[10px] font-bold text-primary uppercase tracking-wider">
                {Enum.count(@sections, fn {_k, v} -> v end)}/{map_size(@sections)} on
              </span>
            </div>
            <p class="text-[11px] text-slate-500 mb-4">
              Tap to show or hide on your storefront homepage
            </p>

            <%!-- Essentials --%>
            <p class="text-[10px] font-bold uppercase tracking-[0.18em] text-slate-400 mb-2">
              Essentials
            </p>
            <div class="grid grid-cols-2 gap-2 mb-4">
              <.visual_toggle icon="image" label="Hero" enabled={@sections.hero} field="hero" />
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
                label="Story"
                enabled={@sections.brand_story}
                field="brand_story"
              />
            </div>

            <%!-- Social proof --%>
            <p class="text-[10px] font-bold uppercase tracking-[0.18em] text-slate-400 mb-2">
              Social Proof
            </p>
            <div class="grid grid-cols-2 gap-2 mb-4">
              <.visual_toggle
                icon="verified_user"
                label="Trust"
                enabled={@sections.trust}
                field="trust"
              />
              <.visual_toggle
                icon="format_quote"
                label="Reviews"
                enabled={@sections.testimonials}
                field="testimonials"
              />
              <.visual_toggle
                icon="newspaper"
                label="As Seen In"
                enabled={@sections.featured_in}
                field="featured_in"
              />
              <.visual_toggle
                icon="quiz"
                label="FAQ"
                enabled={@sections.faq}
                field="faq"
              />
            </div>

            <%!-- Engagement --%>
            <p class="text-[10px] font-bold uppercase tracking-[0.18em] text-slate-400 mb-2">
              Engagement
            </p>
            <div class="grid grid-cols-2 gap-2">
              <.visual_toggle
                icon="campaign"
                label="Closing CTA"
                enabled={@sections.closing_cta}
                field="closing_cta"
              />
              <.visual_toggle
                icon="mail"
                label="Newsletter"
                enabled={@sections.newsletter}
                field="newsletter"
              />
            </div>
          </.admin_card>

          <%!-- Hand-off CTA → Design Studio --%>
          <.link
            navigate="/admin/design"
            class="block bg-gradient-to-br from-violet-50 to-violet-100 hover:from-violet-100 hover:to-violet-200 rounded-card p-4 transition-colors group"
          >
            <div class="flex items-start gap-3">
              <div class="w-9 h-9 rounded-control bg-violet-200 group-hover:bg-violet-300 flex items-center justify-center shrink-0 transition-colors">
                <span class="material-symbols-outlined text-lg text-violet-700">tune</span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-violet-900">Fine-tune the details</p>
                <p class="text-[11px] text-violet-700 mt-0.5 leading-relaxed">
                  Buttons, cards, typography &amp; layout in the Design Studio
                </p>
              </div>
              <span class="material-symbols-outlined text-base text-violet-600 group-hover:translate-x-0.5 transition-transform shrink-0">
                arrow_forward
              </span>
            </div>
          </.link>
        </aside>
      </div>

      <%!-- STICKY SAVE BAR — bottom of viewport --%>
      <div class="fixed bottom-0 inset-x-0 z-30 bg-white border-t border-slate-200 shadow-lg">
        <div class="max-w-[1600px] mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <div class="hidden sm:flex items-center gap-2 text-xs text-slate-500">
            <span class="material-symbols-outlined text-base">info</span>
            <span>Changes apply to your live storefront when you save</span>
          </div>
          <button
            phx-click="save_theme"
            disabled={@saving}
            class={[
              "ml-auto px-8 py-3 rounded-control text-sm font-bold shadow-md transition-all active:scale-[0.98]",
              if(@saved,
                do: "bg-emerald-500 text-white",
                else: "bg-primary hover:bg-primary-hover text-white"
              )
            ]}
          >
            <span
              :if={@saving}
              class="material-symbols-outlined animate-spin text-base align-middle mr-1.5"
            >
              progress_activity
            </span>
            {cond do
              @saving -> "Saving..."
              @saved -> "Saved!"
              true -> "Save Changes"
            end}
          </button>
        </div>
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
        "flex flex-col items-center gap-2 p-4 rounded-control transition-all",
        if(@enabled,
          do: "bg-primary-soft ring-2 ring-emerald-500",
          else: "bg-slate-50 ring-1 ring-slate-200 opacity-50"
        )
      ]}
    >
      <span class={[
        "material-symbols-outlined text-2xl",
        if(@enabled, do: "text-primary", else: "text-slate-400")
      ]}>
        {@icon}
      </span>
      <span class={[
        "text-xs font-semibold",
        if(@enabled, do: "text-primary-hover", else: "text-slate-400")
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

  defp load_preview_categories(store_id) do
    Emakola.Catalog.list_root_categories!(store_id)
    |> Enum.take(4)
  rescue
    _ -> []
  end

  # Builds the theme picker list by combining static metadata (name, icon,
  # description) with each theme module's actual defaults — so the picker
  # cards display the same colors that `select_theme` will apply.
  defp build_themes do
    Enum.map(@theme_metadata, fn meta ->
      defaults = ThemeResolver.theme_module(meta.id).defaults()

      Map.merge(meta, %{
        colors: %{
          primary: defaults.colors.primary,
          accent: defaults.colors.accent,
          background: Map.get(defaults.colors, :background, "#FFFFFF")
        }
      })
    end)
  end

  defp first_hero_image(hero_images, fallback_url) do
    case hero_images do
      [first | _] -> first
      _ -> fallback_url || ""
    end
  end

  defp trust_title(config) when is_map(config), do: Map.get(config, :title, "") || ""
  defp trust_title(_), do: ""

  defp newsletter_title(config) when is_map(config) do
    Map.get(config, :title) || Map.get(config, :heading) || "Stay Updated."
  end

  defp newsletter_title(_), do: "Stay Updated."

  defp newsletter_button(config) when is_map(config) do
    Map.get(config, :button_text) || "Subscribe"
  end

  defp newsletter_button(_), do: "Subscribe"

  defp story_text(store) when is_map(store) do
    case Map.get(store, :description) do
      desc when is_binary(desc) -> String.trim(desc)
      _ -> ""
    end
  end

  defp story_text(_), do: ""

  # Visual trust badges shown in the preview. The icons/labels mirror what
  # the storefront's trust section renders so the preview reflects reality.
  defp preview_trust_badges do
    [
      %{icon: "lock", label: "Safe", subtitle: "Secure checkout"},
      %{icon: "bolt", label: "Fast", subtitle: "Instant confirmation"},
      %{icon: "smartphone", label: "Easy", subtitle: "Pay with your phone"}
    ]
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
    section_atom =
      Emakola.SafeAtom.to_atom_in(
        section,
        [
          :hero,
          :categories,
          :featured_products,
          :trust,
          :brand_story,
          :testimonials,
          :faq,
          :featured_in,
          :closing_cta,
          :newsletter
        ],
        :hero
      )

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
            "testimonials" => socket.assigns.sections.testimonials,
            "faq" => socket.assigns.sections.faq,
            "featured_in" => socket.assigns.sections.featured_in,
            "closing_cta" => socket.assigns.sections.closing_cta,
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

        # Re-resolve through the same pipeline used in mount so reload
        # values come from the theme's defaults (not arbitrary hex literals)
        # whenever a key is missing from the saved config.
        resolved = ThemeResolver.resolve(updated_store.theme_config || %{}, updated_store)
        saved_hero = get_in(resolved, [:hero]) || %{}

        {:noreply,
         socket
         |> assign(
           store: updated_store,
           theme_id: resolved.theme_id,
           primary_color: resolved.colors.primary,
           accent_color: resolved.colors.accent,
           bg_color: resolved.colors.background,
           hero_images: Map.get(saved_hero, :images, []),
           hero_image: Map.get(saved_hero, :image_url, ""),
           hero_carousel: Map.get(saved_hero, :carousel, false),
           hero_title: Map.get(saved_hero, :title, ""),
           trust_config: resolved.trust,
           newsletter_config: resolved.newsletter,
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
