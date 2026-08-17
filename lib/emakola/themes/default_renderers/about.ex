defmodule Emakola.Themes.DefaultRenderers.About do
  @moduledoc """
  Default render for the storefront About page.

  Used by `EmakolaWeb.Storefront.AboutLive` for every theme that doesn't
  override `:about`. Renders inside the store's OWN chrome via
  `DefaultRenderers.Chrome` — the same dispatch cart and category use — so
  the About page no longer swaps a store's nav/footer for Atelier's. The
  body is theme-aware through the `--theme-*` CSS variables the storefront
  layout defines on every page.

  Content assembly is single-sourced in `content_assigns/1`: every text slot
  reads the store's `StorePageContent` and falls back to NEUTRAL,
  store-name-driven copy — never invented provenance. `Atelier.About` (the
  one theme keeping its own branded About) reuses the same assembly, so the
  buyer-facing copy cannot drift between the two.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @step_icons ["search", "hands", "package"]
  @value_icons ["shield", "heart", "leaf", "globe"]

  @default_steps [
    {"Browse", "Explore our collection and find the pieces you love."},
    {"Order", "Add to cart and check out securely in just a few taps."},
    {"Delivered", "We carefully pack your order and get it safely to your door."}
  ]

  @default_values [
    {"Quality", "We stand behind every item we sell."},
    {"Fair Prices", "Honest pricing with no surprises at checkout."},
    {"Customer Care", "Real people ready to help, before and after your order."},
    {"Trust", "Secure payments and reliable delivery you can count on."}
  ]

  @doc """
  Builds the About page content assigns from the store + `StorePageContent`.

  Public because it is the single source of the About copy: this renderer
  and `Atelier.About` both call it, so fallback copy stays identical.
  """
  def content_assigns(assigns) do
    store = assigns.store
    pc = Map.get(assigns, :page_content) || %{}

    assigns
    |> assign(
      :about_headline,
      blank_to_nil(Map.get(pc, :about_headline)) || "About #{store.name}"
    )
    |> assign(:about_intro, about_intro(pc, store))
    |> assign(:story_paragraphs, build_story(pc, store))
    |> assign(:process_steps, build_steps(pc))
    |> assign(:value_cards, build_values(pc))
    |> assign(:cta_heading, blank_to_nil(Map.get(pc, :about_cta_heading)) || "Ready to shop?")
    |> assign(
      :cta_text,
      blank_to_nil(Map.get(pc, :about_cta_text)) ||
        "Explore our collection — we'd love to have you."
    )
  end

  def render(assigns) do
    assigns = content_assigns(assigns)

    ~H"""
    <Emakola.Themes.DefaultRenderers.Chrome.navbar
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="about"
    />

    <%!-- Hero --%>
    <section class="max-w-5xl mx-auto px-4 sm:px-6 pt-12 sm:pt-16 pb-10 sm:pb-14">
      <span
        class="text-xs font-semibold uppercase tracking-[0.2em] block mb-3"
        style="color: var(--theme-primary);"
      >
        Our Story
      </span>
      <h1 class="text-3xl sm:text-5xl font-black text-stone-900 leading-tight mb-5 max-w-3xl">
        {@about_headline}
      </h1>
      <p class="text-lg text-stone-600 leading-relaxed max-w-2xl">
        {@about_intro}
      </p>
    </section>

    <%!-- Story --%>
    <section class="max-w-5xl mx-auto px-4 sm:px-6 pb-14 sm:pb-20">
      <div
        class="border-l-4 pl-6 sm:pl-8 space-y-4 text-stone-600 leading-relaxed max-w-2xl"
        style="border-color: var(--theme-primary);"
      >
        <p :for={paragraph <- @story_paragraphs}>{paragraph}</p>
      </div>
    </section>

    <%!-- How It Works --%>
    <section class="bg-stone-50 py-14 sm:py-20">
      <div class="max-w-5xl mx-auto px-4 sm:px-6">
        <h2 class="text-2xl sm:text-3xl font-black text-stone-900 text-center mb-10 sm:mb-14">
          How It Works
        </h2>
        <div class="grid gap-10 sm:grid-cols-3">
          <.process_step
            :for={step <- @process_steps}
            number={step.number}
            title={step.title}
            description={step.description}
            icon={step.icon}
          />
        </div>
      </div>
    </section>

    <%!-- Values --%>
    <section class="py-14 sm:py-20">
      <div class="max-w-5xl mx-auto px-4 sm:px-6">
        <h2 class="text-2xl sm:text-3xl font-black text-stone-900 text-center mb-10 sm:mb-14">
          Our Values
        </h2>
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.value_card
            :for={value <- @value_cards}
            icon={value.icon}
            title={value.title}
            description={value.description}
          />
        </div>
      </div>
    </section>

    <%!-- CTA --%>
    <section style="background: var(--theme-accent);">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 py-14 sm:py-16 text-center">
        <h2 class="text-2xl sm:text-3xl font-black text-white mb-3">{@cta_heading}</h2>
        <p class="text-white/70 mb-8 max-w-xl mx-auto">{@cta_text}</p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex items-center px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg bg-white text-stone-900 hover:bg-white/90 transition-colors min-h-[48px]"
          >
            Shop the Collection
          </a>
          <a
            :if={Map.get(@store, :whatsapp_number)}
            href={"https://wa.me/#{@store.whatsapp_number}?text=#{URI.encode("Hi! I'd love to learn more about your products.")}"}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 px-8 py-4 text-sm font-bold uppercase tracking-wider rounded-lg border-2 border-white/30 text-white hover:bg-white/10 transition-colors min-h-[48px]"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
              <path d="M12 0C5.373 0 0 5.373 0 12c0 2.625.846 5.059 2.284 7.034L.789 23.492a.5.5 0 00.613.613l4.458-1.495A11.952 11.952 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-2.24 0-4.31-.726-5.99-1.956l-.418-.312-2.65.888.888-2.65-.312-.418A9.935 9.935 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z" />
            </svg>
            Chat with Us
          </a>
        </div>
      </div>
    </section>

    <Emakola.Themes.DefaultRenderers.Chrome.footer
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
      categories={@categories}
    />
    """
  end

  # ── Cards ──

  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true

  defp process_step(assigns) do
    ~H"""
    <div class="text-center">
      <div
        class="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-5"
        style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
      >
        <.step_icon name={@icon} />
      </div>
      <span
        class="text-xs font-bold tracking-widest mb-2 block"
        style="color: var(--theme-primary);"
      >
        {@number}
      </span>
      <h3 class="text-lg font-bold text-stone-900 mb-3">{@title}</h3>
      <p class="text-sm text-stone-600 leading-relaxed">{@description}</p>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp value_card(assigns) do
    ~H"""
    <div class="bg-stone-50 rounded-xl p-6 sm:p-8 text-center">
      <div
        class="w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-4"
        style="background: color-mix(in srgb, var(--theme-primary) 12%, white);"
      >
        <.value_icon name={@icon} />
      </div>
      <h3 class="text-base font-bold text-stone-900 mb-2">{@title}</h3>
      <p class="text-sm text-stone-600 leading-relaxed">{@description}</p>
    </div>
    """
  end

  # ── Icons ──

  defp step_icon(%{name: "search"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
    """
  end

  defp step_icon(%{name: "hands"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M18 11V6a2 2 0 00-2-2 2 2 0 00-2 2v0M14 10V4a2 2 0 00-2-2 2 2 0 00-2 2v2M10 10.5V6a2 2 0 00-2-2 2 2 0 00-2 2v8" />
      <path d="M18 8a2 2 0 012 2v7.21a4 4 0 01-.86 2.48L16.5 23H8l-4.33-6A3 3 0 014.6 13.4L6 12" />
    </svg>
    """
  end

  defp step_icon(%{name: "package"} = assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M16.5 9.4l-9-5.19M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z" />
      <polyline points="3.27 6.96 12 12.01 20.73 6.96" /><line x1="12" y1="22.08" x2="12" y2="12" />
    </svg>
    """
  end

  defp step_icon(assigns) do
    ~H"""
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
    </svg>
    """
  end

  defp value_icon(%{name: "shield"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <polyline points="9 12 11 14 15 10" />
    </svg>
    """
  end

  defp value_icon(%{name: "heart"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
    </svg>
    """
  end

  defp value_icon(%{name: "leaf"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <path d="M17 8C8 10 5.9 16.17 3.82 21.34l1.89.66.95-2.3c.48.17.98.3 1.34.3C19 20 22 3 22 3c-1 2-8 2.25-13 3.25S2 11.5 2 13.5s1.75 3.75 1.75 3.75" />
    </svg>
    """
  end

  defp value_icon(%{name: "globe"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
      <line x1="2" y1="12" x2="22" y2="12" />
      <path d="M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z" />
    </svg>
    """
  end

  defp value_icon(assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      style="color: var(--theme-primary);"
    >
      <circle cx="12" cy="12" r="10" />
    </svg>
    """
  end

  # ── Content helpers ──
  #
  # Every text slot reads from the store's `StorePageContent` and falls back to
  # NEUTRAL, store-name-driven copy — never shared artisan/heritage prose.

  defp about_intro(pc, store) do
    blank_to_nil(Map.get(pc, :about_intro)) ||
      blank_to_nil(Map.get(store, :description)) ||
      "Welcome to #{store.name}. Here's a little more about who we are and what we offer."
  end

  defp build_story(pc, store) do
    case blank_to_nil(Map.get(pc, :about_story)) do
      nil ->
        [
          "#{store.name} is dedicated to bringing you quality products and a shopping experience you can trust. Thanks for taking a moment to learn more about us."
        ]

      story ->
        story
        |> String.split(~r/\n{2,}/, trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp build_steps(pc) do
    rows =
      case custom_pairs(pc, :about_steps) do
        [] -> @default_steps
        rows -> rows
      end

    rows
    |> Enum.with_index()
    |> Enum.map(fn {{title, description}, index} ->
      %{
        number: number(index),
        title: title,
        description: description || "",
        icon: Enum.at(@step_icons, rem(index, length(@step_icons)))
      }
    end)
  end

  defp build_values(pc) do
    rows =
      case custom_pairs(pc, :about_values) do
        [] -> @default_values
        rows -> rows
      end

    rows
    |> Enum.with_index()
    |> Enum.map(fn {{title, description}, index} ->
      %{
        title: title,
        description: description || "",
        icon: Enum.at(@value_icons, rem(index, length(@value_icons)))
      }
    end)
  end

  # Non-blank {title, description} pairs from a stored list field. Rows whose
  # title is blank are dropped so a half-filled admin form never renders gaps.
  defp custom_pairs(pc, key) do
    pc
    |> Map.get(key)
    |> List.wrap()
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn row ->
      {blank_to_nil(Map.get(row, "title")), blank_to_nil(Map.get(row, "description"))}
    end)
    |> Enum.filter(fn {title, _description} -> title end)
  end

  defp number(index) do
    index
    |> Kernel.+(1)
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp blank_to_nil(_), do: nil
end
