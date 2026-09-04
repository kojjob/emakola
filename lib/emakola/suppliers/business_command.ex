defmodule Emakola.Suppliers.BusinessCommand do
  @moduledoc "Parses a small, explicit set of preview-first text or transcribed voice commands."

  @max_products 5

  def parse(text) when is_binary(text) do
    normalized = text |> String.trim() |> String.downcase()

    cond do
      normalized == "" ->
        {:error, :empty}

      Regex.match?(~r/\b(add|list|publish)\b.*\b(product|products|item|items)\b/u, normalized) ->
        count = normalized |> requested_count() |> min(@max_products)

        {:ok,
         %{
           action: :import_products,
           count: count,
           original: text,
           preview:
             "Add up to #{count} top-ranked partner #{Emakola.Plural.noun(count, "product")} to your store."
         }}

      Regex.match?(~r/\b(content|caption|advert|ad)\b/u, normalized) ->
        {:ok,
         %{
           action: :create_content,
           count: 1,
           original: text,
           preview: "Create one fact-grounded content draft for your first partner product."
         }}

      Regex.match?(~r/\b(sales kit|share link|selling link)\b/u, normalized) ->
        {:ok,
         %{
           action: :create_sales_kit,
           count: 1,
           original: text,
           preview: "Create tracked Sales Kit links for your first partner product."
         }}

      true ->
        {:error, :unsupported}
    end
  end

  def parse(_text), do: {:error, :empty}

  defp requested_count(text) do
    case Regex.run(~r/\b([1-9]|one|two|three|four|five|six|seven|eight|nine|ten)\b/u, text) do
      [_, number] -> number(number)
      _ -> 1
    end
  end

  defp number("one"), do: 1
  defp number("two"), do: 2
  defp number("three"), do: 3
  defp number("four"), do: 4
  defp number("five"), do: 5
  defp number("six"), do: 6
  defp number("seven"), do: 7
  defp number("eight"), do: 8
  defp number("nine"), do: 9
  defp number("ten"), do: 10
  defp number(number), do: String.to_integer(number)
end
