defmodule Emakola.Content.RecipeMeta do
  @moduledoc """
  Recipe metadata resource for the Content domain.

  Stores structured recipe data (prep/cook time, servings, difficulty,
  ingredients, instructions) linked one-to-one with a Post of type :recipe.
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

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

    attribute :prep_time, :integer do
      public?(true)
    end

    attribute :cook_time, :integer do
      public?(true)
    end

    attribute :servings, :integer do
      public?(true)
    end

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

    policy always() do
      authorize_if(always())
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :post_id,
        :prep_time,
        :cook_time,
        :servings,
        :difficulty,
        :ingredients,
        :instructions
      ])
    end

    update :update do
      accept([:prep_time, :cook_time, :servings, :difficulty, :ingredients, :instructions])
    end

    read :get_by_post do
      argument(:post_id, :uuid, allow_nil?: false)

      filter(expr(post_id == ^arg(:post_id)))
    end
  end
end
