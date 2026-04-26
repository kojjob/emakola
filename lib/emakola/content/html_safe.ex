defmodule Emakola.Content.HtmlSafe do
  @moduledoc """
  Sanitizes merchant-authored HTML (blog posts, recipe bodies) so it
  can be rendered into the storefront without XSS risk.

  Uses `HtmlSanitizeEx.basic_html/1`, which keeps formatting tags
  (a, p, h1-h6, ul, ol, li, img, strong, em, code, blockquote, br,
  hr, span) and strips script/iframe/event-handler/javascript: URI
  vectors.

  Returns a `Phoenix.HTML.safe()` tuple so HEEX templates can
  interpolate the value directly without calling `raw/1`. Sanitize
  once in `mount/3` (or another data-loading boundary) and store the
  result as an assign — never sanitize on every render.

  ## Example

      assign(socket, :safe_body, HtmlSafe.sanitize(post.body))

      # in template
      {@safe_body}
  """

  @doc """
  Sanitizes the given HTML string using the basic_html allowlist and
  returns a `Phoenix.HTML.safe()` tuple. Nil input renders as empty.
  """
  @spec sanitize(String.t() | nil) :: Phoenix.HTML.safe()
  def sanitize(nil), do: {:safe, ""}

  def sanitize(html) when is_binary(html) do
    {:safe, HtmlSanitizeEx.basic_html(html)}
  end
end
