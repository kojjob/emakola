defmodule Emakola.Themes.LayoutTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.Layout

  defp product(id) do
    %{id: id, title: "Product #{id}", slug: "p#{id}", min_price: 100, max_price: 100, images: []}
  end

  defp plan(products, opts \\ []) do
    Layout.plan(%{
      products: products,
      categories: Keyword.get(opts, :categories, []),
      store: %{name: "Stall", description: Keyword.get(opts, :description)}
    })
  end

  describe "an empty stall" do
    test "keeps the grid for its setting-up state and hides everything that needs products" do
      plan = plan([])

      assert plan.featured == nil
      assert plan.grid_products == []
      assert plan.show_grid?
      refute plan.show_categories?
      refute plan.show_newsletter?
    end
  end

  describe "one product" do
    test "the featured card carries it alone, and no grid repeats it" do
      plan = plan([product(1)])

      assert plan.featured.id == 1
      assert plan.grid_products == []
      refute plan.show_grid?
      refute plan.show_categories?
      refute plan.show_newsletter?
    end
  end

  describe "two or three products" do
    test "featured takes the first, the grid takes the rest, nothing appears twice" do
      plan = plan([product(1), product(2), product(3)], categories: [%{id: "c1"}])

      assert plan.featured.id == 1
      assert Enum.map(plan.grid_products, & &1.id) == [2, 3]
      assert plan.show_grid?
      refute plan.show_categories?
      refute plan.show_newsletter?
    end
  end

  describe "a full stall" do
    test "four or more products unlock the category strip and the newsletter" do
      plan = plan(Enum.map(1..4, &product/1), categories: [%{id: "c1"}])

      assert plan.show_categories?
      assert plan.show_newsletter?
      assert length(plan.grid_products) == 3
    end

    test "the category strip still hides when the store has no categories" do
      refute plan(Enum.map(1..5, &product/1)).show_categories?
    end
  end

  describe "about" do
    test "shows only when the merchant wrote a description" do
      refute plan([]).show_about?
      refute plan([], description: "   ").show_about?
      assert plan([], description: "Family stall since 1998.").show_about?
    end
  end
end
