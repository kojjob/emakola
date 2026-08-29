defmodule Emakola.GhanaDigitalAddress do
  @moduledoc """
  Pure normalization and validation of a GhanaPost GPS digital address
  (e.g. `GA-183-8164`) — the postcode-like code GhanaPost's app assigns to
  a location.

  The field is optional everywhere it appears, so blank input is always
  valid; when present, it must match `^[A-Z]{2}-\\d{3,4}-\\d{4}$` after
  normalization. `normalize/1` trims, upcases, and re-hyphenates the input
  deterministically — stripping every separator (space, hyphen, em-dash,
  ...) down to the bare letters/digits, then re-inserting hyphens after
  the 2-letter prefix and before the last 4 digits. This handles messy
  paste-ins and separator-less codes alike with one rule, and it never
  raises — malformed input just comes back as its best-effort normalized
  string; `valid?/1` is the separate check for whether that string is
  actually well-formed.

  v1 scope: no GhanaPost API lookups, no region-letter checking — just
  shape validation.
  """

  @format ~r/^[A-Z]{2}-\d{3,4}-\d{4}$/
  @non_alnum ~r/[^A-Z0-9]/

  @doc """
  Best-effort normalized form of `value`: trimmed, upcased, re-hyphenated.

  `nil` stays `nil`; everything else returns a string (possibly still
  invalid — see `valid?/1`).
  """
  def normalize(nil), do: nil

  def normalize(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.upcase()
    |> then(&Regex.replace(@non_alnum, &1, ""))
    |> rehyphenate()
  end

  @doc """
  `true` when `value` is blank (`nil`/`""`) or, once normalized, matches
  the GhanaPost digital-address shape.
  """
  def valid?(value) do
    case normalize(value) do
      blank when blank in [nil, ""] -> true
      normalized -> Regex.match?(@format, normalized)
    end
  end

  defp rehyphenate(""), do: ""

  defp rehyphenate(core) do
    {prefix, rest} = String.split_at(core, 2)
    rest_length = String.length(rest)

    cond do
      rest_length >= 4 ->
        {middle, suffix} = String.split_at(rest, rest_length - 4)
        [prefix, middle, suffix] |> Enum.reject(&(&1 == "")) |> Enum.join("-")

      rest == "" ->
        prefix

      true ->
        Enum.join([prefix, rest], "-")
    end
  end
end
