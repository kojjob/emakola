defmodule Emakola.Themes.Adwuma.Sections.Collection do
  @moduledoc """
  The product grid. Quick-add is a real button — `StoreLive` handles
  `add_to_cart` with `phx-value-product-id`.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Adwuma.Shared

  @impl true
  def key, do: "adwuma/collection"
  @impl true
  def label, do: "Featured"

  @impl true
  def settings_schema do
    [
      %{key: "heading", type: :string, label: "Heading", default: "New in"},
      %{key: "limit", type: :integer, label: "How many to show", default: 8}
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:products, Map.get(assigns, :products) || [])
      |> assign(:limit, limit(assigns))

    ~H"""
    <section
      :if={@products != []}
      class="bg-[color:var(--adw-bg)] px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20"
    >
      <div class="mx-auto max-w-6xl">
        <h2 class="text-center text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)] sm:text-3xl">
          {@settings["heading"] || "New in"}
        </h2>

        <div class="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <Shared.product_card
            :for={product <- Enum.take(@products, @limit)}
            product={product}
            store={@store}
            show_add={true}
          />
        </div>
      </div>
    </section>
    """
  end

  defp limit(assigns) do
    case assigns.settings["limit"] do
      n when is_integer(n) and n > 0 -> n
      _ -> 8
    end
  end
end
