defmodule Emakola.Themes.Fresh.Sections.Hero do
  @moduledoc """
  Fresh home hero — emerald-to-amber gradient, leaf pattern, the store's
  own name as the headline. The theme ships no invented headline or
  standfirst: a merchant heading (section setting, then `@theme.hero`)
  wins, then the store's own description, then nothing.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Fresh.Shared

  @impl true
  def key, do: "fresh/hero"
  @impl true
  def label, do: "Hero"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: ""},
      %{key: "subheading", type: :string, label: "Subheading", default: ""},
      %{key: "cta_label", type: :string, label: "Button label", default: ""}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(
        :heading,
        present(assigns.settings["heading"]) || present(assigns.theme.hero.title) ||
          assigns.store.name
      )
      |> assign(
        :subheading,
        present(assigns.settings["subheading"]) || present(assigns.store.description) ||
          present(assigns.theme.hero.subtitle)
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :hero)} class="relative overflow-hidden">
      <div class="bg-gradient-to-br from-[#059669] via-[#047857] to-[#92400E]/30">
        <%!-- Organic leaf pattern overlay --%>
        <div class="absolute inset-0 opacity-[0.07]">
          <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <pattern
                id="fresh-leaves"
                x="0"
                y="0"
                width="60"
                height="60"
                patternUnits="userSpaceOnUse"
              >
                <circle cx="15" cy="15" r="6" fill="white" fill-opacity="0.4" />
                <circle cx="45" cy="45" r="4" fill="white" fill-opacity="0.3" />
                <path
                  d="M30 5 Q35 15 30 25 Q25 15 30 5Z"
                  fill="white"
                  fill-opacity="0.2"
                />
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#fresh-leaves)" />
          </svg>
        </div>

        <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28">
          <div class="max-w-2xl">
            <%!-- The leaf badge names the store above a merchant headline. When
                 the store's name is the headline it would say it twice. --%>
            <span
              :if={@heading != @store.name}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold tracking-widest uppercase text-[#D9F99D] bg-white/10 rounded-full mb-4 backdrop-blur-sm"
              style="font-family: 'Inter', sans-serif;"
            >
              <span
                class="material-symbols-outlined"
                style="font-size: 14px;"
              >
                eco
              </span>
              {@store.name}
            </span>
            <h1
              id="fresh-hero-heading"
              class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-4"
              style="font-family: 'Nunito', sans-serif;"
            >
              {@heading}
            </h1>
            <p
              :if={@subheading}
              class="text-lg sm:text-xl text-white/80 leading-relaxed mb-8 max-w-lg"
              style="font-family: 'Inter', sans-serif;"
            >
              {@subheading}
            </p>
            <div class="flex flex-wrap gap-3">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center gap-2 px-8 py-4 bg-white text-[var(--theme-primary,#047857)] rounded-full text-base font-bold hover:bg-[#ECFDF5] active:scale-[0.97] transition-all shadow-lg shadow-black/20"
                style="font-family: 'Inter', sans-serif;"
              >
                {if @settings["cta_label"] not in [nil, ""],
                  do: @settings["cta_label"],
                  else: @theme.hero.cta_text || "Start Shopping"}
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </a>
              <a
                :if={Map.get(@store, :whatsapp_number)}
                href={"https://wa.me/#{String.replace(@store.whatsapp_number || "", "+", "")}"}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 px-6 py-4 bg-white/10 text-white rounded-full text-base font-semibold hover:bg-white/20 backdrop-blur-sm transition-all border border-white/20"
                style="font-family: 'Inter', sans-serif;"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z" />
                  <path d="M12 2C6.477 2 2 6.477 2 12c0 1.89.525 3.66 1.438 5.168L2 22l4.832-1.438A9.955 9.955 0 0012 22c5.523 0 10-4.477 10-10S17.523 2 12 2z" />
                </svg>
                Order via WhatsApp
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp present(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present(_value), do: nil
end
