defmodule Emakola.PageBuilder.SafeUrl do
  @moduledoc """
  Render-boundary URL allowlist for merchant-controlled block content.

  Block content is stored verbatim by both the page editor and the section
  block-bridge, so the render boundary is the one chokepoint covering every
  write path and all already-stored data (spec:
  docs/superpowers/specs/2026-07-12-block-url-sanitization-design.md).

  Mirrors the allowlist the Video block proved out in `video_embed/1`:
  absolute http(s) or site-relative. Everything else — javascript:, data:,
  all four protocol-relative spellings (`//`, `/\\`, `\\/`, `\\\\`) plus
  tab/LF/CR-smuggled variants, bare-relative, non-binaries — becomes `nil`,
  which HEEx renders as an omitted attribute.
  """

  @doc "Returns the URL when it is http(s) or site-relative; otherwise nil."
  def safe_url(url) when is_binary(url) do
    # WHATWG URL parsing strips ASCII tab/LF/CR from anywhere in a URL
    # before parsing, so canonicalize the same way before classifying —
    # otherwise "/\t/evil.com" smuggles past the prefix checks and the
    # browser collapses it to protocol-relative //evil.com.
    sanitized = url |> String.replace(["\t", "\n", "\r"], "") |> String.trim()

    cond do
      sanitized =~ ~r{^https?://}i ->
        sanitized

      # Browsers treat \ as / in http(s) URL parsing, so ANY pairing of
      # slash/backslash in the first two chars (//, /\, \/, \\) is
      # protocol-relative to a foreign host — reject all four spellings.
      sanitized =~ ~r{^[/\\][/\\]} ->
        nil

      String.starts_with?(sanitized, "/") ->
        sanitized

      true ->
        nil
    end
  end

  def safe_url(_other), do: nil
end
