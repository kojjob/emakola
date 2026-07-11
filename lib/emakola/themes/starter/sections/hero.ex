defmodule Emakola.Themes.Starter.Sections.Hero do
  @moduledoc "Starter home hero -- extracted verbatim from starter/home.ex."
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import Emakola.Themes.Starter.Sections.Helpers

  @impl true
  def key, do: "starter/hero"
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
    ~H"""
    <section
      :if={section_enabled?(@theme, :hero)}
      class="relative overflow-hidden"
    >
      <div class="bg-gradient-to-br from-[var(--theme-primary,#6366F1)] to-[var(--theme-accent,#1E293B)]">
        <div class="relative max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28">
          <div class="max-w-2xl">
            <h1
              class="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-[1.1] mb-4 tracking-tight"
              style="font-family: 'Inter', sans-serif;"
            >
              {if @settings["heading"] not in [nil, ""],
                do: @settings["heading"],
                else: @theme.hero.title}
            </h1>
            <p
              class="text-lg sm:text-xl text-white/90 leading-relaxed mb-8 max-w-lg"
              style="font-family: 'Inter', sans-serif;"
            >
              {if @settings["subheading"] not in [nil, ""],
                do: @settings["subheading"],
                else:
                  if(@store.description,
                    do: @store.description,
                    else: @theme.hero.subtitle
                  )}
            </p>
            <div class="flex flex-wrap gap-3">
              <a
                href={store_path(@store.slug, "/products")}
                class="inline-flex items-center gap-2 px-8 py-4 bg-white text-[var(--theme-primary,#6366F1)] rounded-full text-base font-semibold hover:bg-gray-50 active:scale-[0.97] transition-all shadow-lg shadow-black/10"
                style="font-family: 'Inter', sans-serif;"
              >
                {if @settings["cta_label"] not in [nil, ""],
                  do: @settings["cta_label"],
                  else: @theme.hero.cta_text}
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
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
                class="inline-flex items-center gap-2 px-6 py-4 bg-white/10 text-white rounded-full text-base font-medium hover:bg-white/20 backdrop-blur-sm transition-all border border-white/20"
                style="font-family: 'Inter', sans-serif;"
              >
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                </svg>
                Chat with Us
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
