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
      define(:update_post, action: :update)
      define(:publish_post, action: :publish)
      define(:destroy_post, action: :destroy)
      define(:list_posts_by_store, action: :list_by_store, args: [:store_id])
      define(:list_posts_admin, action: :list_admin, args: [:store_id])
      define(:list_published_posts, action: :list_published)
      define(:get_post_by_slug, action: :get_by_slug, args: [:slug])
      define(:get_post_for_admin, action: :get_for_admin, args: [:id, :store_id])
    end

    resource Emakola.Content.MediaAttachment do
      define(:create_media_attachment, action: :create)
      define(:list_media_by_post, action: :list_by_post, args: [:post_id])
      define(:list_media_by_store, action: :list_by_store, args: [:store_id])
    end

    resource Emakola.Content.RecipeMeta do
      define(:create_recipe_meta, action: :create)
      define(:get_recipe_meta_by_post, action: :get_by_post, args: [:post_id])
    end
  end
end
