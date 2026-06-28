defmodule Emakola.Themes.Atelier.HomeTest do
  use ExUnit.Case, async: true

  alias Emakola.Themes.Atelier.Home

  describe "hero_title_html/1" do
    test "escapes merchant markup but preserves intended line breaks" do
      out =
        "<img src=x onerror=alert(document.cookie)>\nLine two"
        |> Home.hero_title_html()
        |> Phoenix.HTML.safe_to_string()

      # The merchant-supplied payload must be neutralised — the tag is escaped
      # to inert text (`&lt;img...&gt;`), so no live <img> element is rendered.
      refute out =~ "<img"
      assert out =~ "&lt;img"

      # The only <br> is the one we inject for the intended newline.
      assert out =~ "Line two"
      assert out =~ "<br>"
    end
  end
end
