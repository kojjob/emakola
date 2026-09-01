defmodule Emakola.Plural do
  @moduledoc """
  "1 order", "2 orders" — in one place.

  Four modules had grown their own private `plural/2`, and forty-odd templates
  had none, so merchants read "1 orders", "1 products active" and "Imported 3
  product(s)". For an audience that often reads with effort, "(s)" is not a
  plural, it is a puzzle.

  English rules only, and only the ones this codebase needs. If the UI is ever
  translated, the calls here are the sites to move to `ngettext/3`.
  """

  @irregular %{"person" => "people", "child" => "children"}

  @doc """
  The noun alone: `noun(1, "item")` → `"item"`, `noun(3, "item")` → `"items"`.

  Pass the plural explicitly when the rule would get it wrong. A multi-word
  noun pluralises its last word (`"coupon code"` → `"coupon codes"`).
  """
  @spec noun(integer() | nil, String.t(), String.t() | nil) :: String.t()
  def noun(count, singular, plural \\ nil)
  def noun(1, singular, _plural), do: singular
  def noun(_count, _singular, plural) when is_binary(plural), do: plural
  def noun(_count, singular, nil), do: pluralize(singular)

  @doc ~S"""
  The number and the noun: `count(1, "order")` → `"1 order"`. A nil count
  reads as zero rather than crashing a template.
  """
  @spec count(integer() | nil, String.t(), String.t() | nil) :: String.t()
  def count(count, singular, plural \\ nil) do
    n = count || 0
    "#{n} #{noun(n, singular, plural)}"
  end

  defp pluralize(singular) do
    case String.split(singular, " ") do
      [word] -> pluralize_word(word)
      words -> words |> List.update_at(-1, &pluralize_word/1) |> Enum.join(" ")
    end
  end

  defp pluralize_word(word) do
    cond do
      Map.has_key?(@irregular, word) -> @irregular[word]
      String.match?(word, ~r/[^aeiou]y$/) -> String.replace_suffix(word, "y", "ies")
      String.match?(word, ~r/(s|x|z|ch|sh)$/) -> word <> "es"
      true -> word <> "s"
    end
  end
end
