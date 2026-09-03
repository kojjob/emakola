defmodule Emakola.Themes.Layout do
  @moduledoc """
  What a storefront home shows for the catalogue it actually has. Shared by
  every theme; each theme's sections consult it.

  Most live shops carry one or two products, so the page must look finished
  at one product and grow from there, never showing the same product twice
  and never speaking for a merchant who wrote nothing:

    * zero products — the grid's setting-up state; nothing else that needs stock
    * one product — the featured card carries it alone; no grid repeats it
    * two or three — featured takes the first, the grid takes the rest
    * four or more — the category strip and the newsletter join the page
    * about — only when the merchant wrote a description

  `plan/1` is pure and cheap; sections call `of/1`, which reuses a plan the
  home chrome already computed. When a section is rendered on its own without
  a `products` list at all, nothing is known about the catalogue and nothing
  is hidden.
  """

  @full_stall 4

  @type plan :: %{
          count: non_neg_integer() | nil,
          featured: map() | nil,
          grid_products: [map()],
          show_grid?: boolean(),
          show_categories?: boolean(),
          show_newsletter?: boolean(),
          show_about?: boolean()
        }

  @spec of(map()) :: plan()
  def of(assigns), do: Map.get(assigns, :layout) || plan(assigns)

  @spec plan(map()) :: plan()
  def plan(assigns) do
    categories = Map.get(assigns, :categories) || []
    description = assigns |> Map.get(:store, %{}) |> Map.get(:description)

    case Map.get(assigns, :products) do
      products when is_list(products) -> plan_for(products, categories, description)
      _unknown -> unknown_catalogue(categories, description)
    end
  end

  defp plan_for(products, categories, description) do
    count = length(products)
    {featured, rest} = split_featured(products)

    %{
      count: count,
      featured: featured,
      grid_products: if(count >= 2, do: rest, else: []),
      show_grid?: count == 0 or count >= 2,
      show_categories?: categories != [] and count >= @full_stall,
      show_newsletter?: count >= @full_stall,
      show_about?: present?(description)
    }
  end

  defp unknown_catalogue(categories, description) do
    %{
      count: nil,
      featured: nil,
      grid_products: [],
      show_grid?: true,
      show_categories?: categories != [],
      show_newsletter?: true,
      show_about?: present?(description)
    }
  end

  defp split_featured([]), do: {nil, []}
  defp split_featured([featured | rest]), do: {featured, rest}

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
