defmodule Emakola.Themes.Akwaaba.Sections.Editorial do
  @moduledoc """
  Akwaaba editorial band — a wide photograph with a serif headline laid over it.

  It renders only when the store actually has a photograph to carry it. A big
  overlay headline on an empty grey box is worse than no section at all, so with
  no imagery this one simply stands down.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Akwaaba.Shared

  @impl true
  def key, do: "akwaaba/editorial"
  @impl true
  def label, do: "Editorial banner"

  @impl true
  def settings_schema do
    [
      %{key: "headline", type: :string, label: "Headline", default: "Made to be worn"},
      %{key: "cta_label", type: :string, label: "Button label", default: "Explore the shop"}
    ]
  end

  @impl true
  def render(assigns) do
    image =
      assigns.products
      |> Enum.map(&Shared.first_image/1)
      |> Enum.find(&is_binary/1)

    assigns =
      assigns
      |> assign(:image, image)
      |> assign(:headline, present(assigns.settings["headline"]) || "Made to be worn")
      |> assign(:cta_label, present(assigns.settings["cta_label"]) || "Explore the shop")

    ~H"""
    <section
      :if={@image}
      class="bg-white px-5 py-12 [font-family:var(--akwaaba-body)] sm:px-10 sm:py-16"
      aria-labelledby="akwaaba-editorial-heading"
    >
      <div class="relative mx-auto max-w-[1320px] overflow-hidden rounded-[2rem]">
        <.optimized_image
          src={@image}
          alt=""
          width={1440}
          height={720}
          class="aspect-[16/10] w-full object-cover sm:aspect-[21/9]"
        />

        <div
          class="absolute inset-0 bg-gradient-to-r from-black/70 via-black/35 to-transparent"
          aria-hidden="true"
        >
        </div>

        <div class="absolute inset-y-0 left-0 flex max-w-xl flex-col justify-center gap-5 p-8 sm:p-14">
          <h2
            id="akwaaba-editorial-heading"
            class="text-4xl leading-[1.05] text-white [font-family:var(--akwaaba-display)] sm:text-6xl"
          >
            {@headline}
          </h2>

          <a
            href={store_path(@store.slug, "/products")}
            class="inline-flex w-fit items-center gap-2 rounded-full bg-white px-6 py-3 text-sm font-bold text-[color:var(--akwaaba-ink)] hover:bg-[color:var(--akwaaba-amber)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 motion-safe:transition-colors"
          >
            {@cta_label}
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12l-7.5 7.5" />
            </svg>
          </a>
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
