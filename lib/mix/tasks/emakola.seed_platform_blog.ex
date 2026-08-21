defmodule Mix.Tasks.Emakola.SeedPlatformBlog do
  @shortdoc "Seeds the makola.io/blog launch posts (idempotent)"

  @moduledoc """
  Publishes the launch set of platform blog posts on makola.io/blog.

      mix emakola.seed_platform_blog

  Safe to re-run: existing posts (matched by slug) are left untouched.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, posts} = Emakola.Content.PlatformBlogSeeder.seed()

    Enum.each(posts, fn post ->
      Mix.shell().info("#{post.status}: /blog/#{post.slug}")
    end)
  end
end
