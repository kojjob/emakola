defmodule Emakola.Content.MediaAttachmentTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "create" do
    test "creates image attachment", %{store: store} do
      media = create_media!(store, %{type: :image, alt_text: "Product photo"})
      assert media.id
      assert media.type == :image
      assert media.alt_text == "Product photo"
    end

    test "creates video attachment", %{store: store} do
      media = create_media!(store, %{type: :video, url: "https://example.com/video.mp4"})
      assert media.type == :video
    end

    test "links to a post", %{store: store} do
      post = create_post!(store)
      media = create_media!(store, %{post_id: post.id})
      assert media.post_id == post.id
    end
  end

  describe "list_by_store" do
    test "returns media for store", %{store: store} do
      create_media!(store)
      create_media!(store)

      {:ok, results} =
        Emakola.Content.MediaAttachment
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read(authorize?: false)

      assert length(results) == 2
    end
  end

  describe "list_by_post" do
    test "returns media for post sorted by position", %{store: store} do
      post = create_post!(store)
      create_media!(store, %{post_id: post.id, position: 2})
      create_media!(store, %{post_id: post.id, position: 1})

      {:ok, results} =
        Emakola.Content.MediaAttachment
        |> Ash.Query.for_read(:list_by_post, %{post_id: post.id})
        |> Ash.read(authorize?: false)

      assert length(results) == 2
      assert Enum.at(results, 0).position == 1
      assert Enum.at(results, 1).position == 2
    end
  end
end
