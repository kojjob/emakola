defmodule Emakola.SafeAtomTest do
  @moduledoc """
  Tests for `Emakola.SafeAtom`, the atom-exhaustion / 500-DoS defense
  documented in CLAUDE.md. The critical property: it NEVER raises on
  arbitrary user input.
  """
  use ExUnit.Case, async: true

  doctest Emakola.SafeAtom

  describe "to_atom/2" do
    test "returns the existing atom for a known string" do
      assert Emakola.SafeAtom.to_atom("featured", :featured) == :featured
    end

    test "passes atoms through unchanged" do
      assert Emakola.SafeAtom.to_atom(:newest, :featured) == :newest
    end

    test "returns the default for nil" do
      assert Emakola.SafeAtom.to_atom(nil, :featured) == :featured
    end

    test "returns the default (does NOT raise) for an unknown string" do
      # A string that maps to no existing atom would raise with
      # String.to_existing_atom/1 — the DoS vector this guards against.
      assert Emakola.SafeAtom.to_atom("definitely_not_an_atom_9f8a7b6c5d", :featured) == :featured
    end

    test "returns the default for non-binary, non-atom input" do
      assert Emakola.SafeAtom.to_atom(123, :featured) == :featured
      assert Emakola.SafeAtom.to_atom(%{}, :featured) == :featured
    end
  end

  describe "to_atom_in/3" do
    @allowed [:featured, :newest, :popular, :name]

    test "returns the value when it is in the allowlist" do
      assert Emakola.SafeAtom.to_atom_in("newest", @allowed, :featured) == :newest
    end

    test "returns the default when the value is a real atom but NOT allowlisted" do
      # :length is an existing atom (so to_atom would return it), but it
      # must not leak through because it's not in the allowlist.
      assert Emakola.SafeAtom.to_atom_in("length", @allowed, :featured) == :featured
    end

    test "returns the default (does NOT raise) for an unknown string" do
      assert Emakola.SafeAtom.to_atom_in("'; DROP TABLE--", @allowed, :featured) == :featured
    end

    test "returns the default for nil" do
      assert Emakola.SafeAtom.to_atom_in(nil, @allowed, :featured) == :featured
    end
  end
end
