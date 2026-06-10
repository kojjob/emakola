defmodule Emakola.Catalog.CsvImporterDbTest do
  @moduledoc """
  DB-backed tests for `Emakola.Catalog.CsvImporter.import_rows/2`.

  Regression: import ran with a nil actor and no authorize?: false, so the
  H2 policy tightening silently turned every imported row into an error.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Catalog.CsvImporter

  test "import_rows creates products and variants" do
    store = create_store!()

    rows = [
      %{
        "title" => "Shea Butter",
        "description" => "Raw and unrefined",
        "category_id" => nil,
        "tags" => "skincare",
        "sku" => "SHEA-1",
        "price" => "2500",
        "stock_quantity" => "10"
      }
    ]

    assert {1, 0, []} = CsvImporter.import_rows(rows, store.id)

    product =
      Emakola.Catalog.Product
      |> Ash.Query.filter(store_id: store.id)
      |> Ash.read_one!(authorize?: false)

    assert product.title == "Shea Butter"

    variants =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(product_id: product.id)
      |> Ash.read!(authorize?: false)

    assert [%{sku: "SHEA-1", price: 2500, stock_quantity: 10}] = variants
  end
end
