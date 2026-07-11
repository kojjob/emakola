defmodule Emakola.Content.PostTest do
  @moduledoc "Tests for the Content.Post resource."

  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Content.Post

  setup do
    store = create_store!()
    %{store: store}
  end

  describe "create action" do
    test "creates a blog post with valid attributes", %{store: store} do
      post = create_post!(store, %{title: "My First Blog Post", body: "Hello world!"})

      assert post.title == "My First Blog Post"
      assert post.body == "Hello world!"
      assert post.type == :blog_post
      assert post.store_id == store.id
    end

    test "auto-generates slug from title", %{store: store} do
      post = create_post!(store, %{title: "Hello World Post!"})

      assert post.slug == "hello-world-post"
    end

    test "creates a page type", %{store: store} do
      post = create_post!(store, %{type: :page, title: "About Us"})

      assert post.type == :page
      assert post.slug == "about-us"
    end

    test "creates a recipe type", %{store: store} do
      post = create_post!(store, %{type: :recipe, title: "Jollof Rice Recipe"})

      assert post.type == :recipe
      assert post.slug == "jollof-rice-recipe"
    end

    test "creates a platform post with nil store_id" do
      post = create_platform_post!(%{title: "Welcome to Emakola"})

      assert post.store_id == nil
      assert post.title == "Welcome to Emakola"
      assert post.slug == "welcome-to-emakola"
    end

    test "defaults to draft status", %{store: store} do
      post = create_post!(store)

      assert post.status == :draft
    end

    test "defaults ai_generated to false", %{store: store} do
      post = create_post!(store)

      assert post.ai_generated == false
    end

    test "accepts ai_generated flag", %{store: store} do
      post = create_post!(store, %{ai_generated: true})

      assert post.ai_generated == true
    end

    test "defaults view_count to 0", %{store: store} do
      post = create_post!(store)

      assert post.view_count == 0
    end

    test "defaults tags to empty list", %{store: store} do
      post = create_post!(store)

      assert post.tags == []
    end
  end

  describe "publish action" do
    test "sets status to published and sets published_at", %{store: store} do
      post = create_post!(store)
      assert post.status == :draft
      assert post.published_at == nil

      published =
        post
        |> Ash.Changeset.for_update(:publish, %{})
        |> Ash.update!(authorize?: false)

      assert published.status == :published
      assert published.published_at != nil
    end

    test "does not overwrite existing published_at", %{store: store} do
      original_time = ~U[2025-01-01 12:00:00.000000Z]

      post =
        create_post!(store)
        |> Ash.Changeset.for_update(:publish, %{})
        |> Ash.update!(authorize?: false)

      # Force set a specific published_at, then re-publish
      post =
        post
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update!(authorize?: false)

      post =
        post
        |> Ash.Changeset.for_update(:update, %{})
        |> Ash.Changeset.force_change_attribute(:published_at, original_time)
        |> Ash.update!(authorize?: false)

      republished =
        post
        |> Ash.Changeset.for_update(:publish, %{})
        |> Ash.update!(authorize?: false)

      assert republished.status == :published
      assert republished.published_at == original_time
    end
  end

  describe "archive action" do
    test "sets status to archived", %{store: store} do
      post =
        create_post!(store)
        |> Ash.Changeset.for_update(:publish, %{})
        |> Ash.update!(authorize?: false)

      archived =
        post
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update!(authorize?: false)

      assert archived.status == :archived
    end
  end

  describe "list_published action" do
    test "returns only published posts", %{store: store} do
      _draft = create_post!(store, %{title: "Draft Post"})

      published =
        create_post!(store, %{title: "Published Post"})
        |> Ash.Changeset.for_update(:publish, %{})
        |> Ash.update!(authorize?: false)

      results =
        Post
        |> Ash.Query.for_read(:list_published, %{store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
      assert hd(results).id == published.id
    end

    test "filters by type when provided", %{store: store} do
      create_post!(store, %{title: "Blog", type: :blog_post})
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!(authorize?: false)

      create_post!(store, %{title: "Page", type: :page})
      |> Ash.Changeset.for_update(:publish, %{})
      |> Ash.update!(authorize?: false)

      results =
        Post
        |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :blog_post})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
      assert hd(results).type == :blog_post
    end
  end

  describe "get_by_slug action" do
    test "finds a post by slug", %{store: store} do
      post = create_post!(store, %{title: "Unique Slug Post"})

      found =
        Post
        |> Ash.Query.for_read(:get_by_slug, %{slug: "unique-slug-post", store_id: store.id})
        |> Ash.read_one!(authorize?: false)

      assert found.id == post.id
    end

    test "returns nil for non-existent slug", %{store: store} do
      result =
        Post
        |> Ash.Query.for_read(:get_by_slug, %{slug: "does-not-exist", store_id: store.id})
        |> Ash.read_one!(authorize?: false)

      assert result == nil
    end
  end

  describe "increment_views action" do
    test "atomically increments view_count", %{store: store} do
      post = create_post!(store)
      assert post.view_count == 0

      updated =
        post
        |> Ash.Changeset.for_update(:increment_views, %{})
        |> Ash.update!(authorize?: false)

      assert updated.view_count == 1

      updated2 =
        updated
        |> Ash.Changeset.for_update(:increment_views, %{})
        |> Ash.update!(authorize?: false)

      assert updated2.view_count == 2
    end
  end

  describe "list_by_store action" do
    test "returns posts for a specific store", %{store: store} do
      other_store = create_store!()
      create_post!(store, %{title: "Store A Post"})
      create_post!(other_store, %{title: "Store B Post"})

      results =
        Post
        |> Ash.Query.for_read(:list_by_store, %{store_id: store.id})
        |> Ash.read!(authorize?: false)

      assert length(results) == 1
      assert hd(results).title == "Store A Post"
    end
  end
end
