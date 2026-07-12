defmodule Emakola.Money do
  @moduledoc "Pure money parsing/formatting at the presentation boundary (GHS ↔ pesewas)."

  @doc """
  Parses a GHS decimal string to integer pesewas.
  Returns `{:ok, pesewas}` (pesewas > 0), `:skip` (blank), `:zero` (parses to 0),
  or `:error` (non-empty unparseable).
  """
  def parse_price(value) do
    case Regex.run(~r/^\s*(\d+)(?:\.(\d{1,2}))?\s*$/, value || "") do
      [_, major] ->
        pesewas = String.to_integer(major) * 100
        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      [_, major, minor] ->
        pesewas =
          String.to_integer(major) * 100 +
            String.to_integer(String.pad_trailing(minor, 2, "0"))

        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      nil ->
        if String.trim(value || "") == "", do: :skip, else: :error
    end
  end

  @doc """
  Groups a major-unit integer with thousands separators: `4800` -> `"4,800"`.

  Every money formatter on the platform calls this. Four of them used to carry
  their own copy of the grouping and five had none at all, so the same amount
  printed three different ways: `GH₵ 4800` on a storefront, `GHS 12500.00` on
  the platform finance screen, `GH₵ 12,500.00` in the merchant's dashboard.

  ## Examples

      iex> Emakola.Money.group_thousands(4800)
      "4,800"

      iex> Emakola.Money.group_thousands(-1500)
      "-1,500"
  """
  @spec group_thousands(integer()) :: String.t()
  def group_thousands(major) when is_integer(major) do
    sign = if major < 0, do: "-", else: ""

    grouped =
      major
      |> abs()
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/\d{3}(?=\d)/, "\\0,")
      |> String.reverse()

    sign <> grouped
  end
end
