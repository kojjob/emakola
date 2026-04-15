defmodule EmakolaWeb.Admin.DesignLive do
  @moduledoc """
  Design Studio — sidebar panel with live store preview.
  Merchants customize component styles, typography, and layout
  while seeing changes reflected in a live iframe preview.
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

        {:ok,
         socket
         |> assign(
           page_title: "Design Studio",
           active_nav: :design,
           store: store,
           design_tokens: resolved.design_tokens,
           preview_key: System.unique_integer([:positive]),
           saving: false,
           saved: false
         )}
    end
  end

  @impl true
  def handle_event("update_token", %{"token" => token, "value" => value}, socket) do
    token_atom = String.to_existing_atom(token)

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

    case socket.assigns.store
         |> Ash.Changeset.for_update(:update_settings, %{theme_config: theme_config})
         |> Ash.update(actor: actor) do
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
    <div class="space-y-6">
      <%!-- Header --%>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-xl font-bold text-slate-900">Design Studio</h1>
          <p class="text-sm text-slate-500 mt-0.5">Customize your store's visual style</p>
        </div>
        <button
          phx-click="save_design"
          disabled={@saving || @saved}
          class={[
            "px-6 py-2.5 rounded-xl text-sm font-semibold transition-all",
            cond do
              @saved -> "bg-emerald-100 text-emerald-700"
              @saving -> "bg-slate-200 text-slate-400"
              true -> "bg-emerald-600 text-white hover:bg-emerald-700"
            end
          ]}
        >
          {cond do
            @saved -> "Saved"
            @saving -> "Saving..."
            true -> "Save Changes"
          end}
        </button>
      </div>

      <%!-- Options Panel (horizontal scrolling cards) --%>
      <div class="bg-white rounded-2xl border border-slate-200 shadow-sm p-5">
        <div class="flex gap-6 overflow-x-auto pb-2 -mb-2">
          <%!-- BUTTONS --%>
          <div class="shrink-0 w-48">
            <.panel_section title="Buttons">
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
            </.panel_section>
          </div>

          <%!-- CARDS --%>
          <div class="shrink-0 w-48">
            <.panel_section title="Cards">
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
            </.panel_section>
          </div>

          <%!-- GRID --%>
          <div class="shrink-0 w-48">
            <.panel_section title="Grid">
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
            </.panel_section>
          </div>

          <%!-- HEADING FONT --%>
          <div class="shrink-0 w-52">
            <.panel_section title="Heading">
              <div class="space-y-2">
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
            </.panel_section>
          </div>

          <%!-- SPACING --%>
          <div class="shrink-0 w-48">
            <.panel_section title="Spacing">
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
            </.panel_section>
          </div>

          <%!-- HERO + FOOTER --%>
          <div class="shrink-0 w-48">
            <.panel_section title="Hero">
              <div class="space-y-2">
                <.option_tile
                  token="hero_layout"
                  value="full-bleed"
                  selected={@design_tokens.hero_layout}
                  label="Full"
                >
                  <div class="h-6 bg-slate-300 rounded-sm relative">
                    <div class="absolute bottom-0.5 left-1">
                      <div class="h-0.5 bg-white/70 rounded w-4"></div>
                    </div>
                  </div>
                </.option_tile>
                <.option_tile
                  token="hero_layout"
                  value="split"
                  selected={@design_tokens.hero_layout}
                  label="Split"
                >
                  <div class="h-6 flex gap-0.5">
                    <div class="flex-1 bg-slate-100 rounded-sm"></div>
                    <div class="flex-1 bg-slate-300 rounded-sm"></div>
                  </div>
                </.option_tile>
              </div>
            </.panel_section>
            <div class="mt-4">
              <.panel_section title="Footer">
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
              </.panel_section>
            </div>
          </div>
        </div>
      </div>

      <%!-- Live Preview --%>
      <div>
        <div class="max-w-3xl mx-auto bg-white rounded-2xl shadow-lg border border-slate-200 overflow-hidden">
          <%!-- Preview Navbar --%>
          <div class={"flex items-center h-12 px-4 border-b border-slate-200 gap-3 " <> Emakola.Themes.DesignTokens.navbar_classes(@design_tokens.navbar_layout)}>
            <div class="w-6 h-6 rounded-full bg-slate-200"></div>
            <span class="text-sm font-semibold text-slate-800">{@store.name}</span>
            <div class="flex-1"></div>
            <div class="w-5 h-5 rounded-full bg-slate-100"></div>
            <div class="w-5 h-5 rounded-full bg-slate-100"></div>
          </div>

          <%!-- Preview Hero --%>
          <%= if @design_tokens.hero_layout == "split" do %>
            <div class="flex">
              <div class="flex-1 p-8">
                <h2
                  class={"font-bold text-slate-900 mb-2 " <> Emakola.Themes.DesignTokens.heading_size(@design_tokens.typography_scale)}
                  style={"font-family: #{Emakola.Themes.DesignTokens.heading_font_family(@design_tokens.heading_font)}"}
                >
                  Welcome to our store
                </h2>
                <p
                  class={"text-slate-500 mb-4 " <> Emakola.Themes.DesignTokens.body_size(@design_tokens.typography_scale)}
                  style={"font-family: #{Emakola.Themes.DesignTokens.body_font_family(@design_tokens.body_font)}"}
                >
                  Discover our curated collection of premium products.
                </p>
                <button class={"bg-slate-900 text-white text-sm font-semibold px-6 py-2.5 " <> Emakola.Themes.DesignTokens.button_classes(@design_tokens.button_style)}>
                  Shop Now
                </button>
              </div>
              <div class="flex-1 bg-gradient-to-br from-amber-100 to-orange-200"></div>
            </div>
          <% else %>
            <div class="relative bg-gradient-to-br from-stone-800 to-stone-900 p-8 sm:p-12">
              <h2
                class={"font-bold text-white mb-2 " <> Emakola.Themes.DesignTokens.heading_size(@design_tokens.typography_scale)}
                style={"font-family: #{Emakola.Themes.DesignTokens.heading_font_family(@design_tokens.heading_font)}"}
              >
                Welcome to our store
              </h2>
              <p
                class={"text-stone-300 mb-4 " <> Emakola.Themes.DesignTokens.body_size(@design_tokens.typography_scale)}
                style={"font-family: #{Emakola.Themes.DesignTokens.body_font_family(@design_tokens.body_font)}"}
              >
                Discover our curated collection of premium products.
              </p>
              <button class={"bg-white text-stone-900 text-sm font-semibold px-6 py-2.5 " <> Emakola.Themes.DesignTokens.button_classes(@design_tokens.button_style)}>
                Shop Now
              </button>
            </div>
          <% end %>

          <%!-- Preview Product Grid --%>
          <div class="p-6">
            <h3
              class={"font-bold text-slate-900 mb-4 " <> Emakola.Themes.DesignTokens.heading_size(@design_tokens.typography_scale)}
              style={"font-family: #{Emakola.Themes.DesignTokens.heading_font_family(@design_tokens.heading_font)}"}
            >
              Featured Products
            </h3>
            <div class={"grid gap-4 " <> Emakola.Themes.DesignTokens.grid_classes(@design_tokens.product_grid_columns)}>
              <div
                :for={i <- 1..(@design_tokens.product_grid_columns * 2)}
                class={Emakola.Themes.DesignTokens.card_classes(@design_tokens.card_style) <> " overflow-hidden"}
              >
                <div class={"w-full bg-gradient-to-br #{card_gradient(i)} " <> if(@design_tokens.product_grid_columns == 4, do: "h-20", else: "h-28")}>
                </div>
                <div class="p-3">
                  <div
                    class="h-3 bg-slate-200 rounded w-3/4 mb-1.5"
                    style={"font-family: #{Emakola.Themes.DesignTokens.body_font_family(@design_tokens.body_font)}"}
                  >
                  </div>
                  <div class="h-2 bg-slate-100 rounded w-1/2 mb-3"></div>
                  <button class={"w-full bg-slate-900 text-white text-[10px] font-semibold py-1.5 " <> Emakola.Themes.DesignTokens.button_classes(@design_tokens.button_style)}>
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
                  <div>
                    <div class="h-2 bg-slate-600 rounded w-1/2 mb-2"></div>
                    <div class="space-y-1">
                      <div class="h-1.5 bg-slate-700 rounded w-3/4"></div>
                      <div class="h-1.5 bg-slate-700 rounded w-2/3"></div>
                    </div>
                  </div>
                  <div>
                    <div class="h-2 bg-slate-600 rounded w-1/2 mb-2"></div>
                    <div class="space-y-1">
                      <div class="h-1.5 bg-slate-700 rounded w-3/4"></div>
                      <div class="h-1.5 bg-slate-700 rounded w-2/3"></div>
                    </div>
                  </div>
                  <div>
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
                  <p class="text-xs text-slate-500 text-center">&copy; 2026 {@store.name}</p>
                </div>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  slot :inner_block, required: true
  attr :title, :string, required: true

  defp panel_section(assigns) do
    ~H"""
    <div>
      <p class="text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">
        {@title}
      </p>
      {render_slot(@inner_block)}
    </div>
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
