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
end
