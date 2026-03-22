defmodule Emakola.Cart.CartStore do
  @moduledoc """
  ETS-backed session cart storage.

  Stores cart items keyed by session_id. Each session maps to a list of
  cart item maps. Items include a `stored_at` timestamp for expiry cleanup.

  The ETS table `:cart_store` must be created before this module is used —
  it is initialized in `Emakola.Application.start/2`.

  ## Cart item shape

      %{
        variant_id: uuid,
        product_title: string,
        variant_info: string,
        unit_price: integer (minor units),
        quantity: integer,
        sku: string,
        stored_at: DateTime.t()
      }
  """

  @table :cart_store
  @max_quantity 10

  # -- Public API --

  @doc "Returns the list of cart items for the given session, or [] if none."
  @spec get_cart(String.t()) :: [map()]
  def get_cart(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, items}] -> items
      [] -> []
    end
  end

  @doc """
  Adds an item to the cart. If an item with the same variant_id already exists,
  its quantity is incremented (capped at #{@max_quantity}).
  """
  @spec add_item(String.t(), map()) :: :ok
  def add_item(session_id, item) do
    cart = get_cart(session_id)
    existing_index = Enum.find_index(cart, &(&1.variant_id == item.variant_id))

    new_cart =
      if existing_index do
        List.update_at(cart, existing_index, fn existing ->
          %{existing | quantity: min(existing.quantity + item.quantity, @max_quantity)}
        end)
      else
        cart ++ [Map.put(item, :stored_at, DateTime.utc_now())]
      end

    :ets.insert(@table, {session_id, new_cart})
    :ok
  end

  @doc """
  Updates the quantity of an item identified by variant_id.
  If quantity <= 0, the item is removed. Quantity is capped at #{@max_quantity}.
  """
  @spec update_quantity(String.t(), String.t(), integer()) :: :ok
  def update_quantity(session_id, variant_id, quantity) do
    cart = get_cart(session_id)

    new_cart =
      if quantity <= 0 do
        Enum.reject(cart, &(&1.variant_id == variant_id))
      else
        Enum.map(cart, fn item ->
          if item.variant_id == variant_id do
            %{item | quantity: min(quantity, @max_quantity)}
          else
            item
          end
        end)
      end

    :ets.insert(@table, {session_id, new_cart})
    :ok
  end

  @doc "Removes the item with the given variant_id from the cart."
  @spec remove_item(String.t(), String.t()) :: :ok
  def remove_item(session_id, variant_id) do
    cart = get_cart(session_id)
    new_cart = Enum.reject(cart, &(&1.variant_id == variant_id))
    :ets.insert(@table, {session_id, new_cart})
    :ok
  end

  @doc "Empties the cart for the given session."
  @spec clear_cart(String.t()) :: :ok
  def clear_cart(session_id) do
    :ets.delete(@table, session_id)
    :ok
  end

  @doc "Returns the total item count (sum of quantities) for the session."
  @spec cart_count(String.t()) :: non_neg_integer()
  def cart_count(session_id) do
    get_cart(session_id)
    |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)
  end

  @doc """
  Removes all cart entries whose most recent item `stored_at` is older
  than `max_age_seconds` ago. Called periodically for cleanup.
  """
  @spec cleanup_expired(pos_integer()) :: :ok
  def cleanup_expired(max_age_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_seconds, :second)

    :ets.tab2list(@table)
    |> Enum.each(fn {session_id, items} ->
      case items do
        [] ->
          :ets.delete(@table, session_id)

        _ ->
          newest = Enum.max_by(items, & &1.stored_at, DateTime)

          if DateTime.compare(newest.stored_at, cutoff) == :lt do
            :ets.delete(@table, session_id)
          end
      end
    end)

    :ok
  end

  @doc "Ensures the ETS table exists. Called from Application.start/2."
  @spec init() :: :ok
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end
end
