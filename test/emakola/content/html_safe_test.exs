defmodule Emakola.Content.HtmlSafeTest do
  use ExUnit.Case, async: true

  alias Emakola.Content.HtmlSafe

  describe "sanitize/1" do
    test "returns empty safe tuple for nil" do
      assert HtmlSafe.sanitize(nil) == {:safe, ""}
    end

    test "wraps clean HTML in a Phoenix.HTML.safe tuple" do
      assert {:safe, html} = HtmlSafe.sanitize("<p>Hello <strong>world</strong></p>")
      assert html =~ "<p>Hello <strong>world</strong></p>"
    end

    test "strips <script> tags (executable element gone; inner text becomes plain text)" do
      {:safe, html} = HtmlSafe.sanitize(~s|<p>safe</p><script>alert('xss')</script>|)
      refute html =~ "<script"
      assert html =~ "<p>safe</p>"
    end

    test "strips inline event handlers" do
      {:safe, html} = HtmlSafe.sanitize(~s|<a href="/" onclick="alert(1)">click</a>|)
      refute html =~ "onclick"
      assert html =~ "<a"
    end

    test "strips javascript: URIs in href" do
      {:safe, html} = HtmlSafe.sanitize(~s|<a href="javascript:alert(1)">x</a>|)
      refute html =~ "javascript:"
    end

    test "strips <iframe>" do
      {:safe, html} = HtmlSafe.sanitize(~s|<p>ok</p><iframe src="evil.com"></iframe>|)
      refute html =~ "<iframe"
      assert html =~ "<p>ok</p>"
    end

    test "preserves common formatting tags" do
      input = """
      <h2>Heading</h2>
      <p>Paragraph with <em>emphasis</em> and <strong>bold</strong>.</p>
      <ul><li>One</li><li>Two</li></ul>
      <blockquote>Quote</blockquote>
      """

      {:safe, html} = HtmlSafe.sanitize(input)

      for tag <- ~w(h2 p em strong ul li blockquote) do
        assert html =~ "<#{tag}", "expected <#{tag}> to be preserved"
      end
    end
  end
end
