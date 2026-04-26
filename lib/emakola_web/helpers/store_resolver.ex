defmodule EmakolaWeb.Helpers.StoreResolver do
  @moduledoc """
  Resolves a store from its URL slug.

  Used by all storefront LiveViews in mount/3 to load the store
  from the :store_slug path parameter.
  """

  require Ash.Query

  @doc """
  Looks up a store by its slug.

  Returns `{:ok, store}` or `{:error, :not_found}`.
  """
  @spec resolve(String.t()) :: {:ok, Emakola.Stores.Store.t()} | {:error, :not_found}
  def resolve(slug) when is_binary(slug) do
    case Emakola.Stores.Store
         |> Ash.Query.filter(slug == ^slug)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, store} -> {:ok, store}
      {:error, _} -> {:error, :not_found}
    end
  end
end
