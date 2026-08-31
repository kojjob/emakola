defmodule EmakolaWeb.OnboardingLive do
  @moduledoc """
  Onboarding flow for new Makola merchants.

  3-step flow:
  1. Name Your Store — store name, currency, auto-generated slug
  2. Add Your First Product — optional, skippable
  3. You're Ready! — summary + go to dashboard
  """

  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.NoIndex, :default}

  require Logger

  @theme_save_flash "Your store is ready, but we couldn't apply your theme — " <>
                      "you can set it anytime from Admin → Theme."

  # Short spoken names, not codes: the button already shows the symbol, and
  # a merchant who does not read well recognises "Cedi" faster than "GHS".
  @currencies [
    %{code: "GHS", name: "Cedi"},
    %{code: "NGN", name: "Naira"},
    %{code: "USD", name: "Dollar"}
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
    {"heirloom", "Furniture & interiors — warm neutrals, photography first"},
    {"electronics", "Phones, audio & gadgets"},
    {"spotlight", "One hero product, centre stage"},
    {"ntoma", "Fashion & tailoring — cloth, cut, and print"},
    {"sika", "Jewellery & gold — few pieces, each precious"},
    {"fie", "Home & décor — a quiet gallery for your work"},
    {"chale", "Streetwear & sneakers — drops, sizes, hype"},
    {"dede", "Food & catering — order fast, order on WhatsApp"},
    {"pace", "Activewear & techwear — built for motion"},
    {"depot", "Wholesale — quick-order tables for repeat buyers"},
    {"akwaaba", "Photo-led — let your product shots do the selling"},
    {"adwuma", "Digital goods — ebooks, beats, courses, files"}
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
      themes = build_themes()

      {:ok,
       assign(socket,
         page_title: "Set Up Your Store",
         step: 1,
         buyer_protection: false,
         total_steps: 4,
         current_user: current_user,
         user_type: user_type(current_user),
         store_name: "",
         store_name_form: value_form("store_name", ""),
         store_slug: "",
         currency: "GHS",
         currencies: @currencies,
         themes: themes,
         preview_font_urls: preview_font_urls(),
         selected_theme: "market",
         current_theme: current_theme(themes, "market"),
         product_name: "",
         product_name_form: value_form("product_name", ""),
         product_price: "",
         product_price_form: value_form("product_price", ""),
         error: nil,
         created_store: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <%!-- Webfonts for the shop preview and the look swatches. root.html.heex
         only loads the admin fonts (Inter, Manrope, JetBrains Mono), so
         without these links every serif/display face silently renders in its
         Georgia/system fallback — the merchant would not be seeing the look
         they are choosing. Loaded here, not globally, so admin pages don't
         pay for fonts they never render. --%>
      <link :for={url <- @preview_font_urls} rel="stylesheet" href={url} />

      <div class="flex min-h-screen flex-col bg-slate-900 lg:flex-row-reverse">
        <%!-- ── The shop being built ──
           This is the progress indicator. There is no step counter and no
           progress bar to read: the merchant's own shop sits here and fills
           in as they answer — the sign goes up as they type, the whole shop
           repaints when they pick a look, their product lands on the shelf. --%>
        <div class="flex-none bg-gradient-to-br from-[#14283C] to-slate-900 px-5 pb-10 pt-6 lg:flex lg:flex-1 lg:flex-col lg:justify-center lg:px-12">
          <div class="mx-auto w-full max-w-3xl">
            <div class="mb-3 flex items-center justify-between gap-4 lg:mb-4">
              <p class="text-[11px] font-bold uppercase tracking-[0.08em] text-white/55">
                Your shop so far
              </p>
              <div
                id="onboarding-progress"
                class="flex items-center gap-1.5"
                aria-label={"Step #{@step} of #{@total_steps}"}
              >
                <span
                  :for={i <- 1..@total_steps}
                  data-onboarding-dot={i}
                  aria-current={if i == @step, do: "step"}
                  class={[
                    "h-1.5 rounded-full transition-all duration-300 motion-reduce:transition-none",
                    cond do
                      i == @step -> "w-5 bg-emerald-400"
                      i < @step -> "w-1.5 bg-emerald-400"
                      true -> "w-1.5 bg-white/25"
                    end
                  ]}
                >
                </span>
              </div>
            </div>

            <div
              id="onboarding-shop-preview"
              class="overflow-hidden rounded-2xl shadow-2xl shadow-black/50"
              style={"background-color: #{@current_theme.colors.background};"}
            >
              <%!-- Shop nav --%>
              <div
                class="flex items-center justify-between px-4 py-3 lg:px-6 lg:py-4"
                style={"background-color: #{@current_theme.colors.surface};"}
              >
                <div
                  class="h-2 w-16 rounded-full lg:h-3 lg:w-24"
                  style={"background-color: #{@current_theme.colors.primary};"}
                >
                </div>
                <div class="flex items-center gap-2 lg:gap-3.5">
                  <div
                    class="h-1.5 w-6 rounded-full opacity-25 lg:w-9"
                    style={"background-color: #{@current_theme.colors.primary};"}
                  >
                  </div>
                  <div
                    class="h-1.5 w-6 rounded-full opacity-25 lg:w-9"
                    style={"background-color: #{@current_theme.colors.primary};"}
                  >
                  </div>
                  <div
                    class="h-2.5 w-2.5 rounded-full lg:h-4 lg:w-4"
                    style={"background-color: #{@current_theme.colors.accent};"}
                  >
                  </div>
                </div>
              </div>

              <%!-- The shop sign: the merchant's own name, in the face of the
                 look they picked. --%>
              <div class="px-4 pb-4 pt-5 lg:px-8 lg:pb-6 lg:pt-8">
                <p
                  id="onboarding-shop-sign"
                  class="truncate text-2xl font-bold leading-tight lg:text-4xl"
                  style={"color: #{@current_theme.colors.text}; font-family: #{@current_theme.font_stack};"}
                >
                  {preview_store_name(@store_name)}
                </p>
                <div
                  class="mt-2 h-1 w-16 rounded-full opacity-30 lg:mt-3.5 lg:h-1.5 lg:w-28"
                  style={"background-color: #{@current_theme.colors.text};"}
                >
                </div>
                <div
                  class="mt-3 h-6 w-24 rounded-full lg:mt-5 lg:h-8 lg:w-36"
                  style={"background-color: #{@current_theme.colors.accent};"}
                >
                </div>
              </div>

              <%!-- The shelf. The first slot is the merchant's own product
                 once they name it; the rest stand in for a stocked shop. --%>
              <div class="grid grid-cols-4 gap-2 px-4 pb-4 lg:gap-4 lg:px-8 lg:pb-8">
                <div
                  id="onboarding-shelf-hero"
                  class="overflow-hidden rounded-lg shadow-sm"
                  style={shelf_hero_style(@current_theme, @product_name)}
                >
                  <div
                    class="flex h-14 w-full items-center justify-center lg:h-28"
                    style={"background-color: #{shelf_hero_fill(@current_theme, @product_name)};"}
                  >
                    <svg
                      :if={@product_name == ""}
                      class="h-5 w-5 opacity-40 lg:h-8 lg:w-8"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.6"
                      stroke="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M3 8.5A1.5 1.5 0 0 1 4.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0 1 21 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-9Z"
                      />
                      <circle cx="12" cy="12.5" r="3.4" />
                    </svg>
                  </div>
                  <div class="px-1.5 py-1.5 lg:px-3 lg:py-3">
                    <p
                      :if={@product_name != ""}
                      class="truncate text-[10px] font-semibold leading-tight lg:text-sm"
                      style={"color: #{@current_theme.colors.text};"}
                    >
                      {@product_name}
                    </p>
                    <div
                      :if={@product_name == ""}
                      class="h-1 w-3/4 rounded-full opacity-20 lg:h-2"
                      style={"background-color: #{@current_theme.colors.text};"}
                    >
                    </div>
                    <p
                      class="mt-1 text-[9px] font-bold leading-none lg:mt-2 lg:text-base"
                      style={"color: #{@current_theme.colors.primary};"}
                    >
                      {shelf_hero_price(@product_name, @product_price, @currency)}
                    </p>
                  </div>
                </div>

                <div
                  :for={{minor, index} <- Enum.with_index(shelf_filler_prices())}
                  class="overflow-hidden rounded-lg shadow-sm"
                  style={"background-color: #{@current_theme.colors.surface};"}
                >
                  <div
                    class={[
                      "h-14 w-full lg:h-28",
                      if(rem(index, 2) == 0, do: "opacity-40", else: "opacity-70")
                    ]}
                    style={"background-color: #{if index == 1, do: @current_theme.colors.accent, else: @current_theme.colors.primary};"}
                  >
                  </div>
                  <div class="px-1.5 py-1.5 lg:px-3 lg:py-3">
                    <div
                      class="h-1 w-3/4 rounded-full opacity-20 lg:h-2"
                      style={"background-color: #{@current_theme.colors.text};"}
                    >
                    </div>
                    <p
                      class="mt-1 text-[9px] font-bold leading-none lg:mt-2 lg:text-base"
                      style={"color: #{@current_theme.colors.text};"}
                    >
                      {format_minor_price(minor, @currency)}
                    </p>
                  </div>
                </div>
              </div>

              <div
                class="h-4 w-full lg:h-7"
                style={"background-color: #{@current_theme.colors.primary};"}
              >
              </div>
            </div>
          </div>
        </div>

        <%!-- ── One question at a time ── --%>
        <div class="relative z-10 -mt-5 flex flex-1 flex-col rounded-t-3xl bg-white px-5 pb-7 pt-7 lg:mt-0 lg:w-[520px] lg:flex-none lg:rounded-none lg:px-12 lg:pb-10 lg:pt-10">
          <div
            :if={@error}
            id="onboarding-error"
            class="mb-5 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700"
          >
            <svg
              class="h-5 w-5 flex-shrink-0"
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

          <div class="flex flex-1 flex-col justify-center">
            <%!-- Step 1: name and money.
               No autofocus: the question sits below the shop, so a keyboard
               opening on load (Android honours it) scrolls the shop off
               screen at the exact moment the merchant is meant to watch it
               appear. One tap is cheaper than losing the point of the page. --%>
            <div :if={@step == 1} class="space-y-5">
              <div>
                <h1 class="text-2xl font-extrabold leading-tight text-gray-900 lg:text-3xl">
                  Put your name on it
                </h1>
                <p class="mt-2 text-base text-gray-500">Your sign goes up as you type.</p>
              </div>

              <.form for={@store_name_form} id="store-name-form" phx-change="update_store_name">
                <.input
                  field={@store_name_form[:store_name]}
                  type="text"
                  placeholder="Kojo's Fashion"
                  phx-debounce="300"
                  class="w-full rounded-xl border-2 border-gray-200 bg-white px-4 py-3.5 text-base font-semibold text-gray-900 focus:border-emerald-600 focus:ring-4 focus:ring-emerald-600/10"
                />
              </.form>

              <p
                :if={@store_slug != ""}
                id="store-slug-preview"
                data-slug={@store_slug}
                class="-mt-2 text-sm text-gray-500"
              >
                makola.io/<span class="font-bold text-emerald-700">{@store_slug}</span>
              </p>

              <div class="grid grid-cols-3 gap-2.5">
                <button
                  :for={money <- @currencies}
                  type="button"
                  phx-click="update_currency"
                  phx-value-currency={money.code}
                  aria-pressed={to_string(money.code == @currency)}
                  class={[
                    "rounded-xl border-2 px-2 py-3 text-center transition-all",
                    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2",
                    if(money.code == @currency,
                      do: "border-emerald-600 ring-4 ring-emerald-600/10",
                      else: "border-gray-200 hover:border-gray-300"
                    )
                  ]}
                >
                  <span class={[
                    "block text-lg font-extrabold",
                    if(money.code == @currency, do: "text-emerald-700", else: "text-gray-900")
                  ]}>
                    {currency_symbol(money.code)}
                  </span>
                  <span class="mt-0.5 block text-xs font-bold text-gray-500">{money.name}</span>
                </button>
              </div>
            </div>

            <%!-- Step 2: the look --%>
            <div :if={@step == 2} class="space-y-5">
              <div>
                <h1 class="text-2xl font-extrabold leading-tight text-gray-900 lg:text-3xl">
                  Dress your shop up
                </h1>
                <p class="mt-2 text-base text-gray-500">
                  {@current_theme.name} — one of {length(@themes)}.
                </p>
              </div>

              <div class="-mx-5 flex gap-2 overflow-x-auto px-5 pb-2 lg:mx-0 lg:grid lg:grid-cols-5 lg:gap-2.5 lg:overflow-visible lg:px-0">
                <button
                  :for={theme <- @themes}
                  type="button"
                  phx-click="select_theme"
                  phx-value-theme-id={theme.id}
                  aria-pressed={to_string(theme.id == @selected_theme)}
                  class={[
                    "w-[76px] shrink-0 rounded-xl border-2 p-1.5 transition-all lg:w-auto",
                    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2",
                    if(theme.id == @selected_theme,
                      do: "border-emerald-600 bg-emerald-50",
                      else: "border-transparent hover:bg-gray-50"
                    )
                  ]}
                >
                  <span
                    class="relative flex h-14 w-full items-center justify-center overflow-hidden rounded-lg border border-black/10"
                    style={"background-color: #{theme.colors.background};"}
                  >
                    <span
                      class="absolute inset-x-0 bottom-0 h-3"
                      style={"background-color: #{theme.colors.primary};"}
                    >
                    </span>
                    <span
                      class="absolute right-1.5 top-1.5 h-2 w-2 rounded-full"
                      style={"background-color: #{theme.colors.accent};"}
                    >
                    </span>
                    <span
                      class="relative -mt-1.5 text-xl font-bold leading-none"
                      style={"color: #{theme.colors.text}; font-family: #{theme.font_stack};"}
                    >
                      {theme_initial(theme.name)}
                    </span>
                  </span>
                  <span class={[
                    "mt-1.5 block truncate text-[11px] font-bold",
                    if(theme.id == @selected_theme, do: "text-emerald-700", else: "text-gray-500")
                  ]}>
                    {theme.name}
                  </span>
                </button>
              </div>
            </div>

            <%!-- Step 3: the first product --%>
            <div :if={@step == 3} class="space-y-5">
              <div>
                <h1 class="text-2xl font-extrabold leading-tight text-gray-900 lg:text-3xl">
                  Put one thing on the shelf
                </h1>
                <p class="mt-2 text-base text-gray-500">It appears in your shop as you type.</p>
              </div>

              <div class="flex h-32 flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed border-gray-300 bg-gray-50">
                <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-50">
                  <svg
                    class="h-6 w-6 text-emerald-600"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.6"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M3 8.5A1.5 1.5 0 0 1 4.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0 1 21 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-9Z"
                    />
                    <circle cx="12" cy="12.5" r="3.4" />
                  </svg>
                </span>
                <span class="text-sm font-bold text-gray-900">Take a photo</span>
                <span class="text-xs text-gray-400">You can add photos later</span>
              </div>

              <.form for={@product_name_form} id="product-name-form" phx-change="update_product">
                <.input
                  field={@product_name_form[:product_name]}
                  type="text"
                  placeholder="Ankara Dress"
                  phx-debounce="300"
                  class="w-full rounded-xl border-2 border-gray-200 bg-white px-4 py-3.5 text-base font-semibold text-gray-900 focus:border-emerald-600 focus:ring-4 focus:ring-emerald-600/10"
                />
              </.form>

              <.form for={@product_price_form} id="product-price-form" phx-change="update_product">
                <.input
                  field={@product_price_form[:product_price]}
                  type="number"
                  placeholder={"#{currency_symbol(@currency)} 150"}
                  min="0"
                  step="0.01"
                  phx-debounce="300"
                  class="w-full rounded-xl border-2 border-gray-200 bg-white px-4 py-3.5 text-base font-semibold text-gray-900 focus:border-emerald-600 focus:ring-4 focus:ring-emerald-600/10"
                />
              </.form>
            </div>

            <%!-- Step 4: it is open --%>
            <div :if={@step == 4} class="space-y-5">
              <div class="flex items-center gap-4">
                <span class="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 shadow-lg shadow-emerald-600/30">
                  <svg
                    class="h-7 w-7 text-white"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="3"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="m4 12.5 5 5L20 6.5" />
                  </svg>
                </span>
                <div>
                  <h1 class="text-2xl font-extrabold leading-tight text-gray-900 lg:text-3xl">
                    That is your shop
                  </h1>
                  <p class="mt-1 text-base text-gray-500">Share the link and start selling.</p>
                </div>
              </div>

              <div class="flex items-center gap-3 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3.5">
                <svg
                  class="h-5 w-5 flex-shrink-0 text-emerald-700"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M10 13a5 5 0 0 0 7.5.5l2-2a5 5 0 0 0-7-7l-1 1M14 11a5 5 0 0 0-7.5-.5l-2 2a5 5 0 0 0 7 7l1-1"
                  />
                </svg>
                <span class="truncate text-sm font-bold text-emerald-900">
                  makola.io/{@store_slug}
                </span>
              </div>

              <%!-- Asked, not assumed. Protection was opt-in and almost nobody
                 opted in — because nothing ever raised it. Defaulting it ON was
                 rejected deliberately: it makes Makola custodian of the
                 merchant's money between sale and delivery. So it is one short
                 question, in plain words, at the moment they are already
                 deciding how their shop works. --%>
              <label class={[
                "flex cursor-pointer items-center gap-3.5 rounded-2xl border-2 bg-white p-4 transition-all",
                if(@buyer_protection,
                  do: "border-emerald-600 ring-4 ring-emerald-600/10",
                  else: "border-gray-200"
                )
              ]}>
                <span class={[
                  "flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl",
                  if(@buyer_protection, do: "bg-emerald-50", else: "bg-gray-100")
                ]}>
                  <svg
                    class={[
                      "h-6 w-6",
                      if(@buyer_protection, do: "text-emerald-600", else: "text-gray-400")
                    ]}
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.8"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M12 3l7.5 3v5.5c0 4.5-3.2 8.2-7.5 9.5-4.3-1.3-7.5-5-7.5-9.5V6L12 3Z"
                    />
                    <path stroke-linecap="round" stroke-linejoin="round" d="m9 12 2 2 4-4" />
                  </svg>
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block text-sm font-extrabold text-gray-900">
                    Hold money till delivery
                  </span>
                  <span class="mt-1 block text-xs leading-snug text-gray-500">
                    Safer for buyers. You are paid later.
                  </span>
                </span>
                <input
                  type="checkbox"
                  name="buyer_protection"
                  checked={@buyer_protection}
                  phx-click="toggle_buyer_protection"
                  class="h-6 w-6 flex-shrink-0 rounded-md border-gray-300 text-emerald-600 focus:ring-emerald-500"
                />
              </label>
            </div>
          </div>

          <%!-- Navigation. One loud button, in the thumb. --%>
          <div class="mt-7 flex items-center gap-3">
            <button
              :if={@step > 1}
              type="button"
              phx-click="prev_step"
              aria-label="Back"
              class="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-xl border-2 border-gray-200 text-gray-600 transition-colors hover:bg-gray-50"
            >
              <svg
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2.5"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.5 7.5 12 15 4.5" />
              </svg>
            </button>

            <button
              :if={@step == 3}
              type="button"
              phx-click="skip_step"
              class="h-14 flex-shrink-0 px-3 text-base font-bold text-gray-500 transition-colors hover:text-gray-900"
            >
              Skip
            </button>

            <button
              id="onboarding-next-button"
              type="button"
              phx-click={if @step < @total_steps, do: "next_step", else: "complete"}
              disabled={@step == 1 and String.trim(@store_name) == ""}
              class={[
                "flex h-14 flex-1 items-center justify-center gap-2.5 rounded-xl text-base font-extrabold transition-all",
                if(@step == 1 and String.trim(@store_name) == "",
                  do: "cursor-not-allowed bg-gray-100 text-gray-400",
                  else:
                    "bg-emerald-600 text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 active:scale-[.98]"
                )
              ]}
            >
              {step_button_label(@step, @total_steps)}
              <svg
                class="h-5 w-5"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2.5"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14m-6-6 6 6-6 6" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Events ──

  def handle_event("update_store_name", %{"store_name" => name}, socket) do
    slug = generate_slug(name)

    {:noreply,
     assign(socket,
       store_name: name,
       store_name_form: value_form("store_name", name),
       store_slug: slug,
       error: nil
     )}
  end

  def handle_event("update_currency", %{"currency" => currency}, socket) do
    {:noreply, assign(socket, currency: currency)}
  end

  def handle_event("select_theme", %{"theme-id" => theme_id}, socket) do
    # theme-id comes from the client — only ids the picker actually offers
    # may be selected (and later persisted). Crafted ids are ignored.
    if theme_id in offered_theme_ids() do
      {:noreply,
       assign(socket,
         selected_theme: theme_id,
         current_theme: current_theme(socket.assigns.themes, theme_id)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_product", params, socket) do
    product_name = params["product_name"] || socket.assigns.product_name
    product_price = params["product_price"] || socket.assigns.product_price

    {:noreply,
     assign(socket,
       product_name: product_name,
       product_name_form: value_form("product_name", product_name),
       product_price: product_price,
       product_price_form: value_form("product_price", product_price)
     )}
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
    socket =
      assign(socket,
        product_name: "",
        product_name_form: value_form("product_name", ""),
        product_price: "",
        product_price_form: value_form("product_price", "")
      )

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
    # The delivery question is asked on this screen, but the store was created
    # on the way in to it — so the answer is written here, once it is actually
    # known. Asking and then discarding the answer is the same failure as
    # never asking, which is what left protection off almost everywhere.
    save_buyer_protection(socket.assigns.created_store, socket.assigns.buyer_protection)

    {:noreply,
     socket
     |> put_flash(:info, "Welcome to Makola! Your store is ready.")
     |> push_navigate(to: "/dashboard")}
  end

  def handle_event("toggle_buyer_protection", _params, socket) do
    {:noreply, assign(socket, :buyer_protection, !socket.assigns.buyer_protection)}
  end

  # ── Private helpers ──

  defp value_form(field, value), do: to_form(%{field => value})

  # Merchant-only resolution — legacy User subjects no longer authenticate
  # here (User accounts use the platform session flow exclusively).
  defp resolve_user(session) do
    case EmakolaWeb.AuthTokens.verify_subject_with_iat(session["user_token"]) do
      {:error, _reason} ->
        nil

      {:ok, subject, issued_at} ->
        case AshAuthentication.subject_to_user(subject, Emakola.Accounts.Merchant) do
          # Same cutoff check as AssignDefaults — a session invalidated by a
          # password reset must not slip back in through onboarding.
          {:ok, merchant} when not is_nil(merchant) ->
            if Emakola.Accounts.session_live?(merchant, issued_at), do: merchant

          _ ->
            nil
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

  # :create accepts only name/slug/currency; :update_settings is the action
  # that already exposes this field to merchants, so the answer goes through it.
  defp apply_buyer_protection(store, true) do
    store
    |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
    |> Ash.update(authorize?: false)
  end

  defp apply_buyer_protection(store, _falsey), do: {:ok, store}

  # A failed write must not strand the merchant on the last screen — they
  # still have their store — but it is never silent: an answer that vanishes
  # looks identical to a merchant who declined.
  defp save_buyer_protection(nil, _enabled), do: :ok

  defp save_buyer_protection(store, enabled) do
    case apply_buyer_protection(store, enabled) do
      {:ok, _store} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Onboarding buyer-protection save failed for store #{store.id}: #{inspect(error)}"
        )
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
           {:ok, store} <- apply_buyer_protection(store, assigns[:buyer_protection]),
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
    # {:ok, _} is only returned for positive amounts; signs and trailing
    # garbage ("50abc") are rejected rather than silently coerced.
    case Emakola.Money.parse_price(price) do
      {:ok, pesewas} -> pesewas
      _ -> 0
    end
  end

  defp parse_price(_), do: 0

  defp currency_symbol("GHS"), do: "GH\u20B5"
  defp currency_symbol("NGN"), do: "\u20A6"
  defp currency_symbol("USD"), do: "$"
  defp currency_symbol(currency), do: currency

  defp step_button_label(step, total_steps) when step < total_steps, do: "Next"
  defp step_button_label(_, _), do: "Open my shop"

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

  # The look currently painted on the shop preview. Resolved once per
  # selection rather than searched on every render pass.
  defp current_theme(themes, selected_theme) do
    Enum.find(themes, hd(themes), &(&1.id == selected_theme))
  end

  defp theme_initial(name), do: name |> to_string() |> String.first()

  # The shelf: slot one belongs to the merchant's own product, the rest
  # stand in for a stocked shop.
  defp shelf_filler_prices, do: tl(preview_prices())

  defp shelf_hero_style(theme, "") do
    "background-color: #{theme.colors.surface};"
  end

  defp shelf_hero_style(theme, _product_name) do
    "background-color: #{theme.colors.surface}; " <>
      "outline: 2px solid #{theme.colors.accent}; outline-offset: -2px;"
  end

  defp shelf_hero_fill(_theme, ""), do: "rgba(0, 0, 0, 0.06)"
  defp shelf_hero_fill(theme, _product_name), do: theme.colors.accent

  # An unpriced product still shows a price slot, so the card never looks
  # broken while the merchant is still typing.
  defp shelf_hero_price("", _price, currency) do
    format_minor_price(hd(preview_prices()), currency)
  end

  defp shelf_hero_price(_product_name, price, currency) do
    # Through the same parser that will store the value, then formatted like
    # the chips beside it — a whole-cedi price must not read "GH\u20B5150.00"
    # next to "GH\u20B585".
    case parse_price(price) do
      0 -> "#{currency_symbol(currency)}\u2014"
      minor -> format_minor_price(minor, currency)
    end
  end

  defp preview_store_name(store_name) do
    case String.trim(store_name) do
      "" -> "Your Store"
      name -> name
    end
  end
end
