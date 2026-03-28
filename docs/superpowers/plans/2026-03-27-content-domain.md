# Content Domain Implementation Plan (Part 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `Emakola.Content` Ash domain with Post, MediaAttachment, and RecipeMeta resources, migrations, admin CRUD UI, and storefront read-only pages.

**Architecture:** Three Ash resources under a new `Emakola.Content` domain. Posts are multi-tenant via `store_id` (nullable for platform blog). Admin LiveViews for CRUD. Storefront LiveViews for public reading. Follows existing patterns: policies with ActorHasStoreAccess, factory functions, LiveView conventions.

**Tech Stack:** Ash 3.x, AshPostgres, Phoenix LiveView, TailwindCSS, ExUnit

**Spec:** `docs/superpowers/specs/2026-03-27-seo-ai-blog-design.md`

---

## File Structure

### New files to create

```
lib/emakola/content/
  content.ex                              # Ash Domain module
  resources/
    post.ex                               # Post resource (blog, page, recipe, guide)
    media_attachment.ex                    # Media files linked to posts
    recipe_meta.ex                        # Extra fields for recipe posts
  changes/
    generate_slug.ex                      # Slug generation change (reuse pattern from Catalog)

lib/emakola_web/live/admin/content/
  post_live/
    index.ex                              # Post list (admin)
    form.ex                               # Post create/edit (admin)
  media_live/
    index.ex                              # Media library (admin)

lib/emakola_web/live/storefront/
  blog_list_live.ex                       # Public blog listing
  blog_post_live.ex                       # Public single post
  recipe_list_live.ex                     # Public recipe listing
  recipe_live.ex                          # Public single recipe
  page_live.ex                            # Public static pages

priv/repo/migrations/
  20260327100000_create_posts.exs
  20260327100001_create_media_attachments.exs
  20260327100002_create_recipe_meta.exs

test/emakola/content/
  post_test.exs
  media_attachment_test.exs
  recipe_meta_test.exs

test/emakola_web/live/admin/content/
  post_live_test.exs

test/emakola_web/live/storefront/
  blog_list_live_test.exs
  blog_post_live_test.exs
```

### Files to modify

```
config/config.exs                         # Add Emakola.Content to ash_domains
lib/emakola_web/router.ex                 # Add admin + storefront routes
test/support/factory.ex                   # Add create_post!, create_media!, create_recipe_meta!
```

---

## Task 1: Post Resource + Migration

**Files:**
- Create: `lib/emakola/content/content.ex`
- Create: `lib/emakola/content/resources/post.ex`
- Create: `lib/emakola/content/changes/generate_slug.ex`
- Create: `priv/repo/migrations/20260327100000_create_posts.exs`
- Modify: `config/config.exs` (add domain)
- Create: `test/emakola/content/post_test.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Create the migration**

```elixir
# priv/repo/migrations/20260327100000_create_posts.exs
defmodule Emakola.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all)
      add :author_id, references(:merchants, type: :uuid, on_delete: :nilify_all)
      add :type, :string, null: false
      add :title, :string, null: false, size: 255
      add :slug, :string, null: false, size: 255
      add :body, :text
      add :excerpt, :string, size: 500
      add :featured_image_url, :string
      add :seo_title, :string, size: 255
      add :seo_description, :string, size: 1000
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime_usec
      add :tags, {:array, :string}, default: []
      add :ai_generated, :boolean, default: false
      add :view_count, :integer, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:posts, [:store_id])
    create index(:posts, [:author_id])
    create index(:posts, [:status])
    create index(:posts, [:type])
    create index(:posts, [:published_at])
    create unique_index(:posts, [:store_id, :slug, :type])
  end
end
```

- [ ] **Step 2: Create the slug generation change**

```elixir
# lib/emakola/content/changes/generate_slug.ex
defmodule Emakola.Content.Changes.GenerateSlug do
  @moduledoc "Generates a URL-safe slug from the title attribute."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :title) do
      nil ->
        changeset

      title ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/[\s]+/, "-")
          |> String.trim("-")
          |> String.slice(0, 255)

        Ash.Changeset.change_attribute(changeset, :slug, slug)
    end
  end
end
```

- [ ] **Step 3: Create the Post resource**

```elixir
# lib/emakola/content/resources/post.ex
defmodule Emakola.Content.Post do
  @moduledoc """
  Blog post, page, recipe, or guide content.

  Multi-tenant via store_id (nil for platform blog).
  Status lifecycle: draft -> ai_draft -> published -> archived
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("posts")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      public?(true)
    end

    attribute :author_id, :uuid do
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:blog_post, :page, :recipe, :guide])
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :body, :string do
      public?(true)
    end

    attribute :excerpt, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :featured_image_url, :string do
      public?(true)
    end

    attribute :seo_title, :string do
      public?(true)
      constraints(max_length: 255)
    end

    attribute :seo_description, :string do
      public?(true)
      constraints(max_length: 1000)
    end

    attribute :status, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :ai_draft, :published, :archived])
    end

    attribute :published_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :tags, {:array, :string} do
      default([])
      public?(true)
    end

    attribute :ai_generated, :boolean do
      default(false)
      public?(true)
    end

    attribute :view_count, :integer do
      default(0)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :author, Emakola.Accounts.Merchant do
      define_attribute?(false)
      public?(true)
    end

    has_many :media_attachments, Emakola.Content.MediaAttachment

    has_one :recipe_meta, Emakola.Content.RecipeMeta
  end

  identities do
    identity(:unique_store_slug_type, [:store_id, :slug, :type])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :store_id,
        :author_id,
        :type,
        :title,
        :body,
        :excerpt,
        :featured_image_url,
        :seo_title,
        :seo_description,
        :tags,
        :ai_generated
      ])

      change(Emakola.Content.Changes.GenerateSlug)
    end

    update :update do
      require_atomic?(false)

      accept([
        :title,
        :body,
        :excerpt,
        :featured_image_url,
        :seo_title,
        :seo_description,
        :tags,
        :ai_generated
      ])

      change(Emakola.Content.Changes.GenerateSlug)
    end

    update :publish do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :published))

      change(fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :published_at) do
          changeset
        else
          Ash.Changeset.change_attribute(changeset, :published_at, DateTime.utc_now())
        end
      end)
    end

    update :archive do
      require_atomic?(false)
      accept([])
      change(set_attribute(:status, :archived))
    end

    update :increment_views do
      change(atomic_update(:view_count, expr(view_count + 1)))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :list_published do
      argument(:store_id, :uuid, allow_nil?: true)
      argument(:type, :atom, allow_nil?: true)

      filter(expr(status == :published))

      prepare(fn query, _context ->
        query =
          case Ash.Query.get_argument(query, :store_id) do
            nil -> query
            sid -> Ash.Query.filter(query, store_id == ^sid)
          end

        case Ash.Query.get_argument(query, :type) do
          nil -> query
          t -> Ash.Query.filter(query, type == ^t)
        end
      end)

      prepare(build(sort: [published_at: :desc]))
    end

    read :get_by_slug do
      argument(:store_id, :uuid, allow_nil?: true)
      argument(:slug, :string, allow_nil?: false)
      argument(:type, :atom, allow_nil?: true)

      filter(expr(slug == ^arg(:slug)))

      prepare(fn query, _context ->
        query =
          case Ash.Query.get_argument(query, :store_id) do
            nil -> query
            sid -> Ash.Query.filter(query, store_id == ^sid)
          end

        case Ash.Query.get_argument(query, :type) do
          nil -> query
          t -> Ash.Query.filter(query, type == ^t)
        end
      end)
    end
  end
end
```

- [ ] **Step 4: Create the Content domain module**

```elixir
# lib/emakola/content/content.ex
defmodule Emakola.Content do
  @moduledoc """
  The Content domain — blog posts, pages, recipes, guides, and media.

  Store-scoped content for SEO and marketing. Posts with nil store_id
  belong to the Emakola platform blog.
  """
  use Ash.Domain

  resources do
    resource Emakola.Content.Post do
      define(:create_post, action: :create)
      define(:list_posts_by_store, action: :list_by_store, args: [:store_id])
      define(:list_published_posts, action: :list_published)
      define(:get_post_by_slug, action: :get_by_slug, args: [:slug])
    end

    resource(Emakola.Content.MediaAttachment)
    resource(Emakola.Content.RecipeMeta)
  end
end
```

- [ ] **Step 5: Register domain in config**

Add `Emakola.Content` to the `ash_domains` list in `config/config.exs`:

```elixir
# Add after Emakola.Shipping in the ash_domains list
Emakola.Content
```

- [ ] **Step 6: Add factory functions**

Add to `test/support/factory.ex` before the closing `end`:

```elixir
  # ── Content ──────────────────────────────────────────────────────

  def create_post!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      store_id: store.id,
      type: :blog_post,
      title: "Test Post #{System.unique_integer([:positive])}",
      body: "This is test content for the blog post.",
      excerpt: "Test excerpt",
      status: :draft
    }

    params = Map.merge(default, attrs)

    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!()
  end

  def create_platform_post!(attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      store_id: nil,
      type: :blog_post,
      title: "Platform Post #{System.unique_integer([:positive])}",
      body: "Platform blog content.",
      excerpt: "Platform excerpt"
    }

    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end
```

- [ ] **Step 7: Write Post tests**

```elixir
# test/emakola/content/post_test.exs
defmodule Emakola.Content.PostTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "create" do
    test "creates a blog post with valid attributes", %{store: store} do
      post = create_post!(store, %{title: "My First Post", type: :blog_post})

      assert post.id
      assert post.store_id == store.id
      assert post.title == "My First Post"
      assert post.slug == "my-first-post"
      assert post.status == :draft
      assert post.type == :blog_post
    end

    test "auto-generates slug from title", %{store: store} do
      post = create_post!(store, %{title: "How to Cook Jollof Rice!"})
      assert post.slug == "how-to-cook-jollof-rice"
    end

    test "creates a page type", %{store: store} do
      post = create_post!(store, %{title: "About Us", type: :page})
      assert post.type == :page
    end

    test "creates a recipe type", %{store: store} do
      post = create_post!(store, %{title: "Jollof Rice Recipe", type: :recipe})
      assert post.type == :recipe
    end

    test "creates platform post with nil store_id" do
      post = create_platform_post!(%{title: "Welcome to Emakola"})
      assert is_nil(post.store_id)
    end

    test "defaults to draft status", %{store: store} do
      post = create_post!(store)
      assert post.status == :draft
    end

    test "defaults ai_generated to false", %{store: store} do
      post = create_post!(store)
      assert post.ai_generated == false
    end
  end

  describe "publish" do
    test "sets status to published and published_at", %{store: store} do
      post = create_post!(store)

      {:ok, published} =
        post
        |> Ash.Changeset.for_update(:publish)
        |> Ash.update()

      assert published.status == :published
      assert published.published_at
    end
  end

  describe "archive" do
    test "sets status to archived", %{store: store} do
      post = create_post!(store)

      {:ok, archived} =
        post
        |> Ash.Changeset.for_update(:archive)
        |> Ash.update()

      assert archived.status == :archived
    end
  end

  describe "list_published" do
    test "returns only published posts for a store", %{store: store} do
      _draft = create_post!(store, %{title: "Draft Post"})

      published =
        create_post!(store, %{title: "Published Post"})
        |> Ash.Changeset.for_update(:publish)
        |> Ash.update!()

      {:ok, results} =
        Emakola.Content.Post
        |> Ash.Query.for_read(:list_published, %{store_id: store.id})
        |> Ash.read()

      assert length(results) == 1
      assert hd(results).id == published.id
    end
  end

  describe "get_by_slug" do
    test "finds post by slug", %{store: store} do
      post = create_post!(store, %{title: "Unique Title"})

      {:ok, [found]} =
        Emakola.Content.Post
        |> Ash.Query.for_read(:get_by_slug, %{slug: "unique-title", store_id: store.id})
        |> Ash.read()

      assert found.id == post.id
    end
  end

  describe "increment_views" do
    test "atomically increments view count", %{store: store} do
      post = create_post!(store)
      assert post.view_count == 0

      {:ok, updated} =
        post
        |> Ash.Changeset.for_update(:increment_views)
        |> Ash.update()

      assert updated.view_count == 1
    end
  end
end
```

- [ ] **Step 8: Run migration and tests**

```bash
mix ecto.migrate
mix test test/emakola/content/post_test.exs
```

Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/emakola/content/ priv/repo/migrations/20260327100000_create_posts.exs config/config.exs test/emakola/content/post_test.exs test/support/factory.ex
git commit -m "feat(content): add Post resource with CRUD, slug generation, and publish lifecycle"
```

---

## Task 2: MediaAttachment Resource + Migration

**Files:**
- Create: `lib/emakola/content/resources/media_attachment.ex`
- Create: `priv/repo/migrations/20260327100001_create_media_attachments.exs`
- Create: `test/emakola/content/media_attachment_test.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Create the migration**

```elixir
# priv/repo/migrations/20260327100001_create_media_attachments.exs
defmodule Emakola.Repo.Migrations.CreateMediaAttachments do
  use Ecto.Migration

  def change do
    create table(:media_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all)
      add :store_id, references(:stores, type: :uuid, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :url, :string, null: false
      add :filename, :string
      add :alt_text, :string
      add :caption, :string
      add :position, :integer, default: 0
      add :ai_alt_text, :string
      add :file_size, :integer
      add :content_type, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:media_attachments, [:post_id])
    create index(:media_attachments, [:store_id])
    create index(:media_attachments, [:type])
  end
end
```

- [ ] **Step 2: Create the MediaAttachment resource**

```elixir
# lib/emakola/content/resources/media_attachment.ex
defmodule Emakola.Content.MediaAttachment do
  @moduledoc """
  Media files (images, videos, audio) linked to posts or the store media library.
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("media_attachments")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :post_id, :uuid do
      public?(true)
    end

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:image, :video, :audio])
    end

    attribute :url, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :filename, :string, public?: true
    attribute :alt_text, :string, public?: true
    attribute :caption, :string, public?: true
    attribute :position, :integer, default: 0, public?: true
    attribute :ai_alt_text, :string, public?: true
    attribute :file_size, :integer, public?: true
    attribute :content_type, :string, public?: true

    timestamps()
  end

  relationships do
    belongs_to :store, Emakola.Accounts.Store do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :post, Emakola.Content.Post do
      define_attribute?(false)
      public?(true)
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:store_id, :post_id, :type, :url, :filename, :alt_text, :caption, :position, :file_size, :content_type])
    end

    update :update do
      require_atomic?(false)
      accept([:alt_text, :caption, :position, :ai_alt_text])
    end

    read :list_by_post do
      argument(:post_id, :uuid, allow_nil?: false)
      filter(expr(post_id == ^arg(:post_id)))
      prepare(build(sort: [position: :asc]))
    end

    read :list_by_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end
  end
end
```

- [ ] **Step 3: Add factory function**

Add to `test/support/factory.ex`:

```elixir
  def create_media!(store, attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      store_id: store.id,
      type: :image,
      url: "https://example.com/image-#{System.unique_integer([:positive])}.jpg",
      filename: "image.jpg",
      content_type: "image/jpeg"
    }

    Emakola.Content.MediaAttachment
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end
```

- [ ] **Step 4: Write tests**

```elixir
# test/emakola/content/media_attachment_test.exs
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
        |> Ash.read()

      assert length(results) == 2
    end
  end
end
```

- [ ] **Step 5: Run migration and tests**

```bash
mix ecto.migrate
mix test test/emakola/content/media_attachment_test.exs
```

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/content/resources/media_attachment.ex priv/repo/migrations/20260327100001_create_media_attachments.exs test/emakola/content/media_attachment_test.exs test/support/factory.ex
git commit -m "feat(content): add MediaAttachment resource for images, video, and audio"
```

---

## Task 3: RecipeMeta Resource + Migration

**Files:**
- Create: `lib/emakola/content/resources/recipe_meta.ex`
- Create: `priv/repo/migrations/20260327100002_create_recipe_meta.exs`
- Create: `test/emakola/content/recipe_meta_test.exs`
- Modify: `test/support/factory.ex`

- [ ] **Step 1: Create the migration**

```elixir
# priv/repo/migrations/20260327100002_create_recipe_meta.exs
defmodule Emakola.Repo.Migrations.CreateRecipeMeta do
  use Ecto.Migration

  def change do
    create table(:recipe_meta, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), null: false
      add :prep_time, :integer
      add :cook_time, :integer
      add :servings, :integer
      add :difficulty, :string
      add :ingredients, {:array, :map}, default: []
      add :instructions, {:array, :string}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:recipe_meta, [:post_id])
  end
end
```

- [ ] **Step 2: Create the RecipeMeta resource**

```elixir
# lib/emakola/content/resources/recipe_meta.ex
defmodule Emakola.Content.RecipeMeta do
  @moduledoc """
  Structured recipe data for recipe-type posts.
  Enables Google Recipe rich results via JSON-LD.
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("recipe_meta")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :post_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :prep_time, :integer, public?: true
    attribute :cook_time, :integer, public?: true
    attribute :servings, :integer, public?: true

    attribute :difficulty, :atom do
      public?(true)
      constraints(one_of: [:easy, :medium, :hard])
    end

    attribute :ingredients, {:array, :map} do
      default([])
      public?(true)
    end

    attribute :instructions, {:array, :string} do
      default([])
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :post, Emakola.Content.Post do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_post, [:post_id])
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass always() do
      authorize_unless(actor_present())
    end

    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:post_id, :prep_time, :cook_time, :servings, :difficulty, :ingredients, :instructions])
    end

    update :update do
      require_atomic?(false)
      accept([:prep_time, :cook_time, :servings, :difficulty, :ingredients, :instructions])
    end

    read :get_by_post do
      argument(:post_id, :uuid, allow_nil?: false)
      filter(expr(post_id == ^arg(:post_id)))
    end
  end
end
```

- [ ] **Step 3: Add factory function**

Add to `test/support/factory.ex`:

```elixir
  def create_recipe_meta!(post, attrs \\ %{}) do
    attrs = Map.new(attrs)

    default = %{
      post_id: post.id,
      prep_time: 15,
      cook_time: 30,
      servings: 4,
      difficulty: :easy,
      ingredients: [%{item: "Rice", quantity: "2 cups"}, %{item: "Water", quantity: "4 cups"}],
      instructions: ["Wash the rice", "Boil water", "Cook for 20 minutes"]
    }

    Emakola.Content.RecipeMeta
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end
```

- [ ] **Step 4: Write tests**

```elixir
# test/emakola/content/recipe_meta_test.exs
defmodule Emakola.Content.RecipeMetaTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    post = create_post!(store, %{type: :recipe, title: "Jollof Rice"})
    {:ok, store: store, post: post}
  end

  describe "create" do
    test "creates recipe meta with all fields", %{post: post} do
      meta = create_recipe_meta!(post)

      assert meta.post_id == post.id
      assert meta.prep_time == 15
      assert meta.cook_time == 30
      assert meta.servings == 4
      assert meta.difficulty == :easy
      assert length(meta.ingredients) == 2
      assert length(meta.instructions) == 3
    end
  end

  describe "get_by_post" do
    test "finds recipe meta by post_id", %{post: post} do
      create_recipe_meta!(post)

      {:ok, [found]} =
        Emakola.Content.RecipeMeta
        |> Ash.Query.for_read(:get_by_post, %{post_id: post.id})
        |> Ash.read()

      assert found.post_id == post.id
    end
  end

  describe "update" do
    test "updates ingredients and instructions", %{post: post} do
      meta = create_recipe_meta!(post)

      {:ok, updated} =
        meta
        |> Ash.Changeset.for_update(:update, %{
          servings: 6,
          ingredients: [%{item: "Rice", quantity: "3 cups"}]
        })
        |> Ash.update()

      assert updated.servings == 6
      assert length(updated.ingredients) == 1
    end
  end
end
```

- [ ] **Step 5: Run migration and tests**

```bash
mix ecto.migrate
mix test test/emakola/content/
```

Expected: All content tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/content/resources/recipe_meta.ex priv/repo/migrations/20260327100002_create_recipe_meta.exs test/emakola/content/recipe_meta_test.exs test/support/factory.ex
git commit -m "feat(content): add RecipeMeta resource for recipe structured data"
```

---

## Task 4: Admin Routes + Post List LiveView

**Files:**
- Create: `lib/emakola_web/live/admin/content/post_live/index.ex`
- Modify: `lib/emakola_web/router.ex`
- Create: `test/emakola_web/live/admin/content/post_live_test.exs`

- [ ] **Step 1: Add admin routes**

Add to the `live_session :app` block in `lib/emakola_web/router.ex`, after the existing admin routes:

```elixir
    # Content management
    live "/admin/content/posts", Admin.Content.PostLive.Index
    live "/admin/content/posts/new", Admin.Content.PostLive.Form, :new
    live "/admin/content/posts/:id/edit", Admin.Content.PostLive.Form, :edit
    live "/admin/content/media", Admin.Content.MediaLive.Index
```

- [ ] **Step 2: Create post list LiveView**

```elixir
# lib/emakola_web/live/admin/content/post_live/index.ex
defmodule EmakolaWeb.Admin.Content.PostLive.Index do
  use EmakolaWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store_id = socket.assigns[:current_store] && socket.assigns.current_store.id

    posts =
      if store_id do
        Emakola.Content.Post
        |> Ash.Query.for_read(:list_by_store, %{store_id: store_id})
        |> Ash.read!()
      else
        []
      end

    {:ok,
     socket
     |> assign(:page_title, "Content")
     |> assign(:active_nav, :content)
     |> assign(:posts, posts)
     |> assign(:filter_type, :all)
     |> assign(:filter_status, :all)}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :filter_type, String.to_existing_atom(type))}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, String.to_existing_atom(status))}
  end

  @impl true
  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Enum.find(socket.assigns.posts, &(&1.id == id))

    if post do
      Ash.destroy!(post)
      posts = Enum.reject(socket.assigns.posts, &(&1.id == id))
      {:noreply, socket |> assign(:posts, posts) |> put_flash(:info, "Post deleted")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    filtered_posts = filter_posts(assigns.posts, assigns.filter_type, assigns.filter_status)
    assigns = assign(assigns, :filtered_posts, filtered_posts)

    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-xl font-bold text-slate-900">Content</h1>
          <p class="text-sm text-slate-500 mt-0.5">{length(@posts)} total posts</p>
        </div>
        <.link
          navigate={~p"/admin/content/posts/new"}
          class="inline-flex items-center px-4 py-2.5 bg-emerald-600 text-white rounded-xl text-sm font-semibold hover:bg-emerald-700 transition-colors"
        >
          New Post
        </.link>
      </div>

      <%!-- Filters --%>
      <div class="flex gap-2">
        <button
          :for={type <- [:all, :blog_post, :page, :recipe, :guide]}
          phx-click="filter_type"
          phx-value-type={type}
          class={"px-3 py-1.5 rounded-lg text-sm font-medium transition-colors #{if @filter_type == type, do: "bg-slate-900 text-white", else: "bg-white text-slate-600 border border-slate-200 hover:bg-slate-50"}"}
        >
          {type_label(type)}
        </button>
      </div>

      <%!-- Posts Table --%>
      <div class="bg-white border border-slate-200 rounded-xl overflow-hidden">
        <table class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Title</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Type</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Status</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Views</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={post <- @filtered_posts} class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <p class="text-sm font-medium text-slate-900 truncate max-w-xs">{post.title}</p>
                <p :if={post.ai_generated} class="text-xs text-amber-600 mt-0.5">AI generated</p>
              </td>
              <td class="px-4 py-3">
                <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-700">
                  {type_label(post.type)}
                </span>
              </td>
              <td class="px-4 py-3">
                <span class={[
                  "inline-flex px-2 py-0.5 rounded-full text-xs font-medium",
                  status_class(post.status)
                ]}>
                  {String.capitalize(to_string(post.status))}
                </span>
              </td>
              <td class="px-4 py-3 text-sm text-slate-600">{post.view_count}</td>
              <td class="px-4 py-3 text-right">
                <.link
                  navigate={~p"/admin/content/posts/#{post.id}/edit"}
                  class="text-sm text-slate-600 hover:text-slate-900 font-medium"
                >
                  Edit
                </.link>
              </td>
            </tr>
            <tr :if={@filtered_posts == []}>
              <td colspan="5" class="px-4 py-8 text-center text-sm text-slate-400">
                No posts yet. Create your first post to start driving traffic.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp filter_posts(posts, :all, :all), do: posts
  defp filter_posts(posts, :all, status), do: Enum.filter(posts, &(&1.status == status))
  defp filter_posts(posts, type, :all), do: Enum.filter(posts, &(&1.type == type))
  defp filter_posts(posts, type, status), do: Enum.filter(posts, &(&1.type == type and &1.status == status))

  defp type_label(:all), do: "All"
  defp type_label(:blog_post), do: "Blog"
  defp type_label(:page), do: "Page"
  defp type_label(:recipe), do: "Recipe"
  defp type_label(:guide), do: "Guide"

  defp status_class(:draft), do: "bg-slate-100 text-slate-600"
  defp status_class(:ai_draft), do: "bg-amber-100 text-amber-700"
  defp status_class(:published), do: "bg-emerald-100 text-emerald-700"
  defp status_class(:archived), do: "bg-red-100 text-red-600"
end
```

- [ ] **Step 3: Write admin LiveView test**

```elixir
# test/emakola_web/live/admin/content/post_live_test.exs
defmodule EmakolaWeb.Admin.Content.PostLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    conn = log_in_merchant(conn, merchant)
    {:ok, conn: conn, store: store, merchant: merchant}
  end

  describe "PostLive.Index" do
    test "renders empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "Content"
      assert html =~ "No posts yet"
    end

    test "lists posts for the store", %{conn: conn, store: store} do
      create_post!(store, %{title: "My Blog Post"})
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "My Blog Post"
    end

    test "has new post button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/content/posts")
      assert html =~ "New Post"
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
mix test test/emakola_web/live/admin/content/
```

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/live/admin/content/ lib/emakola_web/router.ex test/emakola_web/live/admin/content/
git commit -m "feat(web): add admin content management list page with filters"
```

---

## Task 5: Storefront Blog Routes + LiveViews

**Files:**
- Create: `lib/emakola_web/live/storefront/blog_list_live.ex`
- Create: `lib/emakola_web/live/storefront/blog_post_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Create: `test/emakola_web/live/storefront/blog_list_live_test.exs`
- Create: `test/emakola_web/live/storefront/blog_post_live_test.exs`

- [ ] **Step 1: Add storefront routes**

Add inside the storefront `live_session :storefront` block in `router.ex`:

```elixir
      live "/blog", BlogListLive
      live "/blog/:post_slug", BlogPostLive
      live "/recipes", RecipeListLive
      live "/recipes/:recipe_slug", RecipeLive
```

- [ ] **Step 2: Create blog list LiveView**

```elixir
# lib/emakola_web/live/storefront/blog_list_live.ex
defmodule EmakolaWeb.Storefront.BlogListLive do
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        {:ok, posts} =
          Emakola.Content.Post
          |> Ash.Query.for_read(:list_published, %{store_id: store.id, type: :blog_post})
          |> Ash.read()

        cart_session_id = session["cart_session_id"]
        cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

        theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
        theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

        {:ok,
         socket
         |> assign(:store, store)
         |> assign(:posts, posts)
         |> assign(:cart_session_id, cart_session_id)
         |> assign(:cart_count, cart_count)
         |> assign(:theme, theme)
         |> assign(:theme_module, theme_module)
         |> assign(:categories, [])
         |> assign(:page_title, "Blog - #{store.name}")}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl font-semibold text-stone-900 mb-8">Blog</h1>

      <div :if={@posts == []} class="text-center py-16">
        <p class="text-stone-400">No posts yet. Check back soon.</p>
      </div>

      <div class="space-y-8">
        <a
          :for={post <- @posts}
          href={"/s/#{@store.slug}/blog/#{post.slug}"}
          class="block group"
        >
          <article class="flex gap-6">
            <div :if={post.featured_image_url} class="w-48 h-32 rounded-xl overflow-hidden shrink-0">
              <img src={post.featured_image_url} alt={post.title} class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" loading="lazy" />
            </div>
            <div class="flex-1 min-w-0">
              <h2 class="text-lg font-semibold text-stone-900 group-hover:text-amber-700 transition-colors">{post.title}</h2>
              <p :if={post.excerpt} class="text-sm text-stone-600 mt-1 line-clamp-2">{post.excerpt}</p>
              <div class="flex items-center gap-3 mt-3 text-xs text-stone-400">
                <span :if={post.published_at}>{Calendar.strftime(post.published_at, "%B %d, %Y")}</span>
                <span>{post.view_count} views</span>
              </div>
            </div>
          </article>
        </a>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 3: Create single blog post LiveView**

```elixir
# lib/emakola_web/live/storefront/blog_post_live.ex
defmodule EmakolaWeb.Storefront.BlogPostLive do
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.StoreResolver

  require Ash.Query

  @impl true
  def mount(%{"store_slug" => slug, "post_slug" => post_slug}, session, socket) do
    case StoreResolver.resolve(slug) do
      {:ok, store} ->
        case Emakola.Content.Post
             |> Ash.Query.for_read(:get_by_slug, %{slug: post_slug, store_id: store.id, type: :blog_post})
             |> Ash.read() do
          {:ok, [post]} ->
            # Increment views
            post |> Ash.Changeset.for_update(:increment_views) |> Ash.update()

            cart_session_id = session["cart_session_id"]
            cart_count = if cart_session_id, do: CartStore.cart_count(cart_session_id), else: 0

            theme = Emakola.Themes.ThemeResolver.resolve(store.theme_config || %{})
            theme_module = Emakola.Themes.ThemeResolver.theme_module(theme.theme_id)

            {:ok,
             socket
             |> assign(:store, store)
             |> assign(:post, post)
             |> assign(:cart_session_id, cart_session_id)
             |> assign(:cart_count, cart_count)
             |> assign(:theme, theme)
             |> assign(:theme_module, theme_module)
             |> assign(:categories, [])
             |> assign(:page_title, "#{post.title} - #{store.name}")}

          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Post not found")
             |> redirect(to: "/s/#{slug}/blog")}
        end

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Store not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <article class="max-w-3xl mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <a href={"/s/#{@store.slug}/blog"} class="inline-flex items-center gap-1 text-sm text-stone-500 hover:text-stone-700 mb-6">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" /></svg>
        Back to blog
      </a>

      <header class="mb-8">
        <h1 class="font-[Cormorant,Georgia,serif] text-3xl sm:text-4xl font-semibold text-stone-900 mb-3">{@post.title}</h1>
        <div class="flex items-center gap-3 text-sm text-stone-500">
          <span :if={@post.published_at}>{Calendar.strftime(@post.published_at, "%B %d, %Y")}</span>
          <span :if={@post.tags != []} class="flex gap-1.5">
            <span :for={tag <- @post.tags} class="px-2 py-0.5 bg-stone-100 rounded-full text-xs">{tag}</span>
          </span>
        </div>
      </header>

      <div :if={@post.featured_image_url} class="mb-8 rounded-2xl overflow-hidden">
        <img src={@post.featured_image_url} alt={@post.title} class="w-full" />
      </div>

      <div class="prose prose-stone prose-lg max-w-none">
        {raw(@post.body)}
      </div>
    </article>
    """
  end
end
```

- [ ] **Step 4: Write storefront tests**

```elixir
# test/emakola_web/live/storefront/blog_list_live_test.exs
defmodule EmakolaWeb.Storefront.BlogListLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup do
    store = create_store!(%{name: "Blog Shop", slug: "blog-shop"})
    {:ok, store: store}
  end

  test "renders blog list with published posts", %{conn: conn, store: store} do
    post = create_post!(store, %{title: "Published Article", type: :blog_post})
    post |> Ash.Changeset.for_update(:publish) |> Ash.update!()

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")

    assert html =~ "Blog"
    assert html =~ "Published Article"
  end

  test "does not show draft posts", %{conn: conn, store: store} do
    create_post!(store, %{title: "Secret Draft", type: :blog_post})

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")

    refute html =~ "Secret Draft"
  end

  test "shows empty state when no posts", %{conn: conn, store: store} do
    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog")
    assert html =~ "No posts yet"
  end
end
```

```elixir
# test/emakola_web/live/storefront/blog_post_live_test.exs
defmodule EmakolaWeb.Storefront.BlogPostLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Emakola.Factory

  setup do
    store = create_store!(%{name: "Blog Shop", slug: "blog-shop-2"})
    {:ok, store: store}
  end

  test "renders a published blog post", %{conn: conn, store: store} do
    post =
      create_post!(store, %{title: "My Great Post", type: :blog_post, body: "<p>Hello world</p>"})
      |> Ash.Changeset.for_update(:publish)
      |> Ash.update!()

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/blog/#{post.slug}")

    assert html =~ "My Great Post"
    assert html =~ "Hello world"
  end

  test "redirects when post not found", %{conn: conn, store: store} do
    assert {:error, {:redirect, _}} = live(conn, "/s/#{store.slug}/blog/nonexistent")
  end
end
```

- [ ] **Step 5: Run tests**

```bash
mix test test/emakola_web/live/storefront/blog_list_live_test.exs test/emakola_web/live/storefront/blog_post_live_test.exs
```

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/storefront/blog_list_live.ex lib/emakola_web/live/storefront/blog_post_live.ex lib/emakola_web/router.ex test/emakola_web/live/storefront/blog_*
git commit -m "feat(web): add storefront blog list and post pages"
```

---

## Summary

| Task | What it builds | Tests |
|------|---------------|-------|
| 1 | Post resource, domain, migration, slug generation | 9 unit tests |
| 2 | MediaAttachment resource + migration | 3 unit tests |
| 3 | RecipeMeta resource + migration | 3 unit tests |
| 4 | Admin post list LiveView + routes | 3 LiveView tests |
| 5 | Storefront blog list + post LiveViews + routes | 5 LiveView tests |

**Total: 5 tasks, ~23 tests, 15 new files, 3 modified files**

After this plan is complete, proceed to **Part 2: AI Content Generator** (behaviour, Claude implementation, Oban workers) and **Part 3: SEO Infrastructure** (sitemap, structured data, robots.txt).
