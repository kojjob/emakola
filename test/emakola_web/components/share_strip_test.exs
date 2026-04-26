defmodule EmakolaWeb.StorefrontComponents.ShareStripTest do
  @moduledoc """
  Pins the contract for `<.share_strip>`:

    * Renders WhatsApp / X / Facebook / Copy-link buttons
    * Uses correct intent URLs for each platform
    * URL-encodes the title and URL parameters
    * Renders headline only when provided
    * Always renders (no conditional on store data — these buttons share
      the page itself, not link to merchant socials)
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "share_strip/1" do
    test "renders all four share buttons" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://example.com/s/test/products/widget" title="Cool Widget" />
        """)

      assert html =~ "WhatsApp"
      assert html =~ "X"
      assert html =~ "Facebook"
      assert html =~ "Copy link"
    end

    test "WhatsApp button uses wa.me intent with title + url encoded" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://example.com/p/widget" title="Cool Widget" />
        """)

      assert html =~ "wa.me/?text="
      # Encoded "Cool Widget — https://example.com/p/widget"
      assert html =~ "Cool+Widget"
      assert html =~ "https%3A%2F%2Fexample.com%2Fp%2Fwidget"
    end

    test "X button uses twitter intent" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://example.com/p/x" title="X Item" />
        """)

      assert html =~ "twitter.com/intent/tweet"
      assert html =~ "X+Item"
    end

    test "Facebook button uses sharer.php" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://example.com/p/fb" title="FB Item" />
        """)

      assert html =~ "facebook.com/sharer/sharer.php"
      assert html =~ "https%3A%2F%2Fexample.com%2Fp%2Ffb"
    end

    test "Copy-link button is a button (not a link) using JS dispatch" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://example.com/p/widget" title="Widget" />
        """)

      assert html =~ ~s(type="button")
      assert html =~ "copy-to-clipboard"
    end

    test "renders headline when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://e.x/p" title="P" headline="Spread the word" />
        """)

      assert html =~ "Spread the word"
    end

    test "omits headline element when not provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://e.x/p" title="P" />
        """)

      refute html =~ "Spread the word"
    end

    test "merges caller-provided class on the wrapper" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.share_strip url="https://e.x" title="t" class="mt-8" />
        """)

      assert html =~ "mt-8"
    end
  end

  describe "url helpers" do
    test "whatsapp_share_url builds correct intent" do
      url = whatsapp_share_url("https://e.x/p", "Hello world")
      assert url =~ "wa.me/?text="
      assert url =~ "Hello+world"
    end

    test "x_share_url passes both text and url" do
      url = x_share_url("https://e.x/p", "Tweet me")
      assert url =~ "text=Tweet+me"
      assert url =~ "url=https%3A%2F%2Fe.x%2Fp"
    end

    test "facebook_share_url URL-encodes the page url" do
      url = facebook_share_url("https://e.x/p?a=1")
      assert url == "https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fe.x%2Fp%3Fa%3D1"
    end
  end
end
