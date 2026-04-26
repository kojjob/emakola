defmodule Emakola.PageBuilder.Blocks.VideoTest do
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder.Blocks.Video

  describe "video_embed/1" do
    test "recognizes a youtube watch URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               Video.video_embed("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    test "recognizes a youtu.be short URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               Video.video_embed("https://youtu.be/dQw4w9WgXcQ")
    end

    test "recognizes a youtube embed URL already" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               Video.video_embed("https://www.youtube.com/embed/dQw4w9WgXcQ")
    end

    test "recognizes a vimeo URL" do
      assert {:vimeo, "https://player.vimeo.com/video/123456789"} =
               Video.video_embed("https://vimeo.com/123456789")
    end

    test "treats other https URLs as direct file URLs" do
      assert {:file, "https://cdn.example.com/promo.mp4"} =
               Video.video_embed("https://cdn.example.com/promo.mp4")
    end

    test "treats absolute paths as direct file URLs" do
      assert {:file, "/uploads/videos/promo.mp4"} =
               Video.video_embed("/uploads/videos/promo.mp4")
    end

    test "returns :invalid for nil, blank, or unrecognised input" do
      assert Video.video_embed(nil) == :invalid
      assert Video.video_embed("") == :invalid
      assert Video.video_embed("not-a-url") == :invalid
    end
  end

  describe "block contract" do
    test "implements the Block behaviour" do
      assert Video.type() == "video"
      assert is_binary(Video.name())
      assert is_binary(Video.icon())
      assert is_map(Video.default_content())
    end

    test "default_content has video_url, poster_url, caption keys" do
      defaults = Video.default_content()
      assert Map.has_key?(defaults, :video_url)
      assert Map.has_key?(defaults, :poster_url)
      assert Map.has_key?(defaults, :caption)
    end
  end
end
