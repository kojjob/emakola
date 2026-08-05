defmodule EmakolaWeb.Admin.SupplyNetworkLive.Commands do
  @moduledoc "Executes previewed supply-network business commands within an actor/store boundary."

  alias Emakola.Suppliers.{ContentStudio, ListingImporter, Offers, SalesSharing}

  def execute(_actor, _store_id, _listings, nil),
    do: {:error, "Preview an instruction before confirming it."}

  def execute(actor, store_id, _listings, %{action: :import_products, count: count}) do
    offers = Offers.list_available(actor, store_id) |> result_rows() |> Enum.take(count)

    imported =
      Enum.count(offers, fn offer ->
        match?({:ok, _listing}, ListingImporter.import(actor, store_id, offer))
      end)

    if imported > 0,
      do: {:ok, "Added #{imported} partner product#{if imported == 1, do: "", else: "s"}."},
      else: {:error, "No eligible new partner products are available."}
  end

  def execute(actor, store_id, listings, %{action: :create_content}) do
    case List.first(listings) do
      nil ->
        {:error, "Add a partner product before creating content."}

      listing ->
        case ContentStudio.create_draft(actor, store_id, listing.id) do
          {:ok, _draft} -> {:ok, "Fact-grounded content draft created for review."}
          _error -> {:error, "The content draft could not be created."}
        end
    end
  end

  def execute(actor, _store_id, listings, %{action: :create_sales_kit}) do
    case List.first(listings) do
      nil ->
        {:error, "Add a partner product before creating a Sales Kit."}

      listing ->
        case SalesSharing.create_kit(actor, listing) do
          {:ok, _shares} -> {:ok, "Tracked Sales Kit links created."}
          _error -> {:error, "The Sales Kit could not be created."}
        end
    end
  end

  defp result_rows({:ok, rows}), do: rows
  defp result_rows(_error), do: []
end
