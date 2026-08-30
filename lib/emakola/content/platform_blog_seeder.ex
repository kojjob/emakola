defmodule Emakola.Content.PlatformBlogSeeder do
  @moduledoc """
  Seeds the launch set of makola.io/blog posts — platform-level (nil
  store_id) merchant-acquisition content. Bodies live as HTML files in
  priv/platform_blog/, keyed by slug.

  Idempotent, and the files are the source of truth: re-running never
  duplicates, and refreshes an existing post's content from its file.
  Platform posts have no admin editor (`list_admin` is store-scoped), so
  this is the only way to correct what is already published — a seeder
  that skipped existing posts would make every correction a no-op.

  Identity and engagement survive a refresh: title and slug are the
  lookup key and stay put (rename = a new post, by design), as do
  `published_at` and `view_count`.
  """

  require Ash.Query

  @posts [
    %{
      title: "Best Ecommerce Platform in Ghana",
      seo_title: "Best Ecommerce Platform in Ghana: 2026 Comparison",
      seo_description:
        "Shopify, WooCommerce, marketplaces, or Makola? An honest comparison of ecommerce platforms for Ghanaian merchants in 2026.",
      excerpt:
        "The best platform for a Ghanaian business is the one your customers can pay on. An honest look at Shopify, WooCommerce, marketplaces, and Makola.",
      tags: ["platforms", "comparison", "ghana"]
    },
    %{
      title: "How to Accept MoMo Payments Online",
      seo_title: "How to Accept MoMo Payments Online in Ghana",
      seo_description:
        "Accept MTN MoMo, Telecel Cash, and AT Money on your online store — no screenshots, no manual checks. How Ghanaian sellers set it up.",
      excerpt:
        "Mobile money is how Ghana pays. The way you collect it decides how much buyers trust you — and how many evenings you lose to screenshot checking.",
      tags: ["mobile money", "payments", "ghana"]
    },
    %{
      title: "Selling on WhatsApp in Ghana",
      seo_title: "Selling on WhatsApp in Ghana Without Screenshots",
      seo_description:
        "WhatsApp is Ghana's best sales channel — until payment screenshots eat your day. How smart sellers pair WhatsApp with a store link.",
      excerpt:
        "\"How much?\" — \"I've sent it o\" — the squint at the screenshot. WhatsApp is unbeatable for closing sales; here's how to stop it working you like a call centre.",
      tags: ["whatsapp", "social selling", "ghana"]
    },
    %{
      title: "How to Sell Online in Ghana",
      seo_title: "How to Sell Online in Ghana: The 2026 Guide",
      seo_description:
        "Start selling online in Ghana with mobile money, WhatsApp orders, and a free store. A practical step-by-step guide for new merchants.",
      excerpt:
        "No developer, no capital, no company registration — what you actually need to start selling online in Ghana, and the mistakes that cost new sellers their first customers.",
      tags: ["selling online", "getting started", "ghana"]
    }
  ]

  @doc "Seeds all launch posts. Returns {:ok, posts} with one post per entry."
  def seed do
    posts = Enum.map(@posts, &upsert_post/1)
    {:ok, posts}
  end

  defp upsert_post(entry) do
    slug = slugify(entry.title)

    case existing_post(slug) do
      nil -> create_and_publish(entry, slug)
      post -> refresh(post, entry, slug)
    end
  end

  defp existing_post(slug) do
    Emakola.Content.Post
    |> Ash.Query.filter(is_nil(store_id) and slug == ^slug and type == :blog_post)
    |> Ash.read_first!(authorize?: false)
  end

  defp refresh(post, entry, slug) do
    post
    |> Ash.Changeset.for_update(:update, %{
      body: read_body(slug),
      excerpt: entry.excerpt,
      seo_title: entry.seo_title,
      seo_description: entry.seo_description,
      featured_image_url: "/images/blog/#{slug}.jpg",
      tags: entry.tags
    })
    |> Ash.update!(authorize?: false)
  end

  defp create_and_publish(entry, slug) do
    body = read_body(slug)

    Emakola.Content.Post
    |> Ash.Changeset.for_create(:create, %{
      type: :blog_post,
      title: entry.title,
      body: body,
      excerpt: entry.excerpt,
      seo_title: entry.seo_title,
      seo_description: entry.seo_description,
      featured_image_url: "/images/blog/#{slug}.jpg",
      tags: entry.tags,
      ai_generated: true
    })
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:publish, %{})
    |> Ash.update!(authorize?: false)
  end

  defp read_body(slug), do: File.read!(Path.join(body_dir(), "#{slug}.html"))

  defp body_dir, do: Path.join(:code.priv_dir(:emakola), "platform_blog")

  # Mirrors Emakola.Content.Changes.GenerateSlug so file names and
  # cross-links can be keyed by the slug the create action will produce.
  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s]+/, "-")
    |> String.trim("-")
  end
end
