defmodule Emakola.Stores.DemoPurge do
  @moduledoc """
  Deletes demo/test stores and their entire object graph. Built to clean the
  seeded demo merchants out of production before real customers arrive.

  Usage (production, via the release):

      /app/bin/emakola rpc "Emakola.Stores.DemoPurge.preview(~w(kente-kingdom accra-fresh))"
      /app/bin/emakola rpc "Emakola.Stores.DemoPurge.execute(~w(kente-kingdom accra-fresh))"

  Design constraints this module answers to:

    * A store is referenced by ~55 tables, only some with `ON DELETE CASCADE`,
      and some only transitively (`reseller_listing_images -> images`,
      `partner_credit_repayments -> payments`). Rather than hand-maintain that
      list — which would silently rot as resources are added — the deletion set
      is discovered at runtime from `pg_constraint`: the FK closure of the root
      rows, deleted children-first in topological order, in ONE transaction.
      Anything unforeseen aborts the whole run loudly; nothing partial survives.

    * Images must be destroyed through Ash, never SQL: the resource's destroy
      runs `DeleteImageFiles`, which enqueues `StorageCleanupWorker` to delete
      the bucket files. A SQL delete would orphan the files in object storage.

    * A merchant is deleted only when every membership they had was in a purged
      store — a merchant who also owns a real store always survives.

  `preview/1` runs the same discovery and reports row counts without deleting.
  """

  require Ash.Query

  alias Emakola.Repo

  @doc "What `execute/1` would delete, without deleting it."
  def preview(slugs) do
    with {:ok, stores} <- resolve(slugs) do
      store_ids = Enum.map(stores, & &1.id)
      plan = deletion_plan("stores", store_ids)

      {:ok,
       %{
         stores: Enum.map(stores, &%{slug: &1.slug, id: &1.id}),
         row_counts: count_rows(plan, store_ids),
         merchants_deleted: length(sole_merchant_ids(store_ids))
       }}
    end
  end

  @doc "Deletes the named stores, their graphs, and merchants left with no store."
  def execute(slugs) do
    with {:ok, stores} <- resolve(slugs) do
      store_ids = Enum.map(stores, & &1.id)
      plan = deletion_plan("stores", store_ids)
      row_counts = count_rows(plan, store_ids)
      doomed_merchants = sole_merchant_ids(store_ids)

      {:ok, _} =
        Repo.transaction(fn ->
          run_plan(plan, store_ids)

          if doomed_merchants != [] do
            run_plan(deletion_plan("merchants", doomed_merchants), doomed_merchants)
          end
        end)

      {:ok,
       %{
         stores: Enum.map(stores, &%{slug: &1.slug, id: &1.id}),
         row_counts: row_counts,
         merchants_deleted: length(doomed_merchants)
       }}
    end
  end

  # ── Root resolution ──────────────────────────────────────────────

  defp resolve([]), do: {:error, :no_slugs}

  defp resolve(slugs) when is_list(slugs) do
    stores =
      Emakola.Stores.Store
      |> Ash.Query.filter(slug in ^slugs)
      |> Ash.read!(authorize?: false)

    case slugs -- Enum.map(stores, & &1.slug) do
      [] -> {:ok, stores}
      missing -> {:error, {:unknown_slugs, missing}}
    end
  end

  # Merchants whose every membership points at a purged store. Computed BEFORE
  # any deletion, from the memberships as they stand.
  defp sole_merchant_ids(store_ids) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        select m.id from merchants m
        where exists (select 1 from store_memberships sm
                      where sm.merchant_id = m.id and sm.store_id = any($1))
          and not exists (select 1 from store_memberships sm
                          where sm.merchant_id = m.id and not (sm.store_id = any($1)))
        """,
        [dump_ids(store_ids)]
      )

    # Raw query rows carry uuids as 16-byte binaries; cast back to strings so
    # they take the same dump_ids path as ids that came from Ash structs.
    Enum.map(rows, fn [id] -> Ecto.UUID.cast!(id) end)
  end

  # ── Deletion plan: FK closure + topological order ────────────────

  # Returns an ordered list of {table, predicate_sql} — children first, roots
  # last. Every predicate takes the root id array as $1.
  defp deletion_plan(root_table, _ids) do
    edges = fk_edges()

    predicates = build_predicates(root_table, edges)
    ordered = topo_order(Map.keys(predicates), edges)

    Enum.map(ordered, fn table -> {table, predicates[table]} end)
  end

  # Every single-column FK in the schema: {child_table, child_column, parent_table}.
  defp fk_edges do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        """
        select c.conrelid::regclass::text,
               a.attname,
               c.confrelid::regclass::text
        from pg_constraint c
        join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
        where c.contype = 'f' and array_length(c.conkey, 1) = 1
        """,
        []
      )

    Enum.map(rows, fn [child, col, parent] -> {child, col, parent} end)
  end

  # BFS out from the root: any table with an FK into an affected table becomes
  # affected, with a predicate selecting exactly the rows that reference doomed
  # rows. A table reachable through several paths gets its clauses OR-ed
  # (supply_connections references stores through two different columns).
  defp build_predicates(root_table, edges) do
    root_pred = "id = any($1)"
    build_predicates(%{root_table => [root_pred]}, [root_table], edges)
  end

  defp build_predicates(preds, [], _edges) do
    Map.new(preds, fn {table, clauses} ->
      {table, clauses |> Enum.uniq() |> Enum.join(" or ")}
    end)
  end

  defp build_predicates(preds, [parent | queue], edges) do
    parent_pred = preds[parent] |> Enum.uniq() |> Enum.join(" or ")

    {preds, queue} =
      edges
      |> Enum.filter(fn {child, _col, p} -> p == parent and child != parent end)
      |> Enum.reduce({preds, queue}, fn {child, col, _p}, {preds, queue} ->
        clause = "#{col} in (select id from #{parent} where #{parent_pred})"

        cond do
          # First visit: adopt the clause and explore the child's own children.
          not Map.has_key?(preds, child) ->
            {Map.put(preds, child, [clause]), queue ++ [child]}

          # Seen before via another path: OR the new clause in. Not re-queued —
          # every FK edge is processed exactly once, so this terminates.
          clause not in preds[child] ->
            {Map.update!(preds, child, &[clause | &1]), queue}

          true ->
            {preds, queue}
        end
      end)

    build_predicates(preds, queue, edges)
  end

  # Children before parents. Kahn's algorithm over the FK edges between
  # affected tables; self-references are fine (Postgres checks immediate FK
  # constraints at end-of-statement, and each table is one DELETE). A genuine
  # cycle between two tables would leave leftovers — appended last so the
  # transaction fails loudly rather than silently skipping them.
  defp topo_order(tables, edges) do
    table_set = MapSet.new(tables)

    relevant =
      Enum.filter(edges, fn {child, _col, parent} ->
        child != parent and MapSet.member?(table_set, child) and
          MapSet.member?(table_set, parent)
      end)

    do_topo(tables, relevant, [])
  end

  defp do_topo([], _edges, acc), do: Enum.reverse(acc)

  defp do_topo(remaining, edges, acc) do
    # A table is deletable when no REMAINING table still references it... the
    # other way around: delete tables that nothing remaining depends on being
    # kept — i.e. tables that are not the PARENT of any remaining child.
    parents = MapSet.new(edges, fn {_child, _col, parent} -> parent end)

    {ready, blocked} = Enum.split_with(remaining, &(not MapSet.member?(parents, &1)))

    case ready do
      [] ->
        # Cycle: emit the rest in arbitrary order and let the transaction shout.
        Enum.reverse(acc, blocked)

      _ ->
        gone = MapSet.new(ready)

        edges =
          Enum.reject(edges, fn {child, _col, _parent} -> MapSet.member?(gone, child) end)

        do_topo(blocked, edges, Enum.reverse(ready) ++ acc)
    end
  end

  # ── Execution ─────────────────────────────────────────────────────

  defp run_plan(plan, ids) do
    dumped = dump_ids(ids)

    Enum.each(plan, fn
      {"images", predicate} ->
        destroy_images_via_ash(predicate, dumped)

      {table, predicate} ->
        Ecto.Adapters.SQL.query!(Repo, "delete from #{table} where #{predicate}", [dumped])
    end)
  end

  # The one delete with a side effect: DeleteImageFiles enqueues bucket cleanup.
  defp destroy_images_via_ash(predicate, dumped) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(Repo, "select id from images where #{predicate}", [dumped])

    ids = Enum.map(rows, fn [id] -> Ecto.UUID.cast!(id) end)

    Emakola.Catalog.Image
    |> Ash.Query.filter(id in ^ids)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))
  end

  defp count_rows(plan, ids) do
    dumped = dump_ids(ids)

    plan
    |> Map.new(fn {table, predicate} ->
      %{rows: [[n]]} =
        Ecto.Adapters.SQL.query!(
          Repo,
          "select count(*) from #{table} where #{predicate}",
          [dumped]
        )

      {table, n}
    end)
    |> Enum.reject(fn {_table, n} -> n == 0 end)
    |> Map.new()
  end

  defp dump_ids(ids), do: Enum.map(ids, &Ecto.UUID.dump!/1)
end
