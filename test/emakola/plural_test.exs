defmodule Emakola.PluralTest do
  @moduledoc """
  One place for "1 item" / "2 items". Four modules had grown their own private
  `plural/2`, and forty-odd templates had none — so merchants read "1 orders",
  "1 products active" and "Imported 3 product(s)", and some tests had been
  written to assert exactly that.
  """
  use ExUnit.Case, async: true

  alias Emakola.Plural

  describe "noun/2" do
    test "one keeps the singular; anything else takes the plural" do
      assert Plural.noun(1, "item") == "item"
      assert Plural.noun(0, "item") == "items"
      assert Plural.noun(2, "item") == "items"
    end

    test "regular English endings" do
      assert Plural.noun(2, "category") == "categories"
      assert Plural.noun(2, "day") == "days"
      assert Plural.noun(2, "search") == "searches"
      assert Plural.noun(2, "box") == "boxes"
      assert Plural.noun(2, "business") == "businesses"
    end

    test "irregulars that the platform actually uses" do
      assert Plural.noun(2, "person") == "people"
      assert Plural.noun(2, "child") == "children"
    end

    test "an explicit plural wins" do
      assert Plural.noun(2, "piece of cloth", "pieces of cloth") == "pieces of cloth"
      assert Plural.noun(1, "piece of cloth", "pieces of cloth") == "piece of cloth"
    end

    test "a multi-word noun pluralises its last word" do
      assert Plural.noun(2, "coupon code") == "coupon codes"
      assert Plural.noun(2, "item type") == "item types"
    end
  end

  describe "count/2" do
    test "puts the number in front" do
      assert Plural.count(1, "order") == "1 order"
      assert Plural.count(3, "order") == "3 orders"
      assert Plural.count(0, "order") == "0 orders"
    end

    test "nil counts as zero rather than crashing a template" do
      assert Plural.count(nil, "order") == "0 orders"
    end
  end
end
