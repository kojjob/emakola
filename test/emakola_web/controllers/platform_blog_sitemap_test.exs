defmodule EmakolaWeb.PlatformBlogSitemapTest do
  @moduledoc "Platform sitemap must surface the apex blog index and published posts."

  use EmakolaWeb.ConnCase, async: true

  defp published_platform_post!(title) do
    post =
      Emakola.Content.Post
      |> Ash.Changeset.for_create(:create, %{
        type: :blog_post,
        title: title,
        body: "<p>body</p>",
        excerpt: "excerpt"
      })
      |> Ash.create!(authorize?: false)

    post
    |> Ash.Changeset.for_update(:publish, %{})
    |> Ash.update!(authorize?: false)
  end

  test "GET /sitemap-platform.xml lists /blog and published platform posts", %{conn: conn} do
    published_platform_post!("Sitemap Visible Post")

    body = conn |> get("/sitemap-platform.xml") |> response(200)

    assert body =~ "<loc>http://localhost:4000/blog</loc>"
    assert body =~ "<loc>http://localhost:4000/blog/sitemap-visible-post</loc>"
  end

  test "GET /sitemap-platform.xml omits unpublished platform posts", %{conn: conn} do
    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, %{
      type: :blog_post,
      title: "Sitemap Hidden Draft",
      body: "<p>body</p>"
    })
    |> Ash.create!(authorize?: false)

    body = conn |> get("/sitemap-platform.xml") |> response(200)

    refute body =~ "sitemap-hidden-draft"
  end
end
