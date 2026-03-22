defmodule EmakolaWeb.Helpers.CurrencyTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Helpers.Currency

  describe "format_price/2" do
    test "formats GHS pesewas correctly" do
      assert Currency.format_price(15000) == "GH\u20B5 150.00"
    end

    test "formats zero amount" do
      assert Currency.format_price(0) == "GH\u20B5 0.00"
    end

    test "formats amount with minor units" do
      assert Currency.format_price(5050) == "GH\u20B5 50.50"
    end

    test "formats single pesewa" do
      assert Currency.format_price(1) == "GH\u20B5 0.01"
    end

    test "formats NGN kobo" do
      assert Currency.format_price(50000, "NGN") == "\u20A6 500.00"
    end

    test "formats USD cents" do
      assert Currency.format_price(1999, "USD") == "$ 19.99"
    end

    test "pads minor units with leading zero" do
      assert Currency.format_price(105) == "GH\u20B5 1.05"
    end
  end

  describe "format_price_range/3" do
    test "shows single price when min equals max" do
      assert Currency.format_price_range(5000, 5000, "GHS") == "GH\u20B5 50.00"
    end

    test "shows range when min differs from max" do
      assert Currency.format_price_range(1000, 2500, "GHS") ==
               "GH\u20B5 10.00 - GH\u20B5 25.00"
    end

    test "handles nil min" do
      assert Currency.format_price_range(nil, 5000, "GHS") == "GH\u20B5 50.00"
    end

    test "handles nil max" do
      assert Currency.format_price_range(5000, nil, "GHS") == "GH\u20B5 50.00"
    end

    test "handles both nil" do
      assert Currency.format_price_range(nil, nil, "GHS") == "Price not set"
    end
  end

  describe "currency_symbol/1" do
    test "returns GHS symbol" do
      assert Currency.currency_symbol("GHS") == "GH\u20B5"
    end

    test "returns NGN symbol" do
      assert Currency.currency_symbol("NGN") == "\u20A6"
    end

    test "returns USD symbol" do
      assert Currency.currency_symbol("USD") == "$"
    end

    test "returns empty for unknown currency" do
      assert Currency.currency_symbol("XYZ") == ""
    end
  end
end
