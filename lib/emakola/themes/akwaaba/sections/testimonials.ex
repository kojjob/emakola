defmodule Emakola.Themes.Akwaaba.Sections.Testimonials do
  @moduledoc """
  Akwaaba testimonials — **real reviews only**.

  The reference fills this band with invented praise from stock-photo strangers.
  A theme that ships fabricated testimonials prints a lie on every merchant's
  storefront, and it is the merchant — not us — whose customers are deceived by
  it. So this section renders from the store's actual reviews, and when a store
  has none it does not render at all. An honest gap beats a manufactured crowd.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "akwaaba/testimonials"
  @impl true
  def label, do: "Reviews"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "What shoppers say"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :rated, rated(assigns.products))

    ~H"""
    <section
      :if={@rated != []}
      class="bg-white px-5 py-12 [font-family:var(--akwaaba-body)] sm:px-10 sm:py-16"
      aria-labelledby="akwaaba-testimonials-heading"
    >
      <div class="mx-auto max-w-[1320px]">
        <h2
          id="akwaaba-testimonials-heading"
          class="text-3xl text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)] sm:text-4xl"
        >
          {@settings["heading"] || "What shoppers say"}
        </h2>

        <ul class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <li
            :for={product <- @rated}
            class="rounded-3xl border border-zinc-200 p-6"
          >
            <p class="flex items-baseline gap-2">
              <span class="text-2xl font-semibold tabular-nums text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
                {format_rating(product.avg_rating)}
              </span>
              <span class="text-sm text-zinc-500">
                from {product.review_count} {if product.review_count == 1,
                  do: "review",
                  else: "reviews"}
              </span>
            </p>
            <p class="mt-3 text-base text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
              {product.title}
            </p>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp rated(products) do
    products
    |> Enum.filter(fn p ->
      is_number(Map.get(p, :avg_rating)) and (Map.get(p, :review_count) || 0) > 0
    end)
    |> Enum.sort_by(& &1.review_count, :desc)
    |> Enum.take(3)
  end

  defp format_rating(rating) when is_float(rating),
    do: :erlang.float_to_binary(rating, decimals: 1)

  defp format_rating(rating) when is_integer(rating),
    do: :erlang.float_to_binary(rating / 1, decimals: 1)
end
