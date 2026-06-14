defmodule Emakola.Catalog.CsvImporterDbTest do
  @moduledoc """
  DB-backed tests for `Emakola.Catalog.CsvImporter.import_rows/3`.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Catalog.CsvImporter

  require Ash.Query

  defp row(overrides) do
    Map.merge(
      %{
        "title" => "Okra",
        "description" => "Fresh",
        "category" => "",
        "category_id" => nil,
        "sku" => "OKRA-1",
        "price" => "15",
        "stock_quantity" => "",
        "tags" => [],
        "images" => []
      },
      overrides
    )
  end

  defp variant_of(product) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(product_id == ^product.id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp product_named(store, title) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(store_id == ^store.id and title == ^title)
    |> Ash.read_one!(authorize?: false, load: [:images])
  end

  test "imports an active product with a priced untracked variant (no stock)" do
    store = create_store!()
    assert {1, 0, []} = CsvImporter.import_rows([row(%{})], store.id, %{})

    p = product_named(store, "Okra")
    assert p.status == :active
    v = variant_of(p)
    assert v.price == 1500
    assert v.track_inventory == false
  end

  test "price '150' becomes 15000 pesewas (cedis bug fix)" do
    store = create_store!()

    CsvImporter.import_rows(
      [row(%{"title" => "Rice", "sku" => "RICE", "price" => "150"})],
      store.id,
      %{}
    )

    assert variant_of(product_named(store, "Rice")).price == 15_000
  end

  test "positive stock_quantity → track_inventory true with that count" do
    store = create_store!()

    CsvImporter.import_rows(
      [row(%{"title" => "Yam", "sku" => "YAM", "stock_quantity" => "10"})],
      store.id,
      %{}
    )

    v = variant_of(product_named(store, "Yam"))
    assert v.track_inventory == true
    assert v.stock_quantity == 10
  end

  test "blank price → draft, no variant, warning" do
    store = create_store!()

    {imported, _skipped, warnings} =
      CsvImporter.import_rows(
        [row(%{"title" => "NoPrice", "sku" => "NP", "price" => ""})],
        store.id,
        %{}
      )

    assert imported == 1
    assert product_named(store, "NoPrice").status == :draft
    assert is_nil(variant_of(product_named(store, "NoPrice")))
    assert Enum.any?(warnings, &String.contains?(&1, "add a price"))
  end

  test "matched image filename attaches; unmatched warns but still imports" do
    store = create_store!()

    image_urls = %{
      "okra-1.jpg" => %{url: "https://s3.example.com/okra-1.jpg", content_type: "image/png"}
    }

    {1, 0, warnings} =
      CsvImporter.import_rows(
        [row(%{"images" => ["okra-1.jpg", "missing.jpg"]})],
        store.id,
        image_urls
      )

    p = product_named(store, "Okra")
    assert length(p.images) == 1
    assert hd(p.images).url == "https://s3.example.com/okra-1.jpg"
    assert Enum.any?(warnings, &String.contains?(&1, "missing.jpg"))
  end
end
