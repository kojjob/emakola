defmodule Emakola.Content.PlatformBlogSeederTest do
  @moduledoc """
  The seeder publishes the launch set of makola.io blog posts and is
  idempotent — re-running never duplicates or overwrites existing posts.
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
end
