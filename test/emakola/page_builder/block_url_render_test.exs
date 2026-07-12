defmodule Emakola.PageBuilder.BlockUrlRenderTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  @evil "javascript:alert(1)"

  defp render_block(type, content) do
    Emakola.PageBuilder.render_block(
      %{"type" => type, "content" => content},
      %{
        __changed__: nil,
        store: %{id: Ash.UUID.generate(), name: "Test Store", slug: "test-store"},
        products: [],
        categories: []
      }
    )
    |> rendered_to_string()
  end

  test "hero_banner neutralizes all three URL sinks, fallbacks preserved" do
    html =
      render_block("hero_banner", %{
        "headline" => "T",
        "image_url" => @evil,
        "cta_label" => "Shop",
        "cta_url" => @evil,
        "secondary_cta_label" => "More",
        "secondary_cta_url" => "data:text/html,x"
      })

    refute html =~ "javascript:"
    refute html =~ "data:text/html"
    assert html =~ ~s(href="/products")
  end

  test "image_banner neutralizes link and image URLs" do
    html =
      render_block("image_banner", %{"image_url" => @evil, "link_url" => @evil})

    refute html =~ "javascript:"
  end

  test "split neutralizes image and CTA URLs, fallback preserved" do
    html =
      render_block("split", %{
        "image_url" => @evil,
        "cta_label" => "Go",
        "cta_url" => @evil
      })

    refute html =~ "javascript:"
    assert html =~ ~s(href="/products")
  end

  test "audio neutralizes the src" do
    html = render_block("audio", %{"audio_url" => @evil, "title" => "Track"})
    refute html =~ "javascript:"
  end

  test "video neutralizes the poster" do
    html =
      render_block("video", %{
        "video_url" => "https://cdn.example.com/video.mp4",
        "poster_url" => @evil
      })

    refute html =~ "javascript:"
    assert html =~ ~s(src="https://cdn.example.com/video.mp4")
  end

  test "video rejects backslash protocol-relative direct-file URLs" do
    # /\evil.com parses protocol-relative in browsers; the block must not
    # render a <video src> for it (video_embed returns :invalid → no section).
    html = render_block("video", %{"video_url" => "/\\evil.com/x.mp4"})
    refute html =~ "evil.com"
  end

  test "legitimate URLs render unchanged" do
    html =
      render_block("hero_banner", %{
        "headline" => "T",
        "image_url" => "https://cdn.example.com/hero.jpg",
        "cta_label" => "Shop",
        "cta_url" => "/s/test-store/products"
      })

    assert html =~ ~s(src="https://cdn.example.com/hero.jpg")
    assert html =~ ~s(href="/s/test-store/products")
  end
end
