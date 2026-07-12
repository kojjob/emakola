defmodule Emakola.Inventory do
  @moduledoc """
  The Inventory domain — multi-location stock levels, movements, and the
  single write funnel for every stock change.

  ## Model

    * `Location` — physical stock locations per store; exactly one default.
    * `StockLevel` — quantity per (variant, location), non-negative CHECK.
    * `StockMovement` — insert-only ledger: why stock changed.

  ## The invariant

  `variant.stock_quantity` remains the denormalized fast-read total —
  storefront availability, low-stock alerts, and dashboards keep reading
  it. Every write goes through this module, which adjusts the touched
  level(s) AND the variant total in one transaction under a `FOR UPDATE`
  variant lock, so `total == sum(levels)` always holds. Levels are seeded
  lazily: a variant's first write creates its default-location level from
  the current total (the migration backfilled existing data the same way).

  Sales decrement the default location first, then cascade across active
  locations by stock descending. The variant-level CHECK still guards
  overselling, preserving the checkout `:insufficient_stock` contract.

  Reads (`list_low_stock/2`, `stock_status/1`, `out_of_stock?/1`) keep the
  pre-domain API.
  """

  use Ash.Domain, validate_config_inclusion?: false

  alias Emakola.Inventory.{Location, StockLevel, StockMovement}

  resources do
    resource(Emakola.Inventory.Location)
    resource(Emakola.Inventory.StockLevel)
    resource(Emakola.Inventory.StockMovement)
  end

  require Ash.Query

  @low_stock_threshold 10

  @doc """
  Default low-stock threshold used by the dashboard, alert worker, and
  inventory page. Override per-call by passing a different `threshold`
  to `list_low_stock/2`.
  """
  def low_stock_threshold, do: @low_stock_threshold

  @doc """
  Returns variants in the given store whose stock has fallen below
  `threshold`, ordered by stock ascending. Only includes variants that
  track inventory (`track_inventory == true`).

  Limited to 10 results — this is a "needs attention" widget, not a
  full report.

  Returns `[]` on any read error (rather than raising) since the
  caller is typically the dashboard which renders many widgets in
  parallel and shouldn't crash on one failure.
  """
  @spec list_low_stock(binary(), integer()) :: list(map())
  def list_low_stock(store_id, threshold \\ @low_stock_threshold) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(
           store_id == ^store_id and
             stock_quantity < ^threshold and
             track_inventory == true
         )
         |> Ash.Query.sort(stock_quantity: :asc)
         |> Ash.Query.limit(10)
         |> Ash.Query.load(:product)
         |> Ash.read(authorize?: false) do
      {:ok, variants} -> variants
      _ -> []
    end
  end

  @doc """
  Classifies a variant by stock level.

  Returns one of:
    * `:in_stock` — quantity ≥ threshold (default 10)
    * `:low` — quantity 1–9
    * `:out` — quantity 0 (or negative — treated as out)

  Untracked variants (`track_inventory == false`) always return
  `:in_stock` since the merchant has signalled they don't manage
  stock for this variant.

  Dropshipped variants (those linked to a supplier via `supplier_id`)
  don't track numeric stock — availability is driven by the merchant-set
  `available` flag: `:out` when `available == false`, else `:in_stock`.
  """
  @spec stock_status(map()) :: :in_stock | :low | :out
  def stock_status(%{supplier_id: sid, available: true}) when not is_nil(sid), do: :in_stock
  def stock_status(%{supplier_id: sid, available: false}) when not is_nil(sid), do: :out

  def stock_status(%{track_inventory: false}), do: :in_stock
  def stock_status(%{stock_quantity: q}) when q <= 0, do: :out
  def stock_status(%{stock_quantity: q}) when q < @low_stock_threshold, do: :low
  def stock_status(_variant), do: :in_stock

  @doc """
  Convenience predicate. Equivalent to `stock_status(variant) == :out`.
  """
  @spec out_of_stock?(map()) :: boolean()
  def out_of_stock?(variant), do: stock_status(variant) == :out

  # ── Locations ──────────────────────────────────────────────────

  @doc """
  Returns the store's default location, creating "Main" on first use.
  Safe under races: loser of the partial-unique-index race re-reads.
  """
  def ensure_default_location!(store_id) do
    case default_location(store_id) do
      nil ->
        Location
        |> Ash.Changeset.for_create(:create, %{store_id: store_id, name: "Main", default: true})
        |> Ash.create(authorize?: false)
        |> case do
          {:ok, location} -> location
          # Concurrent creation won the unique index — use theirs.
          {:error, _} -> default_location(store_id) || raise "default location race unresolved"
        end

      location ->
        location
    end
  end

  def create_location(actor, store_id, attrs) do
    with :ok <- ensure_store_access(actor, store_id) do
      Location
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_id,
        name: value(attrs, :name),
        default: false
      })
      |> Ash.create(authorize?: false)
    end
  end

  def list_locations(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      {:ok,
       Location
       |> Ash.Query.filter(store_id == ^store_id)
       |> Ash.Query.sort([{:default, :desc}, {:name, :asc}])
       |> Ash.read!(authorize?: false)}
    end
  end

  def rename_location(actor, store_id, location_id, name) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, location} <- store_location(store_id, location_id) do
      location
      |> Ash.Changeset.for_update(:rename, %{name: name})
      |> Ash.update(authorize?: false)
    end
  end

  def set_default_location(actor, store_id, location_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, location} <- store_location(store_id, location_id) do
      Emakola.Repo.transaction(fn ->
        # Clear first — the partial unique index allows at most one default.
        case default_location(store_id) do
          nil -> :ok
          %{id: ^location_id} -> :ok
          current -> run_update!(current, :clear_default)
        end

        run_update!(location, :set_default)
      end)
      |> normalize_transaction()
    end
  end

  def deactivate_location(actor, store_id, location_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, location} <- store_location(store_id, location_id) do
      cond do
        location.default -> {:error, :default_location}
        location_stock(location_id) > 0 -> {:error, :location_holds_stock}
        true -> {:ok, run_update!(location, :deactivate)}
      end
    end
  end

  # ── Stock writes (the funnel) ──────────────────────────────────

  @doc "Adds stock at a location (receiving). Positive quantities only."
  def restock(variant_id, location_id, quantity, opts \\ [])

  def restock(variant_id, location_id, quantity, opts)
      when is_integer(quantity) and quantity > 0 do
    adjust(variant_id, location_id, quantity, :restock, opts)
  end

  def restock(_variant_id, _location_id, _quantity, _opts), do: {:error, :invalid_quantity}

  @doc """
  Adjusts one location's stock by `delta` (either sign) and the variant
  total with it, recording a movement. Fails atomically when the level
  would go negative.
  """
  def adjust(variant_id, location_id, delta, reason, opts \\ [])
      when is_integer(delta) and delta != 0 do
    Emakola.Repo.transaction(fn ->
      variant = locked_variant!(variant_id)
      level = seeded_level!(variant, location_id)

      with {:ok, _level} <- adjust_level(level, delta),
           {:ok, _variant} <- adjust_total(variant, delta) do
        record_movement!(variant, location_id, delta, reason, opts[:order_id])
        :ok
      else
        {:error, error} -> Emakola.Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, :ok} -> {:ok, :adjusted}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Decrements sold stock: default location first, then active locations by
  stock descending. Raises `Ash.Error.Invalid` (nothing committed) when the
  variant total is insufficient — the contract `Orders.Changes.DecrementStock`
  rescues on.
  """
  def decrement_for_sale!(variant_id, store_id, quantity, order_id)
      when is_integer(quantity) and quantity > 0 do
    {:ok, :ok} =
      Emakola.Repo.transaction(fn ->
        variant = locked_variant!(variant_id)

        # The variant CHECK is the oversell guard: raise → full rollback.
        variant
        |> Ash.Changeset.for_update(:adjust_stock, %{delta: -quantity})
        |> Ash.update!(authorize?: false)

        default = ensure_default_location!(store_id)
        _seeded = seeded_level!(variant, default.id)

        allocation_levels(variant.id, default.id)
        |> allocate(quantity)
        |> Enum.each(fn {level, take} ->
          {:ok, _} = adjust_level(level, -take)
          record_movement!(variant, level.location_id, -take, :sale, order_id)
        end)

        :ok
      end)

    :ok
  end

  @doc "Moves stock between two locations; the variant total is unchanged."
  def transfer(variant_id, from_location_id, to_location_id, quantity)
      when is_integer(quantity) and quantity > 0 do
    if from_location_id == to_location_id do
      {:error, :same_location}
    else
      Emakola.Repo.transaction(fn ->
        variant = locked_variant!(variant_id)
        from = seeded_level!(variant, from_location_id)
        to = seeded_level!(variant, to_location_id)

        with {:ok, _} <- adjust_level(from, -quantity),
             {:ok, _} <- adjust_level(to, quantity) do
          record_movement!(variant, from_location_id, -quantity, :transfer_out, nil)
          record_movement!(variant, to_location_id, quantity, :transfer_in, nil)
          :ok
        else
          {:error, error} -> Emakola.Repo.rollback(error)
        end
      end)
      |> case do
        {:ok, :ok} -> {:ok, :transferred}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc "Stock levels for a variant with locations loaded, default first."
  def levels(variant_id) do
    StockLevel
    |> Ash.Query.filter(variant_id == ^variant_id)
    |> Ash.Query.load(:location)
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(fn level -> {!level.location.default, level.location.name} end)
  end

  @doc """
  All stock levels for a store in one read, keyed by variant id, each
  variant's levels sorted default-location-first (same order as `levels/1`).
  Powers the admin per-location breakdown without an N+1.
  """
  def levels_by_variant(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      {:ok,
       StockLevel
       |> Ash.Query.filter(store_id == ^store_id)
       |> Ash.Query.load(:location)
       |> Ash.read!(authorize?: false)
       |> Enum.group_by(& &1.variant_id)
       |> Map.new(fn {variant_id, levels} ->
         {variant_id,
          Enum.sort_by(levels, fn level -> {!level.location.default, level.location.name} end)}
       end)}
    end
  end

  # ── Internals ──────────────────────────────────────────────────

  defp default_location(store_id) do
    Location
    |> Ash.Query.filter(store_id == ^store_id and default == true)
    |> Ash.read_one!(authorize?: false)
  end

  defp store_location(store_id, location_id) do
    Location
    |> Ash.Query.filter(store_id == ^store_id and id == ^location_id)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> {:error, :not_found}
      location -> {:ok, location}
    end
  end

  defp location_stock(location_id) do
    StockLevel
    |> Ash.Query.filter(location_id == ^location_id)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, &(&1.quantity + &2))
  end

  defp locked_variant!(variant_id) do
    Emakola.Catalog.Variant
    |> Ash.Query.filter(id == ^variant_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  # Lazily creates the level rows for a variant. The FIRST level ever
  # created for a variant is the default location's, seeded from the
  # variant total so the invariant holds from the first write; every
  # other level starts at zero.
  defp seeded_level!(variant, location_id) do
    existing =
      StockLevel
      |> Ash.Query.filter(variant_id == ^variant.id and location_id == ^location_id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!(authorize?: false)

    case existing do
      nil ->
        default = ensure_default_location!(variant.store_id)

        if location_id != default.id do
          # Seed the default first so sum(levels) covers the legacy total.
          _default_level = seeded_level!(variant, default.id)
        end

        seed_quantity =
          if location_id == default.id and no_levels?(variant.id),
            do: Kernel.max(variant.stock_quantity, 0),
            else: 0

        StockLevel
        |> Ash.Changeset.for_create(:create, %{
          store_id: variant.store_id,
          variant_id: variant.id,
          location_id: location_id,
          quantity: seed_quantity
        })
        |> Ash.create!(authorize?: false)

      level ->
        level
    end
  end

  defp no_levels?(variant_id) do
    StockLevel
    |> Ash.Query.filter(variant_id == ^variant_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Enum.empty?()
  end

  defp allocation_levels(variant_id, default_location_id) do
    StockLevel
    |> Ash.Query.filter(variant_id == ^variant_id and quantity > 0)
    |> Ash.Query.load(:location)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read!(authorize?: false)
    |> Enum.filter(& &1.location.active)
    |> Enum.sort_by(fn level ->
      {if(level.location_id == default_location_id, do: 0, else: 1), -level.quantity}
    end)
  end

  defp allocate(levels, quantity) do
    {allocations, _remaining} =
      Enum.reduce(levels, {[], quantity}, fn
        _level, {acc, 0} ->
          {acc, 0}

        level, {acc, remaining} ->
          take = Kernel.min(level.quantity, remaining)
          {[{level, take} | acc], remaining - take}
      end)

    allocations |> Enum.reject(fn {_level, take} -> take == 0 end) |> Enum.reverse()
  end

  defp adjust_level(level, delta) do
    level
    |> Ash.Changeset.for_update(:adjust, %{delta: delta})
    |> Ash.update(authorize?: false)
  end

  defp adjust_total(variant, delta) do
    variant
    |> Ash.Changeset.for_update(:adjust_stock, %{delta: delta})
    |> Ash.update(authorize?: false)
  end

  defp record_movement!(variant, location_id, delta, reason, order_id) do
    StockMovement
    |> Ash.Changeset.for_create(:create, %{
      store_id: variant.store_id,
      variant_id: variant.id,
      location_id: location_id,
      delta: delta,
      reason: reason,
      order_id: order_id
    })
    |> Ash.create!(authorize?: false)
  end

  defp run_update!(record, action) do
    record |> Ash.Changeset.for_update(action, %{}) |> Ash.update!(authorize?: false)
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [_] -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key))

  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
end
