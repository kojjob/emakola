defmodule Emakola.Suppliers.BusinessCommandTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.BusinessCommand

  test "parses bounded product, content, and sales-kit instructions" do
    assert {:ok, %{action: :import_products, count: 3}} =
             BusinessCommand.parse("Add three products")

    assert {:ok, %{action: :import_products, count: 5}} = BusinessCommand.parse("Publish 9 items")
    assert {:ok, %{action: :create_content}} = BusinessCommand.parse("Make an advert")
    assert {:ok, %{action: :create_sales_kit}} = BusinessCommand.parse("Create my sales kit")
  end

  test "rejects empty and ambiguous instructions instead of guessing" do
    assert {:error, :empty} = BusinessCommand.parse("  ")
    assert {:error, :unsupported} = BusinessCommand.parse("Make me rich tomorrow")
  end
end
