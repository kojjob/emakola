defmodule Emakola.Stores.PageContent do
  @moduledoc """
  Lazy get-or-create for a store's `StorePageContent` row.

  The storefront reads content read-only (`authorize?: false`) and tolerates a
  missing row, falling back to neutral copy. The admin editor calls
  `get_or_create/2` on mount with the merchant actor — that is where the row is
  first materialised. The `:unique_store_page_content` identity keeps it to one
  row per store.
  """

  @doc """
  Returns the store's content row, creating an empty one if it does not exist.

  `opts` are forwarded to both the read and the create — pass `authorize?: false`
  on the storefront path, or `actor: merchant` on the admin path.
  """
  def get_or_create(store_id, opts \\ []) when is_binary(store_id) do
    # Authorized (actor) reads of a tenant-scoped resource are denied unless the
    # query carries the tenant — ActorHasStoreAccess checks the actor's
    # membership against query.tenant. Set it to the store so admin reads pass;
    # harmless on the storefront's authorize?: false path.
    opts = Keyword.put_new(opts, :tenant, store_id)
    read_opts = Keyword.put(opts, :not_found_error?, false)

    case Emakola.Stores.get_page_content(store_id, read_opts) do
      {:ok, nil} -> Emakola.Stores.create_page_content(%{store_id: store_id}, opts)
      {:ok, content} -> {:ok, content}
      {:error, _} = error -> error
    end
  end
end
