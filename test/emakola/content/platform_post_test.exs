defmodule Emakola.Content.PlatformPostTest do
  @moduledoc """
  Tests for platform-scoped Post read actions — the makola.io marketing
  blog (posts with nil store_id). Store-scoped merchant posts must never
  leak into these reads.
  """

  use Emakola.DataCase, async: true

  import Emakola.Factory

  defp publish!(post) do
    post
    |> Ash.Changeset.for_update(:publish, %{})
    |> Ash.update!(authorize?: false)
  end

  describe "list_platform_published_posts" do
    test "returns only published platform blog posts, newest first" do
      older = publish!(Emakola.Factory.create_platform_post!(%{title: "Older Guide"}))
      newer = publish!(Emakola.Factory.create_platform_post!(%{title: "Newer Guide"}))
      _draft = Emakola.Factory.create_platform_post!(%{title: "Unpublished Draft"})

      posts = Emakola.Content.list_platform_published_posts!(authorize?: false)

      assert Enum.map(posts, & &1.id) == [newer.id, older.id]
    end

    test "excludes store-scoped merchant posts" do
      store = create_store!()

      merchant_post = create_post!(store, %{title: "Merchant Post"})

      merchant_post
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!(authorize?: false)

      platform_post = publish!(Emakola.Factory.create_platform_post!(%{title: "Platform Only"}))

      posts = Emakola.Content.list_platform_published_posts!(authorize?: false)

      assert Enum.map(posts, & &1.id) == [platform_post.id]
    end

    test "excludes platform pages and guides (blog posts only)" do
      _page = publish!(Emakola.Factory.create_platform_post!(%{type: :page, title: "A Page"}))
      blog_post = publish!(Emakola.Factory.create_platform_post!(%{title: "A Blog Post"}))

      posts = Emakola.Content.list_platform_published_posts!(authorize?: false)

      assert Enum.map(posts, & &1.id) == [blog_post.id]
    end
  end

  describe "get_platform_post_by_slug" do
    test "returns a published platform post by slug" do
      post =
        publish!(Emakola.Factory.create_platform_post!(%{title: "How to Sell Online in Ghana"}))

      found =
        Emakola.Content.get_platform_post_by_slug!("how-to-sell-online-in-ghana",
          authorize?: false
        )

      assert found.id == post.id
    end

    test "does not return a store post with the same slug" do
      store = create_store!()

      store_post = create_post!(store, %{title: "Shared Slug Title"})

      store_post
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Content.get_platform_post_by_slug("shared-slug-title",
                 authorize?: false
               )
    end

    test "does not return an unpublished platform post" do
      Emakola.Factory.create_platform_post!(%{title: "Secret Draft"})

      assert {:error, %Ash.Error.Invalid{}} =
               Emakola.Content.get_platform_post_by_slug("secret-draft", authorize?: false)
    end
  end
end
