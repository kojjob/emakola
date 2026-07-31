defmodule Emakola.GhanaDigitalAddressTest do
  @moduledoc """
  Table tests for `Emakola.GhanaDigitalAddress`: pure normalization of a
  GhanaPost GPS digital address (trim/upcase/re-hyphenate) and validation
  of the normalized form against `^[A-Z]{2}-\\d{3,4}-\\d{4}$`. Both fields
  are optional everywhere, so blank/nil must always be valid and normalize
  never raises — invalid input just comes back as its best-effort
  normalized string.
  """
  use ExUnit.Case, async: true

  alias Emakola.GhanaDigitalAddress

  describe "normalize/1" do
    test "nil stays nil" do
      assert nil == GhanaDigitalAddress.normalize(nil)
    end

    test "empty string stays empty" do
      assert "" == GhanaDigitalAddress.normalize("")
    end

    test "lowercase with space separators is upcased and re-hyphenated" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("ga 183 8164")
    end

    test "already-canonical form passes through unchanged" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("GA-183-8164")
    end

    test "lowercase separator-less (2 letters + 7 digits) is re-hyphenated" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("ga1838164")
    end

    test "uppercase separator-less (2 letters + 7 digits) is re-hyphenated" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("GA1838164")
    end

    test "em-dash separators become hyphens" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("GA—183—8164")
    end

    test "surrounding whitespace is trimmed" do
      assert "GA-183-8164" == GhanaDigitalAddress.normalize("  GA-183-8164  ")
    end

    test "separator-less 2 letters + 8 digits splits last 4 off, middle is the remaining 4" do
      assert "GA-1838-1649" == GhanaDigitalAddress.normalize("GA18381649")
    end
  end

  describe "valid?/1" do
    test "nil is valid" do
      assert GhanaDigitalAddress.valid?(nil)
    end

    test "empty string is valid" do
      assert GhanaDigitalAddress.valid?("")
    end

    test "canonical form with a 3-digit middle is valid" do
      assert GhanaDigitalAddress.valid?("GA-183-8164")
    end

    test "canonical form with a 4-digit middle is valid" do
      assert GhanaDigitalAddress.valid?("GA-1838-1649")
    end

    test "messy input that normalizes to a valid form is valid" do
      assert GhanaDigitalAddress.valid?("ga 183 8164")
    end

    test "a too-short middle (2 digits) is invalid" do
      refute GhanaDigitalAddress.valid?("GA-18-8164")
    end

    test "letters inside the digit groups are invalid" do
      refute GhanaDigitalAddress.valid?("GA-18A-8164")
    end
  end

  describe "valid?/1 — garbage input (no crash, just invalid)" do
    test "digits-only input does not raise and is invalid" do
      refute GhanaDigitalAddress.valid?("12345678")
    end

    test "a 3-letter prefix does not raise and is invalid" do
      refute GhanaDigitalAddress.valid?("GHA1838164")
    end

    test "a 1-letter prefix does not raise and is invalid" do
      refute GhanaDigitalAddress.valid?("G1838164")
    end

    test "a 2-char core (too short to hyphenate) does not raise and is invalid" do
      refute GhanaDigitalAddress.valid?("GA")
    end

    # Intentional: whitespace-only and separator-only input normalizes down to
    # "" (nothing alphanumeric survives), and the "blank never blocks" rule
    # (Global Constraints) treats that the same as nil/"" — valid, not an
    # error, so a merchant clearing the field with spaces isn't punished.
    test "whitespace-only input normalizes to blank and is valid" do
      assert GhanaDigitalAddress.valid?("   ")
    end

    test "separator-only input normalizes to blank and is valid" do
      assert GhanaDigitalAddress.valid?("---")
    end
  end
end
