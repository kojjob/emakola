defmodule Emakola.Content.PlatformBlogSeederTest do
  @moduledoc """
  The seeder publishes the launch set of makola.io blog posts. Re-running
  never duplicates, and refreshes live content from the source files —
  platform posts have no admin editor, so the seeder is the only way to
  correct what is published.
  """

  use Emakola.DataCase, async: true

  alias Emakola.Content.PlatformBlogSeeder

  test "seeds four published platform blog posts with SEO fields and hero images" do
    assert {:ok, posts} = PlatformBlogSeeder.seed()
    assert length(posts) == 4

    for post <- posts do
      assert is_nil(post.store_id)
      assert post.type == :blog_post
      assert post.status == :published
      assert post.published_at
      assert post.ai_generated
      assert post.excerpt not in [nil, ""]
      assert String.length(post.seo_title) <= 60
      assert String.length(post.seo_description) <= 155
      assert post.featured_image_url =~ "/images/blog/"
      assert String.length(post.body) > 2_000
      assert post.tags != []
    end
  end

  test "re-running the seeder does not duplicate posts" do
    assert {:ok, first} = PlatformBlogSeeder.seed()
    assert {:ok, second} = PlatformBlogSeeder.seed()

    assert length(second) == length(first)

    total =
      Emakola.Content.list_platform_published_posts!(authorize?: false)
      |> length()

    assert total == 4
  end

  test "re-running the seeder refreshes stale content from the source files" do
    assert {:ok, [first | _]} = PlatformBlogSeeder.seed()

    # Simulate content that has drifted from the source file — the state a
    # correction lands in: the file is fixed, the published post is stale.
    first
    |> Ash.Changeset.for_update(:update, %{
      body: "<p>stale body</p>",
      excerpt: "stale excerpt",
      seo_title: "stale title",
      seo_description: "stale description"
    })
    |> Ash.update!(authorize?: false)

    assert {:ok, _} = PlatformBlogSeeder.seed()

    refreshed = Emakola.Content.get_platform_post_by_slug!(first.slug, authorize?: false)

    assert refreshed.id == first.id
    assert refreshed.body == first.body
    assert refreshed.excerpt == first.excerpt
    assert refreshed.seo_title == first.seo_title
    assert refreshed.seo_description == first.seo_description
  end

  test "refreshing keeps the post's identity and engagement data" do
    assert {:ok, [first | _]} = PlatformBlogSeeder.seed()

    first
    |> Ash.Changeset.for_update(:increment_views, %{})
    |> Ash.update!(authorize?: false)

    assert {:ok, _} = PlatformBlogSeeder.seed()

    refreshed = Emakola.Content.get_platform_post_by_slug!(first.slug, authorize?: false)

    assert refreshed.slug == first.slug
    assert refreshed.published_at == first.published_at
    assert refreshed.view_count == 1
  end
end
