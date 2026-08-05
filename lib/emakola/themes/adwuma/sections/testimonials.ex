defmodule Emakola.Themes.Adwuma.Sections.Testimonials do
  @moduledoc """
  Real reviews only.

  The reference fills this band with invented praise from stock-photo
  strangers. A theme that ships fabricated testimonials prints a lie on every
  merchant's storefront, and it is the merchant — not us — whose customers are
  deceived by it. With no reviews, this renders nothing. An honest gap beats a
  manufactured crowd.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "adwuma/testimonials"
  @impl true
  def label, do: "Reviews"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "What buyers say"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :rated, rated(Map.get(assigns, :products) || []))

    ~H"""
    <section
      :if={@rated != []}
      class="bg-white px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20"
    >
      <div class="mx-auto max-w-5xl">
        <h2 class="text-center text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-3xl">
          {@settings["heading"] || "What buyers say"}
        </h2>

        <ul class="mt-10 grid gap-5 sm:grid-cols-3">
          <li
            :for={product <- @rated}
            class="rounded-2xl border border-[color:var(--adw-rule)] p-6"
          >
            <p class="flex items-baseline gap-2">
              <span class="text-2xl font-semibold tabular-nums text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
                {format_rating(product.avg_rating)}
              </span>
              <span class="text-sm text-[color:var(--adw-muted)]">
                from {product.review_count} {if product.review_count == 1,
                  do: "review",
                  else: "reviews"}
              </span>
            </p>
            <p class="mt-3 text-base text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
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
