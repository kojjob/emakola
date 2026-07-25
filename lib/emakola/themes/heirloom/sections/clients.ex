defmodule Emakola.Themes.Heirloom.Sections.Clients do
  @moduledoc """
  A customer's own words, beside the places that stock the store's work.

  Two halves that appear and disappear independently:

  - the quote comes from `Themes.Testimonial.list/1`, which reads only the
    store's real published reviews. There is no fallback and no default. A
    store with no reviews shows no quote, and the stars drawn are the rating
    the reviewer actually gave — `Testimonial.stars/1` has no way to be
    asked for five.
  - the stockists come from `@theme.stockists.items`, defaulting to `[]`.

  The reference filled both halves with borrowed credibility: a testimonial
  attributed to "Sarah M., Community Manager, Airbnb", logos for Airbnb,
  WeWork and Ace Hotel, and the line "More than 200 clients from all over the
  world". None of it survives. A merchant's real reviews and their real
  stockists say less, and are true.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Testimonial

  @impl true
  def key, do: "heirloom/clients"

  @impl true
  def label, do: "Reviews & stockists"

  @impl true
  def settings_schema do
    [%{key: "eyebrow", type: :string, label: "Eyebrow", default: ""}]
  end

  @impl true
  def render(assigns) do
    stockists =
      assigns.theme
      |> get_in([:stockists, :items])
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.filter(&(field(&1, "name") != ""))

    assigns =
      assigns
      |> assign(:review, assigns |> Testimonial.list() |> List.first())
      |> assign(:stockists, stockists)
      |> assign(:eyebrow, present(assigns.settings["eyebrow"]))

    ~H"""
    <section
      :if={@review || @stockists != []}
      class="bg-[color:var(--hl-bg)] pb-24 sm:pb-32"
    >
      <div class="mx-auto max-w-[1360px] px-5 sm:px-8">
        <p
          :if={@eyebrow}
          class="mb-10 text-[11px] uppercase tracking-[0.16em] text-[color:var(--hl-muted)]"
        >
          {@eyebrow}
        </p>

        <div class="grid gap-6 lg:grid-cols-2">
          <figure
            :if={@review}
            class="flex flex-col justify-between rounded-[28px] bg-white p-8 sm:p-10"
          >
            <div>
              <Testimonial.stars rating={@review.rating} class="text-[color:var(--hl-accent)]" />
              <blockquote class="mt-6 max-w-prose text-lg font-light leading-relaxed text-[color:var(--hl-ink)] [font-family:var(--hl-display)]">
                {@review.body}
              </blockquote>
            </div>
            <figcaption class="mt-8 border-t border-[color:var(--hl-border)] pt-6">
              <p class="text-base text-[color:var(--hl-ink)]">{Testimonial.name(@review)}</p>
              <p
                :if={@review.verified_purchase}
                class="mt-0.5 text-xs text-[color:var(--hl-muted)]"
              >
                Verified purchase
              </p>
            </figcaption>
          </figure>

          <div
            :if={@stockists != []}
            class="rounded-[28px] bg-white p-8 sm:p-10"
          >
            <p class="text-[11px] uppercase tracking-[0.16em] text-[color:var(--hl-muted)]">
              Stocked at
            </p>
            <ul class="mt-6 flex flex-wrap gap-x-8 gap-y-4">
              <li
                :for={stockist <- @stockists}
                class="text-lg font-light text-[color:var(--hl-ink)] [font-family:var(--hl-display)]"
              >
                {field(stockist, "name")}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp field(item, key) when is_map(item) do
    value = Map.get(item, key) || Map.get(item, safe_atom(key)) || ""
    if is_binary(value), do: String.trim(value), else: ""
  end

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present(_other), do: nil
end
