defmodule Emakola.Content.RecipeMeta do
  @moduledoc """
  Stub resource for recipe metadata on content posts.

  Full implementation will be added in a subsequent task.
  """

  use Ash.Resource,
    domain: Emakola.Content,
    data_layer: :embedded

  attributes do
    uuid_primary_key(:id)
  end
end
