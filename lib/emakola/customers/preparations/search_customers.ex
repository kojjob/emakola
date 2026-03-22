defmodule Emakola.Customers.Preparations.SearchCustomers do
  @moduledoc """
  Ash preparation for searching customers by name or email within a store.

  Uses ILIKE for case-insensitive partial matching. Extracted into a module
  because `Ash.Query.filter` is a macro and cannot be used inside anonymous
  functions within the Ash DSL `actions do...end` blocks.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    store_id = Ash.Query.get_argument(query, :store_id)
    search_term = Ash.Query.get_argument(query, :query)

    query
    |> Ash.Query.filter(
      store_id == ^store_id and
        (contains(name, ^search_term) or
           contains(string_downcase(email), ^String.downcase(search_term)))
    )
    |> Ash.Query.sort(inserted_at: :desc)
  end
end
