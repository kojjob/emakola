defmodule Emakola.Catalog do
  @moduledoc """
  The Catalog domain — products, variants, categories, options, images.

  All resources are multi-tenant, scoped to a store via store_id.
  """
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/v1/shop")
  end

  resources do
    resource Emakola.Catalog.Category do
      define(:create_category, action: :create)
      define(:list_categories_by_store, action: :list_by_store, args: [:store_id])
      define(:list_root_categories, action: :list_roots, args: [:store_id])
      define(:list_child_categories, action: :list_children, args: [:parent_id, :store_id])
      define(:get_category, action: :read, get_by: [:id])
      define(:get_category_for_store, action: :get_by_store, args: [:id, :store_id])
      define(:get_category_by_slug, action: :get_by_slug, args: [:store_id, :slug])
      define(:update_category, action: :update)
      define(:destroy_category, action: :destroy)
    end

    resource Emakola.Catalog.Product do
      define(:create_product, action: :create)
      define(:get_product, action: :read, get_by: [:id])
      define(:get_product_for_store, action: :get_by_store, args: [:id, :store_id])
      define(:get_product_by_slug, action: :get_by_slug, args: [:store_id, :slug])
      # Storefront-safe single-product fetch — active, moderation-ok, store-scoped.
      define(:get_active_product, action: :get_active_by_id, args: [:store_id, :id])
      define(:update_product, action: :update)
      define(:archive_product, action: :archive)
      define(:activate_product, action: :activate)
      define(:increment_product_share_count, action: :increment_share_count)
      define(:list_products_by_store, action: :list_by_store, args: [:store_id])

      define(:list_products_by_store_and_status,
        action: :list_by_store_and_status,
        args: [:store_id, :status]
      )

      define(:search_products, action: :search, args: [:query, :store_id])

      define(:list_products_by_category,
        action: :list_by_category,
        args: [:category_id, :store_id]
      )

      define(:list_related_products, action: :list_related, args: [:store_id, :product_id])
      define(:list_products_admin, action: :list_admin, args: [:store_id])
      # Platform content moderation — call with `authorize?: false` (gated in the LiveView).
      define(:take_down_product, action: :take_down)
      define(:reinstate_product, action: :reinstate)
      define(:list_products_for_moderation, action: :list_for_moderation)
    end

    resource Emakola.Catalog.OptionType do
      define(:list_option_types_by_product, action: :list_by_product, args: [:product_id])
    end

    resource(Emakola.Catalog.OptionValue)

    resource Emakola.Catalog.Variant do
      define(:create_variant, action: :create)
      define(:list_variants_by_store, action: :list_by_store, args: [:store_id])
      define(:list_low_stock, action: :low_stock, args: [:threshold, :store_id])
      define(:list_variants_admin, action: :list_admin, args: [:store_id])
      define(:adjust_variant_stock, action: :adjust_stock)
      define(:update_variant, action: :update)
      define(:sync_availability_variant, action: :sync_availability)
    end

    resource Emakola.Catalog.VariantOptionValue do
      define(:list_variant_option_values_by_variants,
        action: :list_by_variants,
        args: [:variant_ids]
      )
    end

    resource Emakola.Catalog.Image do
      define(:create_image, action: :create)
      define(:get_image, action: :read, get_by: [:id])
      define(:destroy_image, action: :destroy)
    end

    resource Emakola.Catalog.Review do
      define(:create_review, action: :create)
      define(:hide_review, action: :hide)
      define(:unhide_review, action: :unhide)
      define(:list_reviews_admin, action: :list_admin, args: [:store_id])
      define(:get_review_by_store, action: :get_by_store, args: [:id, :store_id])
      define(:list_published_reviews, action: :list_published_by_product, args: [:product_id])
    end

    resource(Emakola.Catalog.DigitalFile)
  end

  @doc """
  One representative photograph per category — the cover a storefront's
  category tiles wear.

  Themes used to source these from the home page's product assign, which is a
  capped preview: any category whose products fell outside it showed an empty
  box. This reads the store's catalogue directly instead.

  Strictly scoped, because a tile is a promise about what is behind it:

  - the photo always comes from a product really in that category
  - only `:active` products lend one — a draft is not on sale
  - the query is filtered by `store_id`, so covers never cross a tenant

  Returns a map of `category_id => image URL`. A category with nothing to show
  is simply absent, and the theme keeps its own empty state.
  """
  @spec category_covers(Ecto.UUID.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t()}
  def category_covers(_store_id, []), do: %{}

  # One DISTINCT ON query rather than loading every active product (with its
  # images) just to keep the first URL per category in Elixir — a store with
  # 500 active products previously paid for all 500 (plus their images) to
  # render ~6 category tiles. `url` is `allow_nil?: false` on Image, so the
  # inner join already gives exactly the "has a real photo" filter the old
  # Elixir-side reduce used to apply by hand — a product with zero image rows
  # simply produces no join row and never wins a category. Raw Ecto because
  # Ash's query DSL has
  # no DISTINCT ON; same precedent as `Emakola.Cart.CartStore`'s domain-layer
  # queries (this stays in the Catalog domain, never in a LiveView — see
  # arch-review issue 6 for why that distinction matters).
  def category_covers(store_id, category_ids) when is_list(category_ids) do
    import Ecto.Query

    from(p in Emakola.Catalog.Product,
      join: i in Emakola.Catalog.Image,
      on: i.product_id == p.id and i.store_id == p.store_id,
      where: p.store_id == ^store_id and p.status == :active and p.category_id in ^category_ids,
      distinct: p.category_id,
      order_by: [asc: p.category_id, asc: p.inserted_at, asc: i.inserted_at],
      select: {p.category_id, coalesce(i.thumbnail_url, i.url)}
    )
    |> Emakola.Repo.all()
    |> Map.new()
  end

  @doc """
  The store's own published reviews, for themes that show testimonials.

  Themes used to ship *invented* ones: named strangers ("Akua M., Accra") with
  quotes nobody wrote, under a hardcoded five-star row, printed on every
  storefront that had not overridden them. A shop that had never sold anything
  still opened with four glowing reviews. That is a lie told to a customer
  about a product, and no amount of it is acceptable.

  A testimonial is now a real review or it does not exist:

  - only `:published` reviews (a merchant-hidden review stays hidden)
  - scoped by `store_id`, so one shop never wears another's praise
  - the reviewer is loaded so the theme can name them; the rating is the
    reviewer's own, so the stars tell the truth

  The resource does the rest of the work: a review requires an `order_id`, so
  only someone who actually bought the thing can say anything about it, and
  `body` is required, so there are no wordless testimonials to filter out.

  A store with no reviews gets `[]`, and the theme renders nothing at all.
  """
  @spec store_testimonials(Ecto.UUID.t(), pos_integer()) :: [Emakola.Catalog.Review.t()]
  def store_testimonials(store_id, limit \\ 4) do
    require Ash.Query

    Emakola.Catalog.Review
    |> Ash.Query.filter(store_id == ^store_id and status == :published)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.load(:customer)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  The photographs the store's customers attached to their reviews, newest first.

  Fashion's "Worn by you." strip used to lay out six camera glyphs where these
  belonged — the shape of customer photography with nothing inside it. These are
  the real ones: `Catalog.Review.images`, the same list the product page already
  renders under each review.

  Same guarantees as `store_testimonials/2` — only `:published` reviews (a
  merchant-hidden review takes its photos down with it), scoped by `store_id`,
  and a review is only possible for someone who actually bought the thing.

  A store whose customers have posted no photographs gets `[]`, and the strip
  renders nothing at all.
  """
  @spec store_review_photos(Ecto.UUID.t(), pos_integer()) :: [map()]
  def store_review_photos(store_id, limit \\ 12) do
    require Ash.Query

    Emakola.Catalog.Review
    |> Ash.Query.filter(store_id == ^store_id and status == :published)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(& &1.images)
    |> Enum.take(limit)
  end
end
