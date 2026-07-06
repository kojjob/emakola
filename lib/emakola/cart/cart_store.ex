defmodule Emakola.Cart.CartStore do
  @moduledoc """
  Postgres-backed session cart storage (drop-in replacement for the old
  node-local ETS store — same module name, same API, same semantics).

  Stores cart items keyed by `(session_id, store_id)`, one `cart_items` row per
  `(session_id, store_id, variant_id)`. Carts are scoped per store: a single
  browser session keeps a separate cart for each store it visits, so items
  added across different storefronts never merge. Being in Postgres, carts
  survive deploys and are shared across machines, so the app can scale
  horizontally.

  ## Cart item shape (as returned by `get_cart/2`)

      %{
        variant_id: uuid,
        product_title: string,
        variant_info: string,
        unit_price: integer (minor units),
        quantity: integer,
        sku: string,
        image_url: string | nil,
        stored_at: DateTime.t()
      }

  ## Error behavior

  Like the ETS version, the happy path always returns `:ok` / `[]` / `0`
  and never raises for missing sessions or variants. Unlike ETS, a genuine
  database outage will raise — deliberately not rescued: callers run inside
  LiveViews where a DB outage already breaks the whole request, and silent
  rescues are an anti-pattern in this codebase.
  """

  import Ecto.Query

  alias Emakola.Cart.CartItem
  alias Emakola.Repo

  @max_quantity 10

  # -- Public API --

  @doc "Returns the list of cart items for the given session + store, or [] if none."
  @spec get_cart(String.t(), String.t()) :: [map()]
  def get_cart(session_id, store_id) do
    from(c in CartItem,
      where: c.session_id == ^session_id and c.store_id == ^store_id,
      order_by: [asc: c.inserted_at, asc: c.id]
    )
    |> Repo.all()
    |> Enum.map(&to_item_map/1)
  end

  @doc """
  Adds an item to the cart. If an item with the same variant_id already exists,
  its quantity is incremented (capped at #{@max_quantity}) and its snapshot
  fields are refreshed from the new item map.
  """
  @spec add_item(String.t(), String.t(), map()) :: :ok
  def add_item(session_id, store_id, item) do
    now = DateTime.utc_now()

    row = %{
      session_id: session_id,
      store_id: store_id,
      variant_id: item.variant_id,
      quantity: item.quantity,
      product_title: item.product_title,
      variant_info: item.variant_info,
      unit_price: item.unit_price,
      sku: item.sku,
      image_url: Map.get(item, :image_url),
      inserted_at: now,
      updated_at: now
    }

    on_conflict =
      from(c in CartItem,
        update: [
          set: [
            quantity: fragment("LEAST(? + EXCLUDED.quantity, ?)", c.quantity, ^@max_quantity),
            product_title: fragment("EXCLUDED.product_title"),
            variant_info: fragment("EXCLUDED.variant_info"),
            unit_price: fragment("EXCLUDED.unit_price"),
            sku: fragment("EXCLUDED.sku"),
            image_url: fragment("EXCLUDED.image_url"),
            updated_at: fragment("EXCLUDED.updated_at")
          ]
        ]
      )

    Repo.insert_all(CartItem, [row],
      on_conflict: on_conflict,
      conflict_target: [:session_id, :store_id, :variant_id]
    )

    :ok
  end

  @doc """
  Updates the quantity of an item identified by variant_id.
  If quantity <= 0, the item is removed. Quantity is capped at #{@max_quantity}.
  """
  @spec update_quantity(String.t(), String.t(), String.t(), integer()) :: :ok
  def update_quantity(session_id, store_id, variant_id, quantity) do
    if quantity <= 0 do
      remove_item(session_id, store_id, variant_id)
    else
      item_query(session_id, store_id, variant_id)
      |> Repo.update_all(
        set: [quantity: min(quantity, @max_quantity), updated_at: DateTime.utc_now()]
      )

      :ok
    end
  end

  @doc "Removes the item with the given variant_id from the store's cart."
  @spec remove_item(String.t(), String.t(), String.t()) :: :ok
  def remove_item(session_id, store_id, variant_id) do
    item_query(session_id, store_id, variant_id) |> Repo.delete_all()
    :ok
  end

  @doc "Empties the cart for the given session + store."
  @spec clear_cart(String.t(), String.t()) :: :ok
  def clear_cart(session_id, store_id) do
    from(c in CartItem, where: c.session_id == ^session_id and c.store_id == ^store_id)
    |> Repo.delete_all()

    :ok
  end

  @doc "Returns the total item count (sum of quantities) for the session + store."
  @spec cart_count(String.t(), String.t()) :: non_neg_integer()
  def cart_count(session_id, store_id) do
    from(c in CartItem,
      where: c.session_id == ^session_id and c.store_id == ^store_id,
      select: coalesce(sum(c.quantity), 0)
    )
    |> Repo.one()
  end

  @doc """
  Removes all carts whose most recently touched item is older than
  `max_age_seconds` ago (newest-item semantics: one fresh item keeps the
  whole cart alive). Each `(session_id, store_id)` cart expires independently.
  Called periodically by `Emakola.Cart.CartCleanupWorker`.
  """
  @spec cleanup_expired(pos_integer()) :: :ok
  def cleanup_expired(max_age_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_seconds, :second)

    expired_carts =
      from(c in CartItem,
        group_by: [c.session_id, c.store_id],
        having: max(c.updated_at) < ^cutoff,
        select: %{session_id: c.session_id, store_id: c.store_id}
      )

    from(c in CartItem,
      join: e in subquery(expired_carts),
      on: c.session_id == e.session_id and c.store_id == e.store_id
    )
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Compatibility no-op. The ETS-backed implementation created its table here;
  storage now lives in Postgres (`cart_items`), so there is nothing to set up.
  Kept because existing callers still invoke it.
  """
  @spec init() :: :ok
  def init, do: :ok

  # -- Helpers --

  defp item_query(session_id, store_id, variant_id) do
    from(c in CartItem,
      where:
        c.session_id == ^session_id and c.store_id == ^store_id and c.variant_id == ^variant_id
    )
  end

  defp to_item_map(%CartItem{} = c) do
    %{
      variant_id: c.variant_id,
      product_title: c.product_title,
      variant_info: c.variant_info,
      unit_price: c.unit_price,
      quantity: c.quantity,
      sku: c.sku,
      image_url: c.image_url,
      stored_at: c.updated_at
    }
  end
end
