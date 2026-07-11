defmodule Emakola.Content.RecipeMetaTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

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
        |> Ash.read(authorize?: false)

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
        |> Ash.update(authorize?: false)

      assert updated.servings == 6
      assert length(updated.ingredients) == 1
    end
  end
end
