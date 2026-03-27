defmodule Emakola.Content do
  @moduledoc """
  The Content domain -- blog posts, pages, recipes, guides, and media.

  Supports both store-scoped content (merchant blogs) and platform-level
  content (Emakola marketing pages). All store-scoped resources use
  store_id for multi-tenant isolation.
  """

  use Ash.Domain

  resources do
    resource Emakola.Content.Post do
      define(:create_post, action: :create)
      define(:list_posts_by_store, action: :list_by_store, args: [:store_id])
      define(:list_published_posts, action: :list_published)
      define(:get_post_by_slug, action: :get_by_slug, args: [:slug])
    end

    # resource(Emakola.Content.MediaAttachment) -- embedded, added in Task 2
    # resource(Emakola.Content.RecipeMeta) -- embedded, added in Task 3
  end
end
