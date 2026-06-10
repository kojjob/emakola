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

  @csv_template_header "title,description,category,sku,price,stock_quantity,tags"

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
    trimmed = String.trim(content)

    cond do
      trimmed == "" ->
        {[], ["CSV file is empty"]}

      true ->
        case String.split(trimmed, ~r/\r?\n/) do
          [_header | []] ->
            {[], ["CSV file contains only a header row, no data"]}

          [_header | data_lines] ->
            data_lines
            |> Enum.with_index(2)
            |> Enum.reduce({[], []}, &reduce_row(&1, &2, categories_map))
            |> finalise_parse()
        end
    end
  end

  defp reduce_row({line, row_num}, {rows_acc, errors_acc}, categories_map) do
    fields =
      line
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    case fields do
      [title, description, category, sku, price, stock_quantity | rest] ->
        tags = Enum.join(rest, ",")

        if String.trim(title) == "" do
          {rows_acc, ["Row #{row_num}: title is required" | errors_acc]}
        else
          row = %{
            "title" => title,
            "description" => description,
            "category" => category,
            "category_id" => resolve_category_id(category, categories_map),
            "sku" => sku,
            "price" => price,
            "stock_quantity" => stock_quantity,
            "tags" => tags
          }

          {[row | rows_acc], errors_acc}
        end

      _ ->
        {rows_acc, ["Row #{row_num}: invalid format, expected at least 6 columns" | errors_acc]}
    end
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
  Writes parsed rows to the database. Each row creates a Product and a
  default Variant with the SKU/price/stock from the CSV.

  ## Returns

      {success_count, error_count, error_messages}
  """
  @spec import_rows(list(map()), binary()) :: {integer(), integer(), list(binary())}
  def import_rows(rows, store_id) when is_list(rows) and is_binary(store_id) do
    Enum.reduce(rows, {0, 0, []}, fn row, {success, errors, error_msgs} ->
      attrs = build_product_attrs(row, store_id)

      case Emakola.Catalog.create_product(attrs, authorize?: false) do
        {:ok, product} ->
          maybe_create_variant(product, row, store_id)
          {success + 1, errors, error_msgs}

        {:error, error} ->
          msg = "\"#{row["title"]}\": #{format_error(error)}"
          {success, errors + 1, [msg | error_msgs]}
      end
    end)
  end

  defp build_product_attrs(row, store_id) do
    tags =
      (row["tags"] || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      title: row["title"],
      description: row["description"],
      category_id: row["category_id"],
      tags: tags,
      store_id: store_id
    }
  end

  defp maybe_create_variant(product, row, store_id) do
    variant_attrs = %{
      product_id: product.id,
      sku: row["sku"],
      price: parse_int(row["price"]),
      stock_quantity: parse_int(row["stock_quantity"]),
      store_id: store_id
    }

    Emakola.Catalog.Variant
    |> Ash.Changeset.for_create(:create, variant_attrs)
    |> Ash.create(authorize?: false)
  rescue
    _ -> :ok
  end

  defp parse_int(value) do
    case Integer.parse(value || "0") do
      {val, _} -> val
      :error -> 0
    end
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn err -> Map.get(err, :message, inspect(err)) end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)
end
