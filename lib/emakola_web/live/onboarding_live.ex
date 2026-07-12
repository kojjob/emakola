defmodule EmakolaWeb.OnboardingLive do
  @moduledoc """
  Onboarding flow for new Makola merchants.

  3-step flow:
  1. Name Your Store — store name, currency, auto-generated slug
  2. Add Your First Product — optional, skippable
  3. You're Ready! — summary + go to dashboard
  """

  use EmakolaWeb, :live_view

  require Logger

  @theme_save_flash "Your store is ready, but we couldn't apply your theme — " <>
                      "you can set it anytime from Admin → Theme."

  @currencies [
    %{code: "GHS", label: "GHS — Ghana Cedi", flag: "\u{1F1EC}\u{1F1ED}"},
    %{code: "NGN", label: "NGN — Nigerian Naira", flag: "\u{1F1F3}\u{1F1EC}"},
    %{code: "USD", label: "USD — US Dollar", flag: "\u{1F1FA}\u{1F1F8}"}
  ]

  # Editorial copy per theme, in the order the picker presents them.
  # Coverage comes from ThemeResolver.offerable_theme_ids/0 (the single
  # theme-offer authority); names and colors come from each theme module.
  # Only the one-line descriptions live here. An offerable theme missing
  # from this list raises in build_themes/0 — a loud test failure instead
  # of a silent omission.
  @theme_descriptions [
    {"starter", "Clean & modern — fits any store"},
    {"market", "Simple commerce for everyday stores"},
    {"atelier", "Premium editorial aesthetic"},
    {"vibrant", "Bold West African energy"},
    {"bold", "Editorial & dramatic"},
    {"fresh", "Food & grocery"},
    {"fashion", "Editorial boutique"},
    {"beauty", "Skincare & cosmetics"},
    {"pharmacy", "Wellness & medicines"},
    {"home_living", "Furniture & home goods"},
    {"electronics", "Phones, audio & gadgets"},
    {"spotlight", "One hero product, centre stage"},
    {"ntoma", "Fashion & tailoring — cloth, cut, and print"},
    {"sika", "Jewellery & gold — few pieces, each precious"},
    {"fie", "Home & décor — a quiet gallery for your work"},
    {"chale", "Streetwear & sneakers — drops, sizes, hype"},
    {"dede", "Food & catering — order fast, order on WhatsApp"},
    {"pace", "Activewear & techwear — built for motion"},
    {"depot", "Wholesale — quick-order tables for repeat buyers"},
    {"akwaaba", "Photo-led — let your product shots do the selling"}
  ]

  def mount(_params, session, socket) do
    current_user = resolve_user(session)

    if current_user && has_store_membership?(current_user) do
      {:ok,
       socket
       |> assign(current_user: current_user)
       |> put_flash(:info, "You've already completed onboarding")
       |> push_navigate(to: "/dashboard")}
    else
      {:ok,
       assign(socket,
         page_title: "Set Up Your Store",
         step: 1,
         total_steps: 4,
         current_user: current_user,
         user_type: user_type(current_user),
         store_name: "",
         store_slug: "",
         currency: "GHS",
         currencies: @currencies,
         themes: build_themes(),
         preview_font_urls: preview_font_urls(),
         selected_theme: "market",
         product_name: "",
         product_price: "",
         error: nil,
         created_store: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <%!-- Webfonts for the theme previews. root.html.heex only loads the
           admin fonts (Inter, Manrope, JetBrains Mono), so without these
           links every serif/display preview silently renders in its
           Georgia/system fallback — the merchant would not be seeing the
           theme they are choosing. Loaded here (not globally) so admin
           pages don't pay for fonts they never render; browsers honour
           <link rel="stylesheet"> in the body. Rendered from step 1 so
           the faces are warm before the picker appears. --%>
      <link :for={url <- @preview_font_urls} rel="stylesheet" href={url} />
      <div class="w-full max-w-lg space-y-8">
        <%!-- Step indicator --%>
        <div class="text-center">
          <div class="flex items-center gap-2 mb-2">
            <div
              :for={i <- 1..@total_steps}
              class={[
                "h-1.5 flex-1 rounded-full transition-all duration-300",
                if(i <= @step, do: "bg-emerald-500", else: "bg-gray-200")
              ]}
            >
            </div>
          </div>
          <p class="text-xs font-medium text-gray-500">
            Step {@step} of {@total_steps}
          </p>
        </div>

        <%!-- Error display --%>
        <div
          :if={@error}
          class="flex items-center gap-2 bg-red-50 text-red-700 text-sm font-medium p-4 rounded-xl border border-red-200"
        >
          <svg
            class="w-5 h-5 flex-shrink-0"
            fill="currentColor"
            viewBox="0 0 20 20"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
              clip-rule="evenodd"
            />
          </svg>
          {@error}
        </div>

        <%!-- Step 1: Name Your Store --%>
        <div :if={@step == 1} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-8 h-8 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.5 21v-7.5a.75.75 0 0 1 .75-.75h3a.75.75 0 0 1 .75.75V21m-4.5 0H2.36m11.14 0H18m0 0h3.64m-1.39 0V9.349M3.75 21V9.349m0 0a3.001 3.001 0 0 0 3.75-.615A2.993 2.993 0 0 0 9.75 9.75c.896 0 1.7-.393 2.25-1.016a2.993 2.993 0 0 0 2.25 1.016c.896 0 1.7-.393 2.25-1.015a3.001 3.001 0 0 0 3.75.614m-16.5 0a3.004 3.004 0 0 1-.621-4.72l1.189-1.19A1.5 1.5 0 0 1 5.378 3h13.243a1.5 1.5 0 0 1 1.06.44l1.19 1.189a3 3 0 0 1-.621 4.72M6.75 18h3.75a.75.75 0 0 0 .75-.75V13.5a.75.75 0 0 0-.75-.75H6.75a.75.75 0 0 0-.75.75v3.75c0 .414.336.75.75.75Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            Name Your Store
          </h1>
          <p class="text-gray-500">
            What should we call your online store?
          </p>

          <div class="space-y-4 text-left">
            <div>
              <label for="store_name" class="block text-sm font-medium text-gray-700 mb-1">
                Store name
              </label>
              <form id="store-name-form" phx-change="update_store_name">
                <input
                  type="text"
                  id="store_name"
                  name="store_name"
                  value={@store_name}
                  placeholder="e.g. Kojo's Fashion"
                  phx-debounce="300"
                  autofocus
                  class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </form>
              <p :if={@store_slug != ""} class="mt-1.5 text-xs text-gray-400">
                Your store URL: <span class="font-mono text-emerald-600">{@store_slug}</span>.emakola.com
              </p>
            </div>

            <div>
              <label for="currency" class="block text-sm font-medium text-gray-700 mb-1">
                Currency
              </label>
              <form id="currency-form" phx-change="update_currency">
                <select
                  id="currency"
                  name="currency"
                  class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                >
                  <option
                    :for={c <- @currencies}
                    value={c.code}
                    selected={c.code == @currency}
                  >
                    {c.flag} {c.label}
                  </option>
                </select>
              </form>
            </div>
          </div>
        </div>

        <%!-- Step 2: Choose Your Theme --%>
        <div :if={@step == 2} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-8 h-8 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4.098 19.902a3.75 3.75 0 005.304 0l6.401-6.402M6.75 21A3.75 3.75 0 013 17.25V4.125C3 3.504 3.504 3 4.125 3h5.25c.621 0 1.125.504 1.125 1.125v4.072M6.75 21a3.75 3.75 0 003.75-3.75V8.197M6.75 21h13.125c.621 0 1.125-.504 1.125-1.125v-5.25c0-.621-.504-1.125-1.125-1.125h-4.072M10.5 8.197l2.88-2.88c.438-.439 1.15-.439 1.59 0l3.712 3.713c.44.44.44 1.152 0 1.59l-2.88 2.88M6.75 17.25h.008v.008H6.75v-.008z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            Choose Your Theme
          </h1>
          <p class="text-gray-500">
            Pick a look for your storefront. You can customize it later.
          </p>

          <div class="grid grid-cols-2 gap-3 sm:gap-4 text-left">
            <button
              :for={theme <- @themes}
              type="button"
              phx-click="select_theme"
              phx-value-theme-id={theme.id}
              aria-pressed={to_string(theme.id == @selected_theme)}
              class={[
                "flex w-full flex-col overflow-hidden rounded-2xl border-2 text-left",
                "transition-all duration-200 motion-reduce:transition-none",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2",
                if(theme.id == @selected_theme,
                  do: "border-emerald-500 ring-1 ring-emerald-500 shadow-lg shadow-emerald-500/10",
                  else:
                    "border-gray-200 bg-white hover:border-gray-300 hover:shadow-md motion-safe:hover:-translate-y-0.5"
                )
              ]}
            >
              <%!-- Miniature storefront painted from the theme's own tokens.
                   Decorative: the accessible name is the label row below. --%>
              <div
                aria-hidden="true"
                class="pointer-events-none select-none"
                style={"background-color: #{theme.colors.background};"}
              >
                <%!-- Nav bar --%>
                <div
                  class="flex items-center justify-between border-b border-black/5 px-2.5 py-1.5"
                  style={"background-color: #{theme.colors.surface};"}
                >
                  <div
                    class="h-1.5 w-7 rounded-full"
                    style={"background-color: #{theme.colors.primary};"}
                  >
                  </div>
                  <div class="flex items-center gap-1">
                    <div
                      class="h-1 w-3 rounded-full opacity-25"
                      style={"background-color: #{theme.colors.primary};"}
                    >
                    </div>
                    <div
                      class="h-1 w-3 rounded-full opacity-25"
                      style={"background-color: #{theme.colors.primary};"}
                    >
                    </div>
                    <div
                      class="h-1.5 w-1.5 rounded-full"
                      style={"background-color: #{theme.colors.accent};"}
                    >
                    </div>
                  </div>
                </div>
                <%!-- Hero: the merchant's shop sign in the theme's heading font --%>
                <div class="px-2.5 pb-2 pt-2.5">
                  <p
                    class="truncate text-[11px] font-bold leading-tight"
                    style={"color: #{theme.colors.text}; font-family: #{theme.font_stack};"}
                  >
                    {preview_store_name(@store_name)}
                  </p>
                  <div
                    class="mt-1 h-1 w-10 rounded-full opacity-30"
                    style={"background-color: #{theme.colors.text};"}
                  >
                  </div>
                  <div
                    class="mt-1.5 h-3 w-11 rounded-full"
                    style={"background-color: #{theme.colors.accent};"}
                  >
                  </div>
                </div>
                <%!-- 2×2 product grid with price chips --%>
                <div class="grid grid-cols-2 gap-1.5 px-2.5 pb-2.5">
                  <div
                    :for={{minor, index} <- Enum.with_index(preview_prices())}
                    class="overflow-hidden rounded-md shadow-sm"
                    style={"background-color: #{theme.colors.surface};"}
                  >
                    <div
                      class={[
                        "h-6 w-full sm:h-7",
                        if(rem(index, 2) == 0, do: "opacity-75", else: "opacity-40")
                      ]}
                      style={"background-color: #{if rem(index, 3) == 0, do: theme.colors.accent, else: theme.colors.primary};"}
                    >
                    </div>
                    <div class="space-y-1 px-1.5 py-1">
                      <div
                        class="h-0.5 w-3/4 rounded-full opacity-25"
                        style={"background-color: #{theme.colors.text};"}
                      >
                      </div>
                      <p
                        class="text-[7px] font-semibold leading-none"
                        style={"color: #{theme.colors.text};"}
                      >
                        {format_minor_price(minor, @currency)}
                      </p>
                    </div>
                  </div>
                </div>
                <%!-- Footer band --%>
                <div class="h-2.5 w-full" style={"background-color: #{theme.colors.primary};"}></div>
              </div>

              <%!-- Label row --%>
              <div class={[
                "flex flex-1 items-start justify-between gap-2 border-t p-3",
                if(theme.id == @selected_theme,
                  do: "border-emerald-100 bg-emerald-50",
                  else: "border-gray-100 bg-white"
                )
              ]}>
                <div class="min-w-0">
                  <p class="text-sm font-semibold text-gray-900">{theme.name}</p>
                  <p class="mt-0.5 text-xs leading-snug text-gray-500">{theme.description}</p>
                </div>
                <div
                  :if={theme.id == @selected_theme}
                  class="mt-0.5 shrink-0 rounded-full bg-emerald-500 p-0.5 text-white"
                >
                  <svg
                    class="h-3 w-3"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="3"
                    stroke="currentColor"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
                  </svg>
                </div>
                <div
                  :if={theme.id != @selected_theme}
                  class="mt-0.5 h-4 w-4 shrink-0 rounded-full border-2 border-gray-200"
                >
                </div>
              </div>
            </button>
          </div>
        </div>

        <%!-- Step 3: Add Your First Product --%>
        <div :if={@step == 3} class="space-y-6 text-center">
          <div class="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-8 h-8 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M20.25 7.5l-.625 10.632a2.25 2.25 0 0 1-2.247 2.118H6.622a2.25 2.25 0 0 1-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            Add Your First Product
          </h1>
          <p class="text-gray-500">
            You can add products now or skip and do it later from your dashboard.
          </p>

          <div class="space-y-4 text-left">
            <div>
              <label for="product_name" class="block text-sm font-medium text-gray-700 mb-1">
                Product name
              </label>
              <form id="product-name-form" phx-change="update_product">
                <input
                  type="text"
                  id="product_name"
                  name="product_name"
                  value={@product_name}
                  placeholder="e.g. Ankara Dress"
                  phx-debounce="300"
                  class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </form>
            </div>

            <div>
              <label for="product_price" class="block text-sm font-medium text-gray-700 mb-1">
                Price ({@currency})
              </label>
              <form id="product-price-form" phx-change="update_product">
                <input
                  type="number"
                  id="product_price"
                  name="product_price"
                  value={@product_price}
                  placeholder="e.g. 150"
                  min="0"
                  step="0.01"
                  phx-debounce="300"
                  class="w-full bg-white border border-gray-300 rounded-lg px-4 py-3 text-sm text-gray-900 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                />
              </form>
            </div>
          </div>

          <p class="text-xs text-gray-400">
            Don't worry — you can add unlimited products later.
          </p>
        </div>

        <%!-- Step 4: You're Ready! --%>
        <div :if={@step == 4} class="space-y-6 text-center">
          <div class="w-20 h-20 rounded-full bg-emerald-50 flex items-center justify-center mx-auto">
            <svg
              class="w-10 h-10 text-emerald-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
              />
            </svg>
          </div>
          <h1 class="text-2xl sm:text-3xl font-extrabold text-gray-900">
            You're Ready!
          </h1>
          <p class="text-gray-500">
            Your store is set up. Time to start selling!
          </p>

          <div class="bg-white rounded-xl p-5 space-y-3 text-sm text-left border border-gray-200 shadow-sm">
            <div class="flex items-center gap-3">
              <svg
                class="w-5 h-5 text-emerald-500 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <div>
                <span class="font-medium text-gray-900">{@store_name}</span>
                <span class="text-gray-400 text-xs ml-2">{@currency}</span>
              </div>
            </div>
            <div :if={@product_name != ""} class="flex items-center gap-3">
              <svg
                class="w-5 h-5 text-emerald-500 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <div>
                <span class="font-medium text-gray-900">{@product_name}</span>
                <span :if={@product_price != ""} class="text-gray-400 text-xs ml-2">
                  {format_price(@product_price, @currency)}
                </span>
              </div>
            </div>
            <div :if={@product_name == ""} class="flex items-center gap-3">
              <svg class="w-5 h-5 text-gray-300 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM6.75 9.25a.75.75 0 000 1.5h6.5a.75.75 0 000-1.5h-6.5z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="text-gray-400">No products yet — you can add them later</span>
            </div>
          </div>
        </div>

        <%!-- Navigation --%>
        <div class="flex justify-between items-center">
          <button
            :if={@step > 1}
            phx-click="prev_step"
            class="flex items-center gap-1 px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
            </svg>
            Back
          </button>
          <div :if={@step == 1}></div>

          <div class="flex items-center gap-3">
            <button
              :if={@step == 3}
              phx-click="skip_step"
              class="px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors"
            >
              Skip for now
            </button>
            <button
              phx-click={if @step < @total_steps, do: "next_step", else: "complete"}
              disabled={@step == 1 and String.trim(@store_name) == ""}
              class={[
                "font-semibold px-6 py-2.5 rounded-lg text-sm flex items-center gap-2 transition-all",
                if(@step == 1 and String.trim(@store_name) == "",
                  do: "bg-gray-100 text-gray-400 cursor-not-allowed",
                  else: "bg-emerald-600 text-white hover:bg-emerald-700 active:scale-95 shadow-sm"
                )
              ]}
            >
              {step_button_label(@step, @total_steps)}
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Events ──

  def handle_event("update_store_name", %{"store_name" => name}, socket) do
    slug = generate_slug(name)
    {:noreply, assign(socket, store_name: name, store_slug: slug, error: nil)}
  end

  def handle_event("update_currency", %{"currency" => currency}, socket) do
    {:noreply, assign(socket, currency: currency)}
  end

  def handle_event("select_theme", %{"theme-id" => theme_id}, socket) do
    # theme-id comes from the client — only ids the picker actually offers
    # may be selected (and later persisted). Crafted ids are ignored.
    if theme_id in offered_theme_ids() do
      {:noreply, assign(socket, selected_theme: theme_id)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_product", params, socket) do
    product_name = params["product_name"] || socket.assigns.product_name
    product_price = params["product_price"] || socket.assigns.product_price

    {:noreply, assign(socket, product_name: product_name, product_price: product_price)}
  end

  def handle_event("next_step", _, socket) do
    case validate_step(socket.assigns.step, socket.assigns) do
      :ok ->
        next = min(socket.assigns.step + 1, socket.assigns.total_steps)

        if next == socket.assigns.total_steps do
          # Moving to final step — create the store
          case create_store(socket.assigns) do
            {:ok, store, theme_flash} ->
              {:noreply,
               socket
               |> maybe_flash_theme_failure(theme_flash)
               |> assign(error: nil, step: next, created_store: store)}

            {:error, reason} ->
              {:noreply, assign(socket, error: "Setup failed: #{reason}")}
          end
        else
          {:noreply, socket |> assign(error: nil, step: next)}
        end

      {:error, msg} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("skip_step", _, socket) do
    # Skip clears product fields and advances
    socket = assign(socket, product_name: "", product_price: "")
    # Move to final step — create the store
    case create_store(socket.assigns) do
      {:ok, store, theme_flash} ->
        {:noreply,
         socket
         |> maybe_flash_theme_failure(theme_flash)
         |> assign(error: nil, step: socket.assigns.total_steps, created_store: store)}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Setup failed: #{reason}")}
    end
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, update(socket, :step, &max(&1 - 1, 1))}
  end

  def handle_event("complete", _, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Welcome to Makola! Your store is ready.")
     |> push_navigate(to: "/dashboard")}
  end

  # ── Private helpers ──

  # Merchant-only resolution — legacy User subjects no longer authenticate
  # here (User accounts use the platform session flow exclusively).
  defp resolve_user(session) do
    case EmakolaWeb.AuthTokens.verify_subject(session["user_token"]) do
      {:error, _reason} ->
        nil

      {:ok, subject} ->
        case AshAuthentication.subject_to_user(subject, Emakola.Accounts.Merchant) do
          {:ok, merchant} -> merchant
          _ -> nil
        end
    end
  end

  defp user_type(%Emakola.Accounts.Merchant{}), do: :merchant
  defp user_type(_), do: nil

  defp has_store_membership?(user) do
    case user_type(user) do
      :merchant ->
        case Emakola.Accounts.get_merchant_store_membership(user.id, authorize?: false) do
          {:ok, membership} when not is_nil(membership) -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp validate_step(1, assigns) do
    if String.trim(assigns.store_name) == "",
      do: {:error, "Please enter a store name."},
      else: :ok
  end

  defp validate_step(_, _), do: :ok

  defp generate_slug(name) do
    name
    |> String.trim()
    |> Slug.slugify()
    |> case do
      nil -> ""
      slug -> slug
    end
  end

  defp create_store(assigns) do
    user = assigns.current_user

    if is_nil(user) do
      {:error, "You must be logged in to create a store."}
    else
      store_name = String.trim(assigns.store_name)
      slug = generate_slug(store_name)
      currency = assigns.currency

      with {:ok, store} <-
             Emakola.Stores.create_store(%{name: store_name, slug: slug, currency: currency},
               authorize?: false
             ),
           {:ok, _membership} <- create_membership_for_user(user, store) do
        maybe_create_product(assigns, store)

        # A failed theme write must not fail onboarding — the merchant still
        # gets their store — but it is logged and surfaced, never swallowed.
        case maybe_save_theme(assigns, store) do
          {:ok, store} -> {:ok, store, nil}
          {:error, store} -> {:ok, store, @theme_save_flash}
        end
      else
        {:error, %Ash.Error.Invalid{} = error} ->
          {:error, Exception.message(error)}

        {:error, error} ->
          {:error, inspect(error)}
      end
    end
  end

  defp create_membership_for_user(%Emakola.Accounts.Merchant{} = merchant, store) do
    Emakola.Accounts.create_store_membership(
      %{role: :owner, merchant_id: merchant.id, store_id: store.id},
      authorize?: false
    )
  end

  defp maybe_create_product(assigns, store) do
    product_name = String.trim(assigns.product_name || "")

    if product_name != "" do
      price = parse_price(assigns.product_price)

      Emakola.Catalog.create_product(%{title: product_name, store_id: store.id},
        authorize?: false
      )
      |> case do
        {:ok, product} when price > 0 ->
          # Create a default variant with the price
          Emakola.Catalog.create_variant(
            %{
              price: price,
              product_id: product.id,
              store_id: store.id
            },
            authorize?: false
          )

        _ ->
          :ok
      end
    end
  end

  defp maybe_save_theme(assigns, store) do
    selected_theme = Map.get(assigns, :selected_theme, "market")
    actor = Map.get(assigns, :current_user)
    save_theme(store, selected_theme, actor)
  end

  # Public for the test exercising the error branch — a rejected theme
  # write must never be silent: the store falls back to the default theme
  # and, without the log, that failure is invisible in production forever.
  @doc false
  def save_theme(store, theme_id, actor) do
    case Emakola.Stores.update_store_settings(
           store,
           %{theme_config: %{"theme" => theme_id}},
           actor: actor
         ) do
      {:ok, updated_store} ->
        {:ok, updated_store}

      {:error, error} ->
        Logger.error(
          "Onboarding theme save failed for store #{store.id} " <>
            "(theme=#{theme_id}): #{inspect(error)}"
        )

        {:error, store}
    end
  end

  defp maybe_flash_theme_failure(socket, nil), do: socket
  defp maybe_flash_theme_failure(socket, message), do: put_flash(socket, :error, message)

  defp parse_price(price) when is_binary(price) do
    case Float.parse(price) do
      {amount, _} when amount > 0 -> round(amount * 100)
      _ -> 0
    end
  end

  defp parse_price(_), do: 0

  defp format_price(price_str, currency) do
    case Float.parse(price_str) do
      {amount, _} ->
        "#{currency_symbol(currency)}#{:erlang.float_to_binary(amount, decimals: 2)}"

      _ ->
        ""
    end
  end

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(currency), do: currency

  defp step_button_label(step, total_steps) when step < total_steps, do: "Continue"
  defp step_button_label(_, _), do: "Go to Dashboard"

  @doc """
  Theme ids the picker offers — delegated to the single theme-offer
  authority, `Emakola.Themes.ThemeResolver.offerable_theme_ids/0`.
  """
  def offered_theme_ids, do: Emakola.Themes.ThemeResolver.offerable_theme_ids()

  # Build the theme picker list. Coverage derives from ThemeResolver
  # (via offered_theme_ids/0); names, colors, and fonts come from each
  # theme module's name/0 and defaults() so the previews stay honest when
  # a theme's brand changes. Only the editorial descriptions are local.
  defp build_themes do
    offered = offered_theme_ids()
    described = Enum.map(@theme_descriptions, &elem(&1, 0))

    case offered -- described do
      [] ->
        :ok

      missing ->
        raise "themes offerable per ThemeResolver but missing from the onboarding " <>
                "picker: #{inspect(missing)} — add editorial copy to @theme_descriptions"
    end

    for {id, description} <- @theme_descriptions, id in offered do
      theme_mod = Emakola.Themes.ThemeResolver.theme_module(id)
      defaults = theme_mod.defaults()

      %{
        id: id,
        name: theme_mod.name(),
        description: description,
        colors: %{
          primary: defaults.colors.primary,
          accent: defaults.colors.accent,
          background: Map.get(defaults.colors, :background, "#FFFFFF"),
          surface: Map.get(defaults.colors, :surface, "#FFFFFF"),
          text: Map.get(defaults.colors, :text, defaults.colors.primary)
        },
        font_stack: heading_font_stack(defaults.fonts.heading)
      }
    end
  end

  # Every Google Fonts stylesheet the offered previews need, deduplicated
  # across themes — the same per-theme fonts/0 URL lists the storefront
  # layout links (all carry display=swap). Derived from the offered set,
  # so a newly offered theme's preview loads its real faces automatically.
  defp preview_font_urls do
    offered_theme_ids()
    |> Enum.flat_map(&Emakola.Themes.ThemeResolver.theme_module(&1).fonts())
    |> Enum.uniq()
  end

  # Serif display faces fall back to a serif so the mock still reads
  # "editorial" when the exact face isn't loaded; everything else falls
  # back to the system sans (same generic-fallback style as
  # Emakola.Themes.DesignTokens). Unknown future serifs degrade to sans —
  # cosmetic only, the colors still carry the preview.
  @serif_heading_fonts ["Cormorant Garamond", "Playfair Display", "Fraunces", "Cormorant", "Lora"]

  defp heading_font_stack(heading) do
    fallback =
      if heading in @serif_heading_fonts, do: "Georgia, serif", else: "system-ui, sans-serif"

    "'#{heading}', #{fallback}"
  end

  # Price chips for the preview mocks — integer minor units (pesewas/kobo),
  # formatted without ever touching a float.
  @preview_prices_minor [12_000, 8_500, 24_000, 6_500]

  defp preview_prices, do: @preview_prices_minor

  defp format_minor_price(minor, currency) when is_integer(minor) do
    whole = div(minor, 100)

    case rem(minor, 100) do
      0 ->
        "#{currency_symbol(currency)}#{whole}"

      cents ->
        "#{currency_symbol(currency)}#{whole}." <>
          String.pad_leading(Integer.to_string(cents), 2, "0")
    end
  end

  defp preview_store_name(store_name) do
    case String.trim(store_name) do
      "" -> "Your Store"
      name -> name
    end
  end
end
