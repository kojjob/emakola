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

  describe "group_thousands/1" do
    test "groups the major unit so a price can be read at a glance" do
      assert Emakola.Money.group_thousands(0) == "0"
      assert Emakola.Money.group_thousands(7) == "7"
      assert Emakola.Money.group_thousands(999) == "999"
      assert Emakola.Money.group_thousands(1000) == "1,000"
      assert Emakola.Money.group_thousands(4800) == "4,800"
      assert Emakola.Money.group_thousands(12_500) == "12,500"
      assert Emakola.Money.group_thousands(999_999) == "999,999"
      assert Emakola.Money.group_thousands(1_234_567) == "1,234,567"
    end

    test "the separator never lands next to the minus sign" do
      assert Emakola.Money.group_thousands(-7) == "-7"
      assert Emakola.Money.group_thousands(-1500) == "-1,500"
      assert Emakola.Money.group_thousands(-1_234_567) == "-1,234,567"
    end
  end
end
