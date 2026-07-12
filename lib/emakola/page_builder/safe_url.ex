defmodule Emakola.PageBuilder.SafeUrl do
  @moduledoc """
  Render-boundary URL allowlist for merchant-controlled block content.

  Block content is stored verbatim by both the page editor and the section
  block-bridge, so the render boundary is the one chokepoint covering every
  write path and all already-stored data (spec:
  docs/superpowers/specs/2026-07-12-block-url-sanitization-design.md).

  Mirrors the allowlist the Video block proved out in `video_embed/1`:
  absolute http(s) or site-relative. Everything else — javascript:, data:,
  protocol-relative //host, bare-relative, non-binaries — becomes `nil`,
  which HEEx renders as an omitted attribute.
  """

  @doc "Returns the URL when it is http(s) or site-relative; otherwise nil."
  def safe_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      trimmed =~ ~r{^https?://}i -> url
      String.starts_with?(trimmed, "//") -> nil
      String.starts_with?(trimmed, "/") -> url
      true -> nil
    end
  end

  def safe_url(_other), do: nil
end
