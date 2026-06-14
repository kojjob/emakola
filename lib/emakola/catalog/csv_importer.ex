defmodule Emakola.Catalog.CsvImporter do
  @moduledoc """
  Parses and imports product CSVs uploaded by merchants from
  `EmakolaWeb.Admin.ProductLive.Index`.

  ## Two-phase API

  - `parse/2` is a **pure function** — given CSV content and a categories
    map, returns `{rows, errors}`. No DB access, no side effects, easy to
    test.
  - `import_rows/2` writes to the database — creates products and a
    default variant per row, returns aggregate counts and error messages.

  ## Expected CSV format

      title,description,category,sku,price,stock_quantity,tags

  Categories are resolved by name (case-insensitive); rows with an
  unknown category get `category_id: nil` (creates an uncategorised
  product). Rows with empty title are rejected with a row-numbered
  error.
  """

  NimbleCSV.define(Emakola.Catalog.CsvParser, separator: ",", escape: "\"")

  @columns 8
  @csv_template_header "title,description,category,sku,price,stock_quantity,tags,images"

  @doc """
  Returns the canonical CSV header string for the import template.
  """
  def template_header, do: @csv_template_header

  @doc """
  Parses CSV content into product rows.

  ## Returns

      {rows, errors}

  Each row is a string-keyed map matching the `import_rows/2` input shape.
  Errors are user-readable strings prefixed with the offending row number
  (`"Row 4: title is required"`).
  """
  @spec parse(binary(), %{optional(any()) => binary()}) ::
          {list(map()), list(binary())}
  def parse(content, categories_map) when is_binary(content) do
    case String.trim(content) do
      "" ->
        {[], ["CSV file is empty"]}

      trimmed ->
        case Emakola.Catalog.CsvParser.parse_string(trimmed, skip_headers: false) do
          [_header] ->
            {[], ["CSV file contains only a header row, no data"]}

          [_header | data_rows] ->
            data_rows
            |> Enum.with_index(2)
            |> Enum.reduce({[], []}, fn {fields, row_num}, acc ->
              reduce_row(fields, row_num, acc, categories_map)
            end)
            |> finalise_parse()

          [] ->
            {[], ["CSV file is empty"]}
        end
    end
  end

  defp reduce_row(fields, row_num, {rows_acc, errors_acc}, categories_map) do
    case fields do
      [title, description, category, sku, price, stock, tags, images] ->
        if String.trim(title) == "" do
          {rows_acc, ["Row #{row_num}: title is required" | errors_acc]}
        else
          row = %{
            "title" => String.trim(title),
            "description" => description,
            "category" => category,
            "category_id" => resolve_category_id(category, categories_map),
            "sku" => String.trim(sku),
            "price" => String.trim(price),
            "stock_quantity" => String.trim(stock),
            "tags" => split_multi(tags),
            "images" => split_multi(images)
          }

          {[row | rows_acc], errors_acc}
        end

      _ ->
        {rows_acc, ["Row #{row_num}: expected #{@columns} columns" | errors_acc]}
    end
  end

  defp split_multi(value) do
    (value || "")
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp finalise_parse({rows, errors}) do
    {Enum.reverse(rows), Enum.reverse(errors)}
  end

  @doc """
  Resolves a CSV category name to a category UUID using the provided map.

  `categories_map` is `%{id => name}` (the same shape `ProductLive.Index`
  loads in mount). Match is case-insensitive after trim. Unknown
  categories return `nil` so the import can still create an uncategorised
  product.
  """
  def resolve_category_id(category_name, categories_map) when is_map(categories_map) do
    target = normalise(category_name)

    case Enum.find(categories_map, fn {_id, name} -> normalise(name) == target end) do
      {id, _name} -> id
      nil -> nil
    end
  end

  def resolve_category_id(_category_name, _categories_map), do: nil

  defp normalise(value) do
    value |> to_string() |> String.trim() |> String.downcase()
  end

  @doc """
  Writes parsed rows to the database. `image_urls` is
  `%{"filename_downcased" => %{url: String.t(), content_type: String.t()}}` —
  images already uploaded to storage by the web layer.

  Per row: create product → (if a valid price) create a priced variant with the
  inventory policy and activate → attach matched images. Returns
  `{imported_count, skipped_count, warnings}`. `imported` counts rows whose product
  was created (a row with no valid price imports as a draft with a warning);
  `skipped` counts rows whose product create failed outright.
  """
  @spec import_rows(list(map()), binary(), map()) :: {integer(), integer(), list(binary())}
  def import_rows(rows, store_id, image_urls \\ %{}) when is_list(rows) and is_binary(store_id) do
    Enum.reduce(rows, {0, 0, []}, fn row, {imported, skipped, warns} ->
      case Emakola.Catalog.create_product(build_product_attrs(row, store_id), authorize?: false) do
        {:ok, product} ->
          warns = warns ++ create_variant_and_activate(product, row, store_id)
          warns = warns ++ attach_images(product, row, store_id, image_urls)
          {imported + 1, skipped, warns}

        {:error, error} ->
          {imported, skipped + 1, warns ++ ["\"#{row["title"]}\": #{format_error(error)}"]}
      end
    end)
  end

  defp build_product_attrs(row, store_id) do
    %{
      title: row["title"],
      description: row["description"],
      category_id: row["category_id"],
      tags: row["tags"] || [],
      store_id: store_id
    }
  end

  # Creates a priced variant + activates, or warns if the price is missing/invalid.
  defp create_variant_and_activate(product, row, store_id) do
    case Emakola.Money.parse_price(row["price"]) do
      {:ok, pesewas} ->
        {track, stock} = inventory_policy(row["stock_quantity"])

        variant_attrs = %{
          product_id: product.id,
          store_id: store_id,
          price: pesewas,
          sku: blank_to_nil(row["sku"]),
          position: 0,
          track_inventory: track,
          stock_quantity: stock
        }

        case Emakola.Catalog.create_variant(variant_attrs, authorize?: false) do
          {:ok, _v} ->
            case Emakola.Catalog.activate_product(product, authorize?: false) do
              {:ok, _} ->
                []

              {:error, error} ->
                [
                  "\"#{row["title"]}\": variant created but not published — #{format_error(error)}"
                ]
            end

          {:error, error} ->
            ["\"#{row["title"]}\": variant not created — #{format_error(error)}"]
        end

      _ ->
        ["\"#{row["title"]}\": add a price to publish (imported as draft)"]
    end
  end

  # stock_quantity a positive integer → track with that count; blank/0/invalid → untracked.
  defp inventory_policy(stock_str) do
    case Integer.parse(stock_str || "") do
      {n, _} when n > 0 -> {true, n}
      _ -> {false, 0}
    end
  end

  defp attach_images(_product, %{"images" => []}, _store_id, _urls), do: []
  defp attach_images(_product, %{"images" => nil}, _store_id, _urls), do: []

  # Attaches matched images in listed order. Unmatched filenames and
  # create_image failures both warn; neither aborts the row.
  defp attach_images(product, %{"images" => filenames, "title" => title}, store_id, urls) do
    Enum.reduce(filenames, [], fn filename, warns ->
      case Map.get(urls, String.downcase(filename)) do
        %{url: url, content_type: ct} ->
          case Emakola.Catalog.create_image(
                 %{url: url, product_id: product.id, store_id: store_id, content_type: ct},
                 authorize?: false
               ) do
            {:ok, _} ->
              warns

            {:error, error} ->
              warns ++ ["\"#{title}\": image #{filename} not saved — #{format_error(error)}"]
          end

        nil ->
          warns ++ ["\"#{title}\": image #{filename} not found in your uploads"]
      end
    end)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors |> Enum.map(&Map.get(&1, :message, "invalid")) |> Enum.join(", ")
  end

  defp format_error(_), do: "could not be saved"
end
