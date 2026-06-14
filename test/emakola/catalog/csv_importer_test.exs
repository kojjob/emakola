defmodule Emakola.Catalog.CsvImporterTest do
  @moduledoc """
  Tests for `Emakola.Catalog.CsvImporter.parse/2` — the pure CSV parser
  used by the merchant bulk-upload flow.

  `import_rows/2` is exercised by the LiveView integration tests; here
  we cover the parsing/validation layer in isolation since it has the
  most edge cases (header-only, malformed rows, category lookup).
  """

  use ExUnit.Case, async: true

  alias Emakola.Catalog.CsvImporter

  @categories %{
    "cat-shirts" => "Shirts",
    "cat-shoes" => "Shoes"
  }

  describe "parse/2" do
    @cats %{}

    test "empty content → error" do
      assert {[], ["CSV file is empty"]} = CsvImporter.parse("", @cats)
    end

    test "header-only → error" do
      header = CsvImporter.template_header()

      assert {[], ["CSV file contains only a header row, no data"]} =
               CsvImporter.parse(header <> "\n", @cats)
    end

    test "parses a row with tags and images (semicolon-separated)" do
      csv =
        CsvImporter.template_header() <>
          "\nOkra,Fresh okra,,OKRA-1,15,10,fresh;local,okra-1.jpg;okra-2.jpg"

      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["title"] == "Okra"
      assert row["price"] == "15"
      assert row["stock_quantity"] == "10"
      assert row["tags"] == ["fresh", "local"]
      assert row["images"] == ["okra-1.jpg", "okra-2.jpg"]
    end

    test "blank tags/images → empty lists" do
      csv = CsvImporter.template_header() <> "\nYam,,,YAM,40,,,"
      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["tags"] == []
      assert row["images"] == []
    end

    test "quoted field containing a comma survives" do
      csv =
        CsvImporter.template_header() <> "\n\"Rice, 5kg\",Bag of rice,,RICE,80,5,grain,rice.jpg"

      {[row], []} = CsvImporter.parse(csv, @cats)
      assert row["title"] == "Rice, 5kg"
    end

    test "row with wrong column count → error, others still parse" do
      csv =
        CsvImporter.template_header() <> "\nBadRow,only,three\nGoodYam,desc,,YAM,40,3,tag,yam.jpg"

      {rows, errors} = CsvImporter.parse(csv, @cats)
      assert length(rows) == 1
      assert hd(rows)["title"] == "GoodYam"
      assert Enum.any?(errors, &String.contains?(&1, "Row 2"))
    end

    test "empty title → error" do
      csv = CsvImporter.template_header() <> "\n,desc,,SKU,10,1,,"
      {[], errors} = CsvImporter.parse(csv, @cats)
      assert Enum.any?(errors, &String.contains?(&1, "title is required"))
    end
  end

  describe "resolve_category_id/2" do
    test "returns the matching id for a known name" do
      assert "cat-shirts" = CsvImporter.resolve_category_id("Shirts", @categories)
      assert "cat-shirts" = CsvImporter.resolve_category_id("shirts", @categories)
      assert "cat-shoes" = CsvImporter.resolve_category_id("  SHOES  ", @categories)
    end

    test "returns nil for unknown names" do
      assert nil == CsvImporter.resolve_category_id("Hats", @categories)
    end

    test "returns nil for non-map input" do
      assert nil == CsvImporter.resolve_category_id("Shirts", nil)
    end
  end
end
