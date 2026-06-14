defmodule Emakola.MoneyTest do
  use ExUnit.Case, async: true

  test "parses cedis strings to integer pesewas" do
    assert Emakola.Money.parse_price("150") == {:ok, 15_000}
    assert Emakola.Money.parse_price("25.50") == {:ok, 2550}
    assert Emakola.Money.parse_price("0") == :zero
    assert Emakola.Money.parse_price("0.00") == :zero
    assert Emakola.Money.parse_price("") == :skip
    assert Emakola.Money.parse_price("abc") == :error
  end
end
