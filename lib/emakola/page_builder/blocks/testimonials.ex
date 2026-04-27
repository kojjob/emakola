defmodule Emakola.PageBuilder.Blocks.Testimonials do
  @moduledoc """
  Testimonials block — 4-column grid of customer quotes with name +
  optional location + 5-star rating row.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `heading` | string | "What customers say" |
  | `items` | list of `%{name, location, quote}` maps | one empty starter row |

  Items with blank quotes or names are filtered out at render time.
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  @impl true
  def type, do: "testimonials"

  @impl true
  def name, do: "Testimonials"

  @impl true
  def icon, do: "format_quote"

  @impl true
  def default_content do
    %{
      heading: "What customers say",
      items: [%{"name" => "", "location" => "", "quote" => ""}]
    }
  end

  @impl true
  def render(assigns) do
    items =
      assigns.content[:items]
      |> List.wrap()
      |> Enum.filter(&valid_item?/1)

    assigns = assign(assigns, :items, items)

    ~H"""
    <section :if={@items != []} class="py-12 sm:py-16 bg-stone-50">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          :if={@content[:heading]}
          class="text-2xl sm:text-3xl font-bold text-stone-900 mb-10 text-center"
        >
          {@content[:heading]}
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div
            :for={item <- @items}
            class="bg-white rounded-xl p-6 border border-stone-200"
          >
            <div class="flex items-center gap-1 mb-3">
              <span :for={_ <- 1..5} class="text-amber-500" style="font-size: 14px;">★</span>
            </div>
            <p class="text-sm text-stone-700 leading-relaxed mb-4 line-clamp-5">
              "{item_field(item, "quote")}"
            </p>
            <p class="text-sm font-semibold text-stone-900">{item_field(item, "name")}</p>
            <p
              :if={present?(item_field(item, "location"))}
              class="text-xs text-stone-500"
            >
              {item_field(item, "location")}
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming with the page editor LiveView.
    </p>
    """
  end

  defp valid_item?(item) when is_map(item) do
    name = item_field(item, "name")
    quote_text = item_field(item, "quote")
    present?(name) and present?(quote_text)
  end

  defp valid_item?(_), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp item_field(item, key) when is_map(item) do
    cond do
      Map.has_key?(item, key) ->
        Map.get(item, key)

      Map.has_key?(item, String.to_existing_atom(key)) ->
        Map.get(item, String.to_existing_atom(key))

      true ->
        nil
    end
  rescue
    ArgumentError -> Map.get(item, key)
  end
end
