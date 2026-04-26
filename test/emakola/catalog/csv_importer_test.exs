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

  defp csv(rows) do
    [CsvImporter.template_header() | rows] |> Enum.join("\n")
  end

  describe "parse/2" do
    test "returns empty rows + error for empty content" do
      assert {[], ["CSV file is empty"]} = CsvImporter.parse("", @categories)
    end

    test "returns empty rows + error for header-only file" do
      content = CsvImporter.template_header()

      assert {[], ["CSV file contains only a header row, no data"]} =
               CsvImporter.parse(content, @categories)
    end

    test "parses a single valid row" do
      content = csv(["Tee,A nice tee,Shirts,SKU-1,5000,10,casual"])

      assert {[row], []} = CsvImporter.parse(content, @categories)
      assert row["title"] == "Tee"
      assert row["description"] == "A nice tee"
      assert row["category_id"] == "cat-shirts"
      assert row["sku"] == "SKU-1"
      assert row["price"] == "5000"
      assert row["stock_quantity"] == "10"
      assert row["tags"] == "casual"
    end

    test "parses multiple rows" do
      content =
        csv([
          "Tee,Cotton,Shirts,SKU-1,5000,10,casual",
          "Sneaker,Leather,Shoes,SKU-2,12000,5,sport"
        ])

      assert {rows, []} = CsvImporter.parse(content, @categories)
      assert length(rows) == 2
    end

    test "rejects rows with empty title" do
      content =
        csv([
          ",no title here,Shirts,SKU-X,1000,1,",
          "Sneaker,Leather,Shoes,SKU-2,12000,5,sport"
        ])

      assert {[row], errors} = CsvImporter.parse(content, @categories)
      assert row["title"] == "Sneaker"
      assert errors == ["Row 2: title is required"]
    end

    test "rejects malformed rows (fewer than 6 columns)" do
      content = csv(["incomplete,row"])

      assert {[], errors} = CsvImporter.parse(content, @categories)
      assert errors == ["Row 2: invalid format, expected at least 6 columns"]
    end

    test "row numbering accounts for the header row (data starts at row 2)" do
      # Two malformed rows so we can verify they're labelled Row 2 and Row 3.
      content = csv(["bad1,short", "bad2,also-short"])

      assert {[], errors} = CsvImporter.parse(content, @categories)
      assert Enum.any?(errors, &String.contains?(&1, "Row 2"))
      assert Enum.any?(errors, &String.contains?(&1, "Row 3"))
    end

    test "joins extra columns into tags field" do
      # tags can contain commas — anything past the 6th column is joined
      content = csv(["Tee,desc,Shirts,SKU-1,5000,10,red,blue,green"])

      assert {[row], []} = CsvImporter.parse(content, @categories)
      assert row["tags"] == "red,blue,green"
    end

    test "returns nil category_id for unknown category" do
      content = csv(["Mystery,desc,UnknownCategory,SKU-1,5000,10,"])

      assert {[row], []} = CsvImporter.parse(content, @categories)
      assert row["category_id"] == nil
      assert row["category"] == "UnknownCategory"
    end

    test "category lookup is case-insensitive and trims whitespace" do
      content = csv(["Tee,desc,  shirts  ,SKU-1,5000,10,"])

      assert {[row], []} = CsvImporter.parse(content, @categories)
      assert row["category_id"] == "cat-shirts"
    end

    test "handles CRLF line endings" do
      content =
        [CsvImporter.template_header(), "Tee,desc,Shirts,SKU-1,5000,10,"]
        |> Enum.join("\r\n")

      assert {[row], []} = CsvImporter.parse(content, @categories)
      assert row["title"] == "Tee"
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
