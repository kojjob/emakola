defmodule Emakola.PageBuilder.Blocks.Faq do
  @moduledoc """
  FAQ block — heading + list of accordion question/answer pairs using the
  native `<details>` element so it works without JavaScript.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `heading` | string | "Frequently asked questions" |
  | `items` | list of `%{question, answer}` maps | one empty starter row |

  Items with blank questions are filtered out at render time.
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  @impl true
  def type, do: "faq"

  @impl true
  def name, do: "FAQ"

  @impl true
  def icon, do: "help"

  @impl true
  def default_content do
    %{
      heading: "Frequently asked questions",
      items: [%{"question" => "", "answer" => ""}]
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
    <section :if={@items != []} class="py-12 sm:py-16">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          :if={@content[:heading]}
          class="text-2xl sm:text-3xl font-bold text-stone-900 mb-8 text-center"
        >
          {@content[:heading]}
        </h2>
        <div class="space-y-3">
          <details
            :for={item <- @items}
            class="bg-white rounded-xl border border-stone-200 group"
          >
            <summary class="flex items-center justify-between p-5 cursor-pointer list-none">
              <span class="text-base font-semibold text-stone-900 pr-4">
                {item_field(item, "question")}
              </span>
              <span
                class="material-symbols-outlined text-stone-500 transition-transform group-open:rotate-45"
                style="font-size: 22px;"
              >
                add
              </span>
            </summary>
            <div class="px-5 pb-5 -mt-1">
              <p class="text-sm text-stone-600 leading-relaxed">
                {item_field(item, "answer")}
              </p>
            </div>
          </details>
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
    q = item_field(item, "question")
    is_binary(q) and String.trim(q) != ""
  end

  defp valid_item?(_), do: false

  # Items come in as either string-keyed (from JSON) or atom-keyed
  # (when constructed in code). Read both transparently.
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
