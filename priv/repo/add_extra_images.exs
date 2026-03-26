# Script to add extra images to existing products so the gallery carousel works.
# Run with: mix run priv/repo/add_extra_images.exs

alias Emakola.Catalog.{Product, Image}
require Ash.Query

IO.puts("Adding extra images to Kente Kingdom products...")

# Find the store
require Ash.Query

store =
  Emakola.Accounts.Store
  |> Ash.Query.filter(slug == "kente-kingdom")
  |> Ash.read_one!()

# Get all active products for this store
products =
  Product
  |> Ash.Query.filter(store_id == ^store.id and status == :active)
  |> Ash.Query.load(:images)
  |> Ash.read!()

# For each product, copy its first image with different alt text to simulate multiple images.
# In production, these would be actual different photos.
for product <- products do
  existing_images = product.images || []
  first_url = if existing_images != [], do: List.first(existing_images).url, else: nil

  if first_url && length(existing_images) < 3 do
    # Add 2 more images using the same URL (simulating additional angles)
    for i <- 2..3 do
      Emakola.Catalog.Image
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        store_id: store.id,
        url: first_url,
        alt_text: "#{product.title} - angle #{i}",
        content_type: "image/jpeg",
        file_size_bytes: 350_000 + i * 10_000
      })
      |> Ash.create!()
    end

    IO.puts("  Added 2 images to: #{product.title}")
  else
    IO.puts("  Skipped: #{product.title} (#{length(existing_images)} images)")
  end
end

IO.puts("Done! All products now have multiple images.")
