defmodule EmakolaWeb.Admin.DesignLive do
  @moduledoc """
  Design Studio — 3-column layout (components | live preview | typography)
  matching ThemeLive's visual structure. Merchants pick component styles,
  typography, and layout while seeing changes reflected in a live preview.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Themes.ThemeResolver

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Design", active_nav: :design)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        resolved = ThemeResolver.resolve(store.theme_config || %{})

        # Gates the "Homepage sections" hand-off card — the section editor
        # redirects away for themes without sections/0 support, so don't
        # render a link that goes nowhere.
        sections_editable? =
          resolved.theme_id
          |> ThemeResolver.theme_module()
          |> Emakola.Themes.Sections.sectionized?()

        {:ok,
         socket
         |> assign(
           page_title: "Design Studio",
           active_nav: :design,
           store: store,
           design_tokens: resolved.design_tokens,
           sections_editable?: sections_editable?,
           preview_key: System.unique_integer([:positive]),
           saving: false,
           saved: false
         )}
    end
  end

  @impl true
  def handle_event("update_token", %{"token" => token, "value" => value}, socket) do
    token_atom =
      Emakola.SafeAtom.to_atom_in(
        token,
        # navbar_layout, hero_layout and product_card_style were removed: they
        # were structural, no storefront read them, and two had no UI at all —
        # so they were writable only by a crafted event and visible to nobody.
        [
          :button_style,
          :card_style,
          :product_grid_columns,
          :footer_style,
          :typography_scale,
          :heading_font,
          :body_font
        ],
        :button_style
      )

    value =
      if token_atom == :product_grid_columns do
        case Integer.parse(value) do
          {int, _} -> int
          :error -> 3
        end
      else
        value
      end

    updated = Map.put(socket.assigns.design_tokens, token_atom, value)

    {:noreply, assign(socket, design_tokens: updated, saved: false)}
  end

  @impl true
  def handle_event("save_design", _params, socket) do
    socket = assign(socket, saving: true)
    existing = socket.assigns.store.theme_config || %{}

    theme_config =
      Map.put(
        existing,
        "design_tokens",
        socket.assigns.design_tokens
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Map.new()
      )

    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case Emakola.Stores.update_store_settings(
           socket.assigns.store,
           %{theme_config: theme_config},
           actor: actor
         ) do
      {:ok, updated_store} ->
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

        {:noreply,
         socket
         |> assign(
           store: updated_store,
           saving: false,
           saved: true,
           preview_key: System.unique_integer([:positive])
         )
         |> put_flash(:info, "Design saved")}

      {:error, _} ->
        {:noreply, socket |> assign(saving: false) |> put_flash(:error, "Failed to save")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6">
      <%!-- Header (matches Theme page) --%>
      <.admin_page_header
        icon="hero-paint-brush"
        title="Design Studio"
        subtitle="Customize buttons, cards, typography, and layout — preview live"
      >
        <a
          href={EmakolaWeb.Storefront.Path.public_path(@store.slug, "/")}
          target="_blank"
          class="inline-flex items-center gap-2 px-4 py-2.5 rounded-control border border-border bg-surface text-sm font-semibold text-text hover:bg-surface-subtle transition-colors"
        >
          <.icon name="hero-arrow-top-right-on-square" class="size-5" /> View live store
        </a>
      </.admin_page_header>

      <%!-- 3-COLUMN LAYOUT — components | preview | typography ──────── --%>
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-5 pb-32">
        <%!-- ═══ LEFT: COMPONENTS ═══ --%>
        <aside class="lg:col-span-3 space-y-4 lg:max-h-[calc(100vh-9rem)] lg:overflow-y-auto lg:sticky lg:top-4 lg:pr-1">
          <%!-- Buttons --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">smart_button</span>
              <h2 class="text-base font-bold text-slate-800">Buttons</h2>
            </div>
            <.reach_note token="button_style" />
            <div class="space-y-2">
              <.option_tile
                token="button_style"
                value="rounded"
                selected={@design_tokens.button_style}
                label="Rounded"
              >
                <div class="h-6 flex items-center justify-center">
                  <div class="bg-slate-800 text-white text-[8px] font-bold px-3 py-1 rounded-md">
                    Button
                  </div>
                </div>
              </.option_tile>
              <.option_tile
                token="button_style"
                value="square"
                selected={@design_tokens.button_style}
                label="Square"
              >
                <div class="h-6 flex items-center justify-center">
                  <div class="bg-slate-800 text-white text-[8px] font-bold px-3 py-1 rounded-none">
                    Button
                  </div>
                </div>
              </.option_tile>
              <.option_tile
                token="button_style"
                value="pill"
                selected={@design_tokens.button_style}
                label="Pill"
              >
                <div class="h-6 flex items-center justify-center">
                  <div class="bg-slate-800 text-white text-[8px] font-bold px-3 py-1 rounded-full">
                    Button
                  </div>
                </div>
              </.option_tile>
            </div>
          </div>

          <%!-- Cards --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">crop_portrait</span>
              <h2 class="text-base font-bold text-slate-800">Cards</h2>
            </div>
            <.reach_note token="card_style" />
            <div class="space-y-2">
              <.option_tile
                token="card_style"
                value="minimal"
                selected={@design_tokens.card_style}
                label="Clean"
              >
                <div class="h-6 bg-white p-0.5">
                  <div class="h-3 bg-slate-100 rounded-sm mb-0.5"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-2/3"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="card_style"
                value="shadow"
                selected={@design_tokens.card_style}
                label="Shadow"
              >
                <div class="h-6 bg-white shadow rounded-md p-0.5">
                  <div class="h-3 bg-slate-100 rounded-sm mb-0.5"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-2/3"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="card_style"
                value="bordered"
                selected={@design_tokens.card_style}
                label="Border"
              >
                <div class="h-6 bg-white border border-slate-200 rounded-md p-0.5">
                  <div class="h-3 bg-slate-100 rounded-sm mb-0.5"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-2/3"></div>
                </div>
              </.option_tile>
            </div>
          </div>

          <%!-- Product Grid --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">grid_view</span>
              <h2 class="text-base font-bold text-slate-800">Product Grid</h2>
            </div>
            <.reach_note token="product_grid_columns" />
            <div class="space-y-2">
              <.option_tile
                token="product_grid_columns"
                value="2"
                selected={to_string(@design_tokens.product_grid_columns)}
                label="2 col"
              >
                <div class="grid grid-cols-2 gap-0.5 h-6">
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="product_grid_columns"
                value="3"
                selected={to_string(@design_tokens.product_grid_columns)}
                label="3 col"
              >
                <div class="grid grid-cols-3 gap-0.5 h-6">
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="product_grid_columns"
                value="4"
                selected={to_string(@design_tokens.product_grid_columns)}
                label="4 col"
              >
                <div class="grid grid-cols-4 gap-0.5 h-6">
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                  <div class="bg-slate-200 rounded-sm"></div>
                </div>
              </.option_tile>
            </div>
          </div>
        </aside>

        <%!-- ═══ CENTER: LIVE PREVIEW ═══ --%>
        <section class="lg:col-span-6">
          <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
            <%!-- Preview header --%>
            <div class="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-xl text-emerald-600">visibility</span>
                <h2 class="text-base font-bold text-slate-800">Live Preview</h2>
              </div>
              <div class="flex items-center gap-1.5">
                <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                <span class="text-[11px] text-slate-500 font-medium">Live</span>
              </div>
            </div>

            <%!-- Storefront mock --%>
            <div class="bg-slate-50 p-4 sm:p-6">
              <div class="bg-white rounded-xl shadow-md border border-slate-200 overflow-hidden">
                <%!-- Mock browser chrome --%>
                <div class="px-3 py-2 border-b border-slate-100 flex items-center gap-1.5 bg-slate-50">
                  <span class="w-2.5 h-2.5 rounded-full bg-rose-300"></span>
                  <span class="w-2.5 h-2.5 rounded-full bg-amber-300"></span>
                  <span class="w-2.5 h-2.5 rounded-full bg-emerald-300"></span>
                  <div class="ml-2 flex-1 h-5 bg-white rounded text-[10px] text-slate-400 px-2 flex items-center">
                    {@store.slug}.emakola.shop
                  </div>
                </div>

                <%!-- Preview Navbar --%>
                <div class="flex items-center h-12 px-4 border-b border-slate-200 gap-3 justify-start">
                  <div class="w-6 h-6 rounded-full bg-slate-200"></div>
                  <span class="text-sm font-semibold text-slate-800">{@store.name}</span>
                  <div class="flex-1"></div>
                  <div class="w-5 h-5 rounded-full bg-slate-100"></div>
                  <div class="w-5 h-5 rounded-full bg-slate-100"></div>
                </div>

                <%!-- Preview Hero --%>
                <div class="relative bg-gradient-to-br from-stone-800 to-stone-900 p-8 sm:p-12">
                  <h2
                    class={
                        "font-bold text-white mb-2 " <>
                          Emakola.Themes.DesignTokens.heading_size(@design_tokens.typography_scale)
                      }
                    style={
                        "font-family: #{Emakola.Themes.DesignTokens.heading_font_family(@design_tokens.heading_font)}"
                      }
                  >
                    Welcome to our store
                  </h2>
                  <p
                    class={
                        "text-stone-300 mb-4 " <>
                          Emakola.Themes.DesignTokens.body_size(@design_tokens.typography_scale)
                      }
                    style={
                        "font-family: #{Emakola.Themes.DesignTokens.body_font_family(@design_tokens.body_font)}"
                      }
                  >
                    Discover our curated collection of premium products.
                  </p>
                  <button class={
                      "bg-white text-stone-900 text-sm font-semibold px-6 py-2.5 " <>
                        Emakola.Themes.DesignTokens.button_classes(@design_tokens.button_style)
                    }>
                    Shop Now
                  </button>
                </div>

                <%!-- Preview Product Grid --%>
                <div class="p-6">
                  <h3
                    class={
                      "font-bold text-slate-900 mb-4 " <>
                        Emakola.Themes.DesignTokens.heading_size(@design_tokens.typography_scale)
                    }
                    style={
                      "font-family: #{Emakola.Themes.DesignTokens.heading_font_family(@design_tokens.heading_font)}"
                    }
                  >
                    Featured Products
                  </h3>
                  <div class={
                    "grid gap-4 " <>
                      Emakola.Themes.DesignTokens.grid_classes(@design_tokens.product_grid_columns)
                  }>
                    <div
                      :for={i <- 1..(@design_tokens.product_grid_columns * 2)}
                      class={
                        Emakola.Themes.DesignTokens.card_classes(@design_tokens.card_style) <>
                          " overflow-hidden"
                      }
                    >
                      <div class={
                        "w-full bg-gradient-to-br #{card_gradient(i)} " <>
                          if(@design_tokens.product_grid_columns == 4,
                            do: "h-20",
                            else: "h-28"
                          )
                      }>
                      </div>
                      <div class="p-3">
                        <div
                          class="h-3 bg-slate-200 rounded w-3/4 mb-1.5"
                          style={
                            "font-family: #{Emakola.Themes.DesignTokens.body_font_family(@design_tokens.body_font)}"
                          }
                        >
                        </div>
                        <div class="h-2 bg-slate-100 rounded w-1/2 mb-3"></div>
                        <button class={
                          "w-full bg-slate-900 text-white text-[10px] font-semibold py-1.5 " <>
                            Emakola.Themes.DesignTokens.button_classes(@design_tokens.button_style)
                        }>
                          Add to Cart
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <%!-- Preview Footer --%>
                <%= case Emakola.Themes.DesignTokens.footer_style(@design_tokens.footer_style) do %>
                  <% :minimal -> %>
                    <div class="bg-slate-900 px-6 py-4 text-center">
                      <p class="text-xs text-slate-500">&copy; 2026 {@store.name}</p>
                    </div>
                  <% :columns -> %>
                    <div class="bg-slate-900 px-6 py-6">
                      <div class="grid grid-cols-3 gap-4 mb-4">
                        <div :for={_ <- 1..3}>
                          <div class="h-2 bg-slate-600 rounded w-1/2 mb-2"></div>
                          <div class="space-y-1">
                            <div class="h-1.5 bg-slate-700 rounded w-3/4"></div>
                            <div class="h-1.5 bg-slate-700 rounded w-2/3"></div>
                          </div>
                        </div>
                      </div>
                      <p class="text-xs text-slate-500 text-center">&copy; 2026 {@store.name}</p>
                    </div>
                  <% :mega -> %>
                    <div class="bg-slate-900 px-6 py-8">
                      <div class="text-sm font-semibold text-white mb-4">{@store.name}</div>
                      <div class="grid grid-cols-4 gap-4 mb-6">
                        <div :for={_ <- 1..4}>
                          <div class="h-1.5 bg-slate-600 rounded w-1/2 mb-2"></div>
                          <div class="space-y-1">
                            <div class="h-1 bg-slate-700 rounded w-3/4"></div>
                            <div class="h-1 bg-slate-700 rounded w-2/3"></div>
                            <div class="h-1 bg-slate-700 rounded w-1/2"></div>
                          </div>
                        </div>
                      </div>
                      <div class="border-t border-slate-800 pt-4">
                        <p class="text-xs text-slate-500 text-center">
                          &copy; 2026 {@store.name}
                        </p>
                      </div>
                    </div>
                <% end %>
              </div>
            </div>
          </div>
        </section>

        <%!-- ═══ RIGHT: TYPOGRAPHY & LAYOUT ═══ --%>
        <aside class="lg:col-span-3 space-y-4 lg:max-h-[calc(100vh-9rem)] lg:overflow-y-auto lg:sticky lg:top-4 lg:pr-1">
          <%!-- Typography --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">title</span>
              <h2 class="text-base font-bold text-slate-800">Typography</h2>
            </div>

            <p class="text-[11px] text-slate-500 mb-2 uppercase tracking-wider font-medium">
              Heading
            </p>
            <div class="space-y-2 mb-4">
              <.option_row
                token="heading_font"
                value="sans"
                selected={@design_tokens.heading_font}
                label="Sans"
              >
                <span class="text-sm font-bold text-slate-800">Modern</span>
              </.option_row>
              <.option_row
                token="heading_font"
                value="serif"
                selected={@design_tokens.heading_font}
                label="Serif"
              >
                <span
                  class="text-sm font-bold text-slate-800"
                  style="font-family: 'Cormorant', Georgia, serif"
                >
                  Elegant
                </span>
              </.option_row>
              <.option_row
                token="heading_font"
                value="display"
                selected={@design_tokens.heading_font}
                label="Display"
              >
                <span
                  class="text-sm font-bold text-slate-800"
                  style="font-family: 'Playfair Display', Georgia, serif"
                >
                  Bold
                </span>
              </.option_row>
            </div>

            <p class="text-[11px] text-slate-500 mb-2 uppercase tracking-wider font-medium">
              Body
            </p>
            <div class="space-y-2">
              <.option_row
                token="body_font"
                value="sans"
                selected={@design_tokens.body_font}
                label="Sans"
              >
                <span class="text-sm text-slate-700">Clean & readable</span>
              </.option_row>
              <.option_row
                token="body_font"
                value="serif"
                selected={@design_tokens.body_font}
                label="Serif"
              >
                <span class="text-sm text-slate-700" style="font-family: 'Lora', Georgia, serif">
                  Editorial feel
                </span>
              </.option_row>
            </div>
          </div>

          <%!-- Spacing --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">density_medium</span>
              <h2 class="text-base font-bold text-slate-800">Spacing</h2>
            </div>
            <div class="space-y-2">
              <.option_tile
                token="typography_scale"
                value="compact"
                selected={@design_tokens.typography_scale}
                label="Tight"
              >
                <div class="space-y-px h-6 flex flex-col justify-center">
                  <div class="h-1 bg-slate-300 rounded w-3/4"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-full"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-5/6"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="typography_scale"
                value="default"
                selected={@design_tokens.typography_scale}
                label="Default"
              >
                <div class="space-y-0.5 h-6 flex flex-col justify-center">
                  <div class="h-1.5 bg-slate-300 rounded w-3/4"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-full"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-5/6"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="typography_scale"
                value="spacious"
                selected={@design_tokens.typography_scale}
                label="Relaxed"
              >
                <div class="space-y-1 h-6 flex flex-col justify-center">
                  <div class="h-2 bg-slate-300 rounded w-3/4"></div>
                  <div class="h-0.5 bg-slate-200 rounded w-full"></div>
                </div>
              </.option_tile>
            </div>
          </div>

          <%!-- Footer --%>
          <div class="bg-white rounded-2xl p-4 shadow-sm">
            <div class="flex items-center gap-2 mb-3">
              <span class="material-symbols-outlined text-xl text-emerald-600">space_dashboard</span>
              <h2 class="text-base font-bold text-slate-800">Footer Style</h2>
            </div>
            <.reach_note token="footer_style" />
            <div class="space-y-2">
              <.option_tile
                token="footer_style"
                value="minimal"
                selected={@design_tokens.footer_style}
                label="Minimal"
              >
                <div class="h-4 bg-slate-700 rounded-sm flex items-center justify-center">
                  <div class="h-0.5 bg-slate-400 rounded w-1/2"></div>
                </div>
              </.option_tile>
              <.option_tile
                token="footer_style"
                value="columns"
                selected={@design_tokens.footer_style}
                label="Columns"
              >
                <div class="h-4 bg-slate-700 rounded-sm p-0.5">
                  <div class="grid grid-cols-3 gap-0.5 h-full">
                    <div class="bg-slate-600 rounded-sm"></div>
                    <div class="bg-slate-600 rounded-sm"></div>
                    <div class="bg-slate-600 rounded-sm"></div>
                  </div>
                </div>
              </.option_tile>
              <.option_tile
                token="footer_style"
                value="mega"
                selected={@design_tokens.footer_style}
                label="Mega"
              >
                <div class="h-4 bg-slate-700 rounded-sm p-0.5">
                  <div class="grid grid-cols-4 gap-px">
                    <div class="h-1 bg-slate-600 rounded-sm"></div>
                    <div class="h-1 bg-slate-600 rounded-sm"></div>
                    <div class="h-1 bg-slate-600 rounded-sm"></div>
                    <div class="h-1 bg-slate-600 rounded-sm"></div>
                  </div>
                </div>
              </.option_tile>
            </div>
          </div>

          <%!-- Hand-off CTA → Section editor (sectionized themes only) --%>
          <.link
            :if={@sections_editable?}
            navigate="/admin/design/sections"
            class="block bg-gradient-to-br from-sky-50 to-sky-100 hover:from-sky-100 hover:to-sky-200 rounded-2xl p-4 transition-colors group"
          >
            <div class="flex items-start gap-3">
              <div class="w-9 h-9 rounded-xl bg-sky-200 group-hover:bg-sky-300 flex items-center justify-center shrink-0 transition-colors">
                <span class="material-symbols-outlined text-lg text-sky-700">view_agenda</span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-sky-900">Homepage sections</p>
                <p class="text-[11px] text-sky-700 mt-0.5 leading-relaxed">
                  Reorder, show, hide, and configure the sections on your home page
                </p>
              </div>
              <span class="material-symbols-outlined text-base text-sky-600 group-hover:translate-x-0.5 transition-transform shrink-0">
                arrow_forward
              </span>
            </div>
          </.link>

          <%!-- Hand-off CTA → back to Theme picker --%>
          <.link
            navigate="/admin/theme"
            class="block bg-gradient-to-br from-emerald-50 to-emerald-100 hover:from-emerald-100 hover:to-emerald-200 rounded-2xl p-4 transition-colors group"
          >
            <div class="flex items-start gap-3">
              <span class="material-symbols-outlined text-base text-emerald-600 group-hover:-translate-x-0.5 transition-transform shrink-0 mt-0.5">
                arrow_back
              </span>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-emerald-900">Pick a different theme</p>
                <p class="text-[11px] text-emerald-700 mt-0.5 leading-relaxed">
                  Change colors, hero style, and section toggles in the Theme picker
                </p>
              </div>
              <div class="w-9 h-9 rounded-xl bg-emerald-200 group-hover:bg-emerald-300 flex items-center justify-center shrink-0 transition-colors">
                <span class="material-symbols-outlined text-lg text-emerald-700">style</span>
              </div>
            </div>
          </.link>
        </aside>
      </div>

      <%!-- STICKY SAVE BAR — bottom of viewport (matches Theme page) --%>
      <div class="fixed bottom-0 inset-x-0 z-30 bg-white border-t border-slate-200 shadow-lg">
        <div class="max-w-[1600px] mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-3">
          <div class="hidden sm:flex items-center gap-2 text-xs text-slate-500">
            <span class="material-symbols-outlined text-base">info</span>
            <span>Changes apply to your live storefront when you save</span>
          </div>
          <button
            phx-click="save_design"
            disabled={@saving}
            class={[
              "ml-auto px-8 py-3 rounded-xl text-sm font-bold shadow-md transition-all active:scale-[0.98]",
              if(@saved,
                do: "bg-emerald-500 text-white",
                else: "bg-emerald-600 hover:bg-emerald-700 text-white"
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

  # ── Components ──

  attr :token, :string, required: true

  # Says out loud when a control does not reach the merchant's storefront.
  #
  # This studio renders its preview through `DesignTokens` while the storefront
  # renders independently, so a control could move the preview and change
  # nothing on the live shop — and several did. Rather than let the preview keep
  # implying otherwise, each affected group carries its own caveat, sourced from
  # `DesignTokens.reach/1` so there is one place to update as tokens get wired.
  #
  # A comment rather than @doc: this is a defp, where @doc is discarded and
  # warns — and CI compiles with --warnings-as-errors.
  defp reach_note(assigns) do
    assigns = assign(assigns, :note, Emakola.Themes.DesignTokens.reach_note(assigns.token))

    ~H"""
    <p
      :if={@note}
      class="mb-3 flex items-start gap-1.5 rounded-lg bg-amber-50 px-2.5 py-2 text-[11px] font-medium leading-snug text-amber-800"
    >
      <span class="material-symbols-outlined text-sm leading-none">info</span>
      {@note}
    </p>
    """
  end

  attr :token, :string, required: true
  attr :value, :string, required: true
  attr :selected, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp option_tile(assigns) do
    is_selected = to_string(assigns.selected) == to_string(assigns.value)
    assigns = assign(assigns, :is_selected, is_selected)

    ~H"""
    <button
      type="button"
      phx-click={Phoenix.LiveView.JS.push("update_token", value: %{token: @token, value: @value})}
      class={[
        "cursor-pointer p-2.5 rounded-xl border-2 transition-all w-full",
        if(@is_selected,
          do: "border-emerald-500 bg-emerald-50 shadow-md shadow-emerald-500/10 scale-[1.02]",
          else: "border-slate-200 bg-white hover:border-slate-300 hover:shadow-sm"
        )
      ]}
    >
      <div class="mb-2">
        {render_slot(@inner_block)}
      </div>
      <div class="flex items-center justify-center gap-1.5">
        <div class={[
          "w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0",
          if(@is_selected, do: "border-emerald-500 bg-emerald-500", else: "border-slate-300")
        ]}>
          <svg
            :if={@is_selected}
            class="w-2.5 h-2.5 text-white"
            fill="none"
            stroke="currentColor"
            stroke-width="3"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
        </div>
        <p class={[
          "text-xs font-semibold",
          if(@is_selected, do: "text-emerald-700", else: "text-slate-500")
        ]}>
          {@label}
        </p>
      </div>
    </button>
    """
  end

  attr :token, :string, required: true
  attr :value, :string, required: true
  attr :selected, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp option_row(assigns) do
    is_selected = to_string(assigns.selected) == to_string(assigns.value)
    assigns = assign(assigns, :is_selected, is_selected)

    ~H"""
    <button
      type="button"
      phx-click={Phoenix.LiveView.JS.push("update_token", value: %{token: @token, value: @value})}
      class={[
        "cursor-pointer flex items-center gap-3 w-full p-3 rounded-xl border-2 transition-all text-left",
        if(@is_selected,
          do: "border-emerald-500 bg-emerald-50 shadow-sm",
          else: "border-slate-200 bg-white hover:border-slate-300"
        )
      ]}
    >
      <div class={[
        "w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0",
        if(@is_selected, do: "border-emerald-500 bg-emerald-500", else: "border-slate-300")
      ]}>
        <svg
          :if={@is_selected}
          class="w-2.5 h-2.5 text-white"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        {render_slot(@inner_block)}
      </div>
      <span class={[
        "text-[10px] font-medium shrink-0",
        if(@is_selected, do: "text-emerald-700", else: "text-slate-400")
      ]}>
        {@label}
      </span>
    </button>
    """
  end

  defp card_gradient(1), do: "from-amber-100 to-orange-200"
  defp card_gradient(2), do: "from-sky-100 to-blue-200"
  defp card_gradient(3), do: "from-emerald-100 to-green-200"
  defp card_gradient(4), do: "from-rose-100 to-pink-200"
  defp card_gradient(5), do: "from-violet-100 to-purple-200"
  defp card_gradient(6), do: "from-amber-100 to-yellow-200"
  defp card_gradient(7), do: "from-cyan-100 to-teal-200"
  defp card_gradient(_), do: "from-slate-100 to-slate-200"
end
