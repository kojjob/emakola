defmodule Emakola.SafeAtom do
  @moduledoc """
  Safe conversion of user-supplied strings to atoms.

  `String.to_existing_atom/1` is the safe variant of `String.to_atom/1`
  (it doesn't grow the atom table), but it still raises `ArgumentError`
  on unknown input. An attacker who can control the input can therefore
  trigger 500s on every request — a denial-of-service surface.

  This module provides two safer interfaces:

    * `to_atom/2` — convert with a fallback default. Never raises.
    * `to_atom_in/3` — convert and require the result to be in an
      explicit allowlist. Never raises and never returns an atom that
      wasn't pre-approved by the caller.

  Prefer `to_atom_in/3` when the set of valid atoms is small and known
  (form fields, sort keys, etc.). Prefer `to_atom/2` when the set is
  large or dynamic (e.g. resource attribute names).
  """

  @doc """
  Convert `value` to an existing atom, returning `default` if conversion
  fails or `value` is nil.

  ## Examples

      iex> Emakola.SafeAtom.to_atom("draft", :draft)
      :draft

      iex> Emakola.SafeAtom.to_atom("not_an_atom_xyz_12345", :default)
      :default

      iex> Emakola.SafeAtom.to_atom(nil, :default)
      :default
  """
  @spec to_atom(String.t() | atom() | nil, atom()) :: atom()
  def to_atom(value, default) when is_atom(default) do
    cond do
      is_atom(value) -> value
      is_binary(value) -> safe_existing(value, default)
      true -> default
    end
  end

  @doc """
  Convert `value` to an atom, requiring the result to appear in `allowed`.
  Returns `default` if `value` is not in the allowlist.

  Strictest option — recommended for form fields and other user-facing
  inputs where you know the exact set of valid values.

  ## Examples

      iex> Emakola.SafeAtom.to_atom_in("percentage", [:percentage, :fixed], :percentage)
      :percentage

      iex> Emakola.SafeAtom.to_atom_in("evil", [:percentage, :fixed], :percentage)
      :percentage
  """
  @spec to_atom_in(String.t() | atom() | nil, [atom()], atom()) :: atom()
  def to_atom_in(value, allowed, default) when is_list(allowed) and is_atom(default) do
    candidate = to_atom(value, default)
    if candidate in allowed, do: candidate, else: default
  end

  defp safe_existing(value, default) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> default
  end
end
