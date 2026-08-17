defmodule Mix.Tasks.Emakola.SeedThemeDemosTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Catalog.Category
  alias Emakola.Catalog.Image
  alias Emakola.Catalog.Product
  alias Emakola.Stores.Store
  alias Emakola.Themes.ThemeResolver

  require Ash.Query

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  defp get_store(slug) do
    Store
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one!(authorize?: false)
  end

  defp count(resource, store_id) do
    resource
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.count!(authorize?: false)
  end

  test "creates a live demo store with pure-default theme config for every registered theme" do
    Mix.Tasks.Emakola.SeedThemeDemos.seed()

    for theme_id <- ThemeResolver.theme_ids() do
      store = get_store("#{theme_id}-demo")
      assert store, "expected #{theme_id}-demo store to exist"

      # Pure defaults: only the theme key, so screenshots show the theme's
      # designed look, not merchant overrides deep-merged on top.
      assert store.theme_config == %{"theme" => theme_id}
      assert Store.live?(store)

      assert count(Category, store.id) >= 3

      active_products =
        Product
        |> Ash.Query.filter(store_id == ^store.id and status == :active)
        |> Ash.count!(authorize?: false)

      assert active_products >= 8, "#{theme_id}-demo needs products for sections to render"
      assert count(Image, store.id) >= 8, "#{theme_id}-demo products need images"
    end
  end

  test "re-running creates no duplicate stores or products" do
    Mix.Tasks.Emakola.SeedThemeDemos.seed()
    store = get_store("market-demo")
    products_before = count(Product, store.id)

    Mix.Tasks.Emakola.SeedThemeDemos.seed()

    stores =
      Store
      |> Ash.Query.filter(slug == "market-demo")
      |> Ash.read!(authorize?: false)

    assert length(stores) == 1
    assert count(Product, store.id) == products_before
  end

  test "never mutates a demo store that already exists" do
    hand_built_config = %{"theme" => "heirloom", "hero" => %{"title" => "Hand-built showcase"}}

    create_store!(%{slug: "heirloom-demo", name: "Heirloom Showcase"})
    |> Ash.Changeset.for_update(:update, %{theme_config: hand_built_config})
    |> Ash.update!(authorize?: false)

    Mix.Tasks.Emakola.SeedThemeDemos.seed()

    reloaded = get_store("heirloom-demo")
    assert reloaded.theme_config == hand_built_config
    assert count(Product, reloaded.id) == 0
  end
end
