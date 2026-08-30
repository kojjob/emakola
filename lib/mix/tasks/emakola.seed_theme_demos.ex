defmodule Mix.Tasks.Emakola.SeedThemeDemos do
  @moduledoc """
  Seeds one `<theme>-demo` store per registered theme.

  Each store gets a pure-default theme_config (`%{"theme" => id}`) and a small
  identical catalogue, so `/s/<theme>-demo` shows the theme's designed look
  with no merchant overrides deep-merged on top.

  Idempotent and non-destructive: any slug that already exists is skipped
  untouched (including the hand-built heirloom-demo showcase).

  Usage: mix emakola.seed_theme_demos

  Dev-only tooling — demo stores are recreatable after `mix ecto.reset`.
  """
  use Mix.Task

  alias Emakola.Themes.ThemeResolver

  require Ash.Query

  @shortdoc "Seed one <theme>-demo store per registered theme"

  @categories [
    %{
      key: :fashion,
      name: "Fashion & Textiles",
      description: "Handwoven cloth and made-in-Ghana fashion"
    },
    %{key: :pantry, name: "Pantry Staples", description: "Everyday Ghanaian kitchen essentials"},
    %{
      key: :accessories,
      name: "Accessories",
      description: "Handcrafted bags and finishing touches"
    }
  ]

  # Images are the same local files priv/static already ships for the main seeds.
  @products [
    %{
      category: :fashion,
      title: "Royal Adweneasa Kente Cloth",
      price: 85_000,
      compare_at_price: 95_000,
      stock: 8,
      image: "/images/seed/kente-kingdom/kente-adweneasa-1.jpg",
      extra_images: [
        "/images/seed/kente-kingdom/kente-stole-1.jpg",
        "/images/seed/kente-kingdom/fusion-dress-1.jpg",
        "/images/seed/kente-kingdom/kente-clutch-1.jpg",
        "/images/seed/kente-kingdom/fugu-smock-1.jpg"
      ],
      alt: "Royal Adweneasa Kente cloth in gold and green",
      tags: ["kente", "handwoven"]
    },
    %{
      category: :fashion,
      title: "Ewe Kente Graduation Stole",
      price: 25_000,
      stock: 35,
      image: "/images/seed/kente-kingdom/kente-stole-1.jpg",
      alt: "Ewe Kente graduation stole in multicolor",
      tags: ["kente", "graduation"]
    },
    %{
      category: :fashion,
      title: "Northern Fugu Smock",
      price: 32_000,
      stock: 12,
      image: "/images/seed/kente-kingdom/fugu-smock-1.jpg",
      alt: "Hand-stitched northern fugu smock",
      tags: ["fugu", "smock"]
    },
    %{
      category: :fashion,
      title: "Kente Fusion Dress",
      price: 45_000,
      compare_at_price: 52_000,
      stock: 9,
      image: "/images/seed/kente-kingdom/fusion-dress-1.jpg",
      alt: "Modern dress with Kente accents",
      tags: ["fashion", "kente"]
    },
    %{
      category: :accessories,
      title: "Kente Clutch Bag",
      price: 18_000,
      stock: 20,
      image: "/images/seed/kente-kingdom/kente-clutch-1.jpg",
      alt: "Kente clutch bag with leather trim",
      tags: ["bag", "kente"]
    },
    %{
      category: :pantry,
      title: "Jollof Spice Mix",
      price: 2_500,
      stock: 60,
      image: "/images/seed/accra-fresh/jollof-spice-1.jpg",
      extra_images: [
        "/images/seed/accra-fresh/shito-1.jpg",
        "/images/seed/accra-fresh/rice-1.jpg"
      ],
      alt: "Jar of jollof spice mix",
      tags: ["spice", "jollof"]
    },
    %{
      category: :pantry,
      title: "Shito Pepper Sauce",
      price: 3_500,
      stock: 45,
      image: "/images/seed/accra-fresh/shito-1.jpg",
      alt: "Jar of black shito pepper sauce",
      tags: ["shito", "sauce"]
    },
    %{
      category: :pantry,
      title: "Crunchy Plantain Chips",
      price: 1_500,
      stock: 80,
      image: "/images/seed/accra-fresh/plantain-chips-1.jpg",
      extra_images: [
        "/images/seed/accra-fresh/groundnuts-1.jpg",
        "/images/seed/accra-fresh/dawadawa-1.jpg",
        "/images/seed/accra-fresh/jollof-spice-1.jpg"
      ],
      alt: "Bag of crunchy plantain chips",
      tags: ["snack", "plantain"]
    },
    %{
      category: :pantry,
      title: "Roasted Groundnuts",
      price: 1_200,
      stock: 70,
      image: "/images/seed/accra-fresh/groundnuts-1.jpg",
      alt: "Roasted groundnuts in a bowl",
      tags: ["snack", "groundnut"]
    },
    %{
      category: :pantry,
      title: "Local Perfumed Rice 5kg",
      price: 9_000,
      stock: 30,
      image: "/images/seed/accra-fresh/rice-1.jpg",
      alt: "Bag of local perfumed rice",
      tags: ["rice", "staple"]
    },
    %{
      category: :pantry,
      title: "Dawadawa Seasoning",
      price: 2_000,
      stock: 40,
      image: "/images/seed/accra-fresh/dawadawa-1.jpg",
      alt: "Dawadawa seasoning balls",
      tags: ["dawadawa", "seasoning"]
    }
  ]

  def run(_argv) do
    Mix.Task.run("app.start")
    seed()
  end

  @doc false
  def seed do
    Enum.each(ThemeResolver.theme_ids(), fn theme_id ->
      slug = "#{theme_id}-demo"

      if store_exists?(slug) do
        Mix.shell().info("  #{slug} already exists — skipped")
      else
        create_demo_store(theme_id, slug)
        Mix.shell().info("  #{slug} created")
      end
    end)

    :ok
  end

  defp store_exists?(slug) do
    Emakola.Stores.Store
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.exists?(authorize?: false)
  end

  defp create_demo_store(theme_id, slug) do
    store =
      create!(Emakola.Stores.Store, :create, %{
        name: "#{theme_display_name(theme_id)} Demo",
        slug: slug,
        currency: "GHS"
      })

    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => theme_id}},
      authorize?: false
    )
    |> Ash.update!()

    store
    |> Ash.Changeset.for_update(
      :update_settings,
      %{
        description: "Demo store showcasing the #{theme_display_name(theme_id)} theme.",
        whatsapp_number: "+233244000000",
        city: "Accra",
        region: "Greater Accra"
      },
      authorize?: false
    )
    |> Ash.update!()

    categories = create_categories(store)

    Enum.with_index(@products, fn product, index ->
      create_product(store, slug, categories, product, index)
    end)
  end

  defp create_categories(store) do
    @categories
    |> Enum.with_index()
    |> Map.new(fn {%{key: key, name: name, description: description}, position} ->
      category =
        create!(Emakola.Catalog.Category, :create, %{
          name: name,
          description: description,
          position: position,
          store_id: store.id
        })

      {key, category}
    end)
  end

  defp create_product(store, slug, categories, spec, index) do
    product =
      create!(Emakola.Catalog.Product, :create, %{
        title: spec.title,
        description: "#{spec.title} — part of the shared demo catalogue.",
        tags: spec.tags,
        store_id: store.id,
        category_id: categories[spec.category].id
      })

    create!(Emakola.Catalog.Variant, :create, %{
      product_id: product.id,
      store_id: store.id,
      price: spec.price,
      compare_at_price: spec[:compare_at_price],
      sku: "#{slug}-#{index}",
      stock_quantity: spec.stock
    })

    # Every image on the spec, in order — `spec.image` leads and `extra_images`
    # follow. A product-detail gallery only exists above one photo, so a
    # catalogue where every product has exactly one leaves the thumbnail rail
    # untestable and unseeable.
    # `:position` is not an accepted input on Image.create — it defaults to 0
    # and `has_many :images` sorts `position: :asc, inserted_at: :asc`, so
    # insertion order is what puts spec.image first in the gallery.
    for url <- [spec.image | spec[:extra_images] || []] do
      create!(Emakola.Catalog.Image, :create, %{
        product_id: product.id,
        store_id: store.id,
        url: url,
        alt_text: spec.alt,
        content_type: "image/jpeg",
        file_size_bytes: 300_000
      })
    end

    product
    |> Ash.Changeset.for_update(:activate, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp create!(resource, action, params) do
    resource
    |> Ash.Changeset.for_create(action, params, authorize?: false)
    |> Ash.create!()
  end

  defp theme_display_name(theme_id) do
    theme_id |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
  end
end
