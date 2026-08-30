defmodule EmakolaWeb.BrokenImageFallbackTest do
  @moduledoc """
  A picture that fails to load must not leave a broken frame on a storefront.

  `Emakola.Stores.ImageUrl` checks the *shape* of a URL. Whether the object is
  still behind it is something only the browser finds out — a well-formed
  `.jpg` whose file was deleted sails through every server-side guard and then
  draws the browser's torn-page icon. That is what shoppers saw in the
  featured spotlight on /stores.

  The remedy is one delegated listener in app.js. These assertions pin the
  three properties that make it work at all, each of which fails silently if
  it regresses:
  """
  use ExUnit.Case, async: true

  @app_js "assets/js/app.js"

  test "the listener exists and hides the failed image" do
    js = File.read!(@app_js)

    assert js =~ ~s(addEventListener(), "no global listener registered"
    assert js =~ "imgFailed", "the failed image is not marked"
    assert js =~ "hidden = true", "a failed image is not hidden"
  end

  test "it listens in the capture phase, because load errors do not bubble" do
    js = File.read!(@app_js)

    # From the "error" event name to the end of that addEventListener call.
    [_before, block] = String.split(js, ~s("error",), parts: 2)
    block = String.slice(block, 0, 1_200)

    assert block =~ "IMG", "the error listener does not look at images"

    # The capture flag must be `true`. Without it the listener never fires for
    # an image at all, and the bug returns looking exactly as fixed.
    assert block =~ ~r/\n\s*true,\n\s*\)/,
           "the error listener is not registered in the capture phase"
  end

  test "no inline onerror handler is used anywhere in a storefront template" do
    # script-src carries no 'unsafe-inline' (EmakolaWeb.Plugs.ContentSecurityPolicy),
    # so an inline handler is dropped without a word — it would look right in
    # review and do nothing in production.
    offenders =
      Path.wildcard("lib/emakola/themes/**/*.ex")
      |> Enum.concat(Path.wildcard("lib/emakola_web/components/*.ex"))
      # A quote or brace after the `=` — otherwise this matches the moduledoc
      # in atelier/home.ex that cites `<img onerror=...>` as escaped input.
      |> Enum.filter(&(File.read!(&1) =~ ~r/\sonerror=["{]/))

    assert offenders == [],
           "inline onerror is blocked by the CSP; found in:\n#{Enum.join(offenders, "\n")}"
  end
end
