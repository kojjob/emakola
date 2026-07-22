defmodule Emakola.StorageTest do
  use ExUnit.Case, async: true

  alias Emakola.Storage

  describe "trusted_media_url?/1" do
    test "accepts local upload paths" do
      assert Storage.trusted_media_url?("/uploads/reviews/photo.jpg")
      assert Storage.trusted_media_url?("/uploads/stores/abc/heroes/hero.png")
    end

    test "accepts bundled static asset paths" do
      assert Storage.trusted_media_url?("/images/placeholder.png")
    end

    test "accepts URLs on the configured storage public host" do
      url = Storage.S3.public_base_url() <> "stores/abc/reviews/photo.jpg"
      assert Storage.trusted_media_url?(url)
    end

    test "rejects URLs on other hosts" do
      refute Storage.trusted_media_url?("https://evil.example.com/photo.jpg")
    end

    test "rejects lookalike hosts that merely start with the public host" do
      base = String.trim_trailing(Storage.S3.public_base_url(), "/")
      refute Storage.trusted_media_url?(base <> ".evil.example.com/photo.jpg")
    end

    test "rejects non-http garbage and non-binaries" do
      refute Storage.trusted_media_url?("javascript:alert(1)")
      refute Storage.trusted_media_url?("uploads/relative-without-slash.jpg")
      refute Storage.trusted_media_url?(nil)
      refute Storage.trusted_media_url?(123)
    end
  end
end
