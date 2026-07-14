defmodule Emakola.Themes.TermsTest do
  @moduledoc """
  What a store can truthfully say about returns and warranty.

  The rule is the same one that governs `Emakola.Themes.Delivery`: a merchant
  who has stated no term has promised nothing, so the storefront promises
  nothing on their behalf. The difference is that a returns window and a
  warranty are the merchant's own commitment — there is no zone table to derive
  them from — so they come from what the merchant typed, or they do not exist.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.Terms

  describe "returns/1" do
    test "states the merchant's own window" do
      assert Terms.returns(%{returns_window_days: 30}) == "30-day returns"
      assert Terms.returns(%{returns_window_days: 14}) == "14-day returns"
      assert Terms.returns(%{returns_window_days: 1}) == "1-day returns"
    end

    test "a merchant who stated no window makes no promise" do
      assert Terms.returns(%{returns_window_days: nil}) == nil
      assert Terms.returns(%{}) == nil
    end

    test "zero days is a stated policy, not an absent one" do
      # A merchant who sells final-sale goods has said something material, and
      # the shopper needs to read it BEFORE paying. Silence would let them
      # assume the returns window every other shop on the platform offers.
      assert Terms.returns(%{returns_window_days: 0}) == "No returns"
    end
  end

  describe "warranty/1" do
    test "states whole years in years and everything else in months" do
      assert Terms.warranty(%{warranty_months: 12}) == "1-year warranty"
      assert Terms.warranty(%{warranty_months: 24}) == "2-year warranty"
      assert Terms.warranty(%{warranty_months: 6}) == "6-month warranty"
      assert Terms.warranty(%{warranty_months: 18}) == "18-month warranty"
      assert Terms.warranty(%{warranty_months: 1}) == "1-month warranty"
    end

    test "a merchant who stated no warranty makes no promise" do
      assert Terms.warranty(%{warranty_months: nil}) == nil
      assert Terms.warranty(%{}) == nil
    end

    test "zero months is the absence of a warranty, so it says nothing" do
      # Unlike a zero-day returns window, this restricts nothing the shopper
      # would otherwise have had: no warranty is the default state of a sale.
      # Printing "No warranty" on every shop that left the field blank-but-zero
      # would be alarming copy for an ordinary transaction.
      assert Terms.warranty(%{warranty_months: 0}) == nil
    end
  end

  describe "badges/1" do
    test "collects only what the merchant actually stated" do
      assigns = %{page_content: %{returns_window_days: 30, warranty_months: 12}}
      assert Terms.badges(assigns) == ["30-day returns", "1-year warranty"]

      assigns = %{page_content: %{returns_window_days: 30, warranty_months: nil}}
      assert Terms.badges(assigns) == ["30-day returns"]
    end

    test "a store that stated nothing gets no badges" do
      assert Terms.badges(%{page_content: %{}}) == []
      assert Terms.badges(%{}) == []
    end
  end

  describe "warranty_terms/1" do
    test "returns the merchant's prose, treating blank as unstated" do
      assert Terms.warranty_terms(%{warranty_months: 12, warranty_terms: "Covers defects."}) ==
               "Covers defects."

      assert Terms.warranty_terms(%{warranty_terms: "   "}) == nil
      assert Terms.warranty_terms(%{}) == nil
    end
  end

  describe "content/1" do
    test "reads the page content the storefront LiveViews assign" do
      content = %{returns_window_days: 30}
      assert Terms.content(%{page_content: content}) == content
    end

    test "a page that never loaded content is treated as a store that stated nothing" do
      # Themes render from a shared assigns map, and not every caller (the
      # section-editor preview, a page-builder page) assigns :page_content.
      # Such a page must degrade to silence, never to a crash.
      assert Terms.content(%{}) == %{}
      assert Terms.content(%{page_content: nil}) == %{}
    end
  end
end
