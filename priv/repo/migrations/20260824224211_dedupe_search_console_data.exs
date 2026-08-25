defmodule Emakola.Repo.Migrations.DedupeSearchConsoleData do
  @moduledoc """
  One Search Console row per keyword + page, instead of one per nightly sync.

  Search Console is queried for a rolling 28-day window aggregated by
  (query, page) — there is no date dimension — so every run returned the same
  rows with a fresh `fetched_at` and stacked another copy. Production had the
  same keyword twelve times over.

  `nulls_distinct: false` is load-bearing: `page` and `organisation_id` are
  both nullable and Postgres treats every NULL as distinct by default, so an
  ordinary unique index would let NULL-page rows keep duplicating.

  Existing duplicates are collapsed first, newest kept — the index cannot be
  created while they are still there.
  """

  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM search_console_data a
    USING search_console_data b
    WHERE a.id <> b.id
      AND a.keyword IS NOT DISTINCT FROM b.keyword
      AND a.page IS NOT DISTINCT FROM b.page
      AND a.organisation_id IS NOT DISTINCT FROM b.organisation_id
      AND (a.fetched_at, a.id) < (b.fetched_at, b.id)
    """)

    create unique_index(:search_console_data, [:keyword, :page, :organisation_id],
             name: "search_console_data_unique_keyword_page_index",
             nulls_distinct: false
           )
  end

  def down do
    drop_if_exists unique_index(:search_console_data, [:keyword, :page, :organisation_id],
                     name: "search_console_data_unique_keyword_page_index"
                   )
  end
end
