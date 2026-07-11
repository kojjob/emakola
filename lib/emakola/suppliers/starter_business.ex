defmodule Emakola.Suppliers.StarterBusiness do
  @moduledoc "Builds a bounded zero-capital starter catalog using existing authorized Earn services."

  alias Emakola.Suppliers.{ContentStudio, ListingImporter, Offers, SalesSharing}

  @max_products 5

  def build(actor, store_id, attrs) do
    niche = attrs |> value(:niche) |> to_string() |> String.trim()
    count = attrs |> value(:count) |> parse_count()

    with {:ok, offers} <- Offers.list_available(actor, store_id) do
      selected = offers |> niche_matches(niche) |> Enum.take(count)

      if selected == [] do
        {:error, :no_matching_offers}
      else
        results = Enum.map(selected, &import_bundle(actor, store_id, &1))

        listings =
          Enum.flat_map(results, fn
            {:ok, listing} -> [listing]
            _error -> []
          end)

        {:ok,
         %{
           niche: niche,
           requested: count,
           imported: length(listings),
           listing_ids: Enum.map(listings, & &1.id),
           skipped: length(results) - length(listings)
         }}
      end
    end
  end

  defp import_bundle(actor, store_id, offer) do
    with {:ok, listing} <- ListingImporter.import(actor, store_id, offer),
         {:ok, _shares} <- SalesSharing.create_kit(actor, listing),
         {:ok, _draft} <- ContentStudio.create_draft(actor, store_id, listing.id) do
      {:ok, listing}
    end
  end

  defp niche_matches(offers, ""), do: offers

  defp niche_matches(offers, niche) do
    terms = niche |> String.downcase() |> String.split(~r/\s+/u, trim: true)

    matches =
      Enum.filter(offers, fn offer ->
        searchable =
          [offer.source_product.title, offer.source_product.description]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")
          |> String.downcase()

        Enum.any?(terms, &String.contains?(searchable, &1))
      end)

    if matches == [], do: offers, else: matches
  end

  defp parse_count(value) when is_integer(value), do: value |> max(1) |> min(@max_products)

  defp parse_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {count, ""} -> parse_count(count)
      _ -> 3
    end
  end

  defp parse_count(_value), do: 3
  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key)) || ""
end
