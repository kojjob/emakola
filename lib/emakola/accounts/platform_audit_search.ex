defmodule Emakola.Accounts.PlatformAuditSearch do
  @moduledoc """
  The audit ledger's filter model and the queries behind it.

  A search is four fields, all carried in the page URL: `family` (see
  `PlatformAuditFamilies`), `severity`, `range` (a rolling window ending
  now) and `q`, a text search over the actor's email or name, the ip, and
  the metadata as text. `from_params/1` is the only way user input becomes
  a search, so every field passes an allowlist.

  `page/2` reads through the resource's keyset-paginated `:list` action;
  `counts/1` is one grouped Ecto query for the family chips, so the same
  conditions are spelled twice below (Ash for the rows, Ecto for the
  counts). Keep the two `filter_*`/`where_*` pairs in step.
  """
  import Ecto.Query, only: [from: 2]

  require Ash.Query

  alias Emakola.Accounts.PlatformAuditFamilies, as: Families
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.User
  alias Emakola.SafeAtom

  defstruct family: :all, severity: :any, range: :all, q: ""

  @type t :: %__MODULE__{family: atom(), severity: atom(), range: atom(), q: String.t()}

  @ranges [day: "Last 24 hours", week: "Last 7 days", month: "Last 30 days", all: "All time"]
  @range_seconds %{day: 86_400, week: 7 * 86_400, month: 30 * 86_400}
  @severities [
    any: "Any severity",
    red: "Red",
    amber: "Amber",
    green: "Green",
    neutral: "Neutral"
  ]

  def ranges, do: @ranges
  def severities, do: @severities

  @doc "Builds a search from URL params; anything outside the allowlists falls back to the default."
  def from_params(params) do
    %__MODULE__{
      family: SafeAtom.to_atom_in(params["family"], [:all | Families.keys()], :all),
      severity: SafeAtom.to_atom_in(params["severity"], Keyword.keys(@severities), :any),
      range: SafeAtom.to_atom_in(params["range"], Keyword.keys(@ranges), :all),
      q: params["q"] |> to_string() |> String.trim()
    }
  end

  @doc "The inverse of `from_params/1`, omitting defaults so URLs stay short."
  def to_params(%__MODULE__{} = search) do
    %{}
    |> put_unless_default("family", search.family, :all)
    |> put_unless_default("severity", search.severity, :any)
    |> put_unless_default("range", search.range, :all)
    |> put_unless_default("q", search.q, "")
  end

  defp put_unless_default(params, _key, default, default), do: params

  defp put_unless_default(params, key, value, _default),
    do: Map.put(params, key, to_string(value))

  @doc "Start of the search's time window, or nil for all time."
  def since(%__MODULE__{range: :all}, _now), do: nil

  def since(%__MODULE__{range: range}, now),
    do: DateTime.add(now, -@range_seconds[range], :second)

  # ── rows ─────────────────────────────────────────────────────────

  @doc "One keyset page of matching entries, newest first. Opts: `limit`, `after`."
  def page(%__MODULE__{} = search, opts \\ []) do
    page_opts =
      case opts[:after] do
        nil -> [limit: Keyword.get(opts, :limit, 50)]
        cursor -> [limit: Keyword.get(opts, :limit, 50), after: cursor]
      end

    search |> query() |> Ash.read(page: page_opts, authorize?: false)
  end

  @doc "Every matching entry, newest first, fetched a page at a time."
  def stream(%__MODULE__{} = search, opts \\ []) do
    size = Keyword.get(opts, :page_size, 200)

    Stream.unfold(:first, fn
      :done ->
        nil

      cursor ->
        page_opts = if cursor == :first, do: [limit: size], else: [limit: size, after: cursor]

        case page(search, page_opts) do
          {:ok, %Ash.Page.Keyset{results: results, more?: true}} when results != [] ->
            {results, List.last(results).__metadata__.keyset}

          {:ok, %Ash.Page.Keyset{results: results}} ->
            {results, :done}

          {:error, _reason} ->
            {[], :done}
        end
    end)
    |> Stream.flat_map(& &1)
  end

  defp query(search) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> filter_actions(family_actions(search))
    |> filter_actions(severity_actions(search))
    |> filter_since(since(search, DateTime.utc_now()))
    |> filter_text(search.q)
  end

  defp filter_actions(query, nil), do: query
  defp filter_actions(query, actions), do: Ash.Query.filter(query, action in ^actions)

  defp filter_since(query, nil), do: query
  defp filter_since(query, at), do: Ash.Query.filter(query, inserted_at >= ^at)

  defp filter_text(query, ""), do: query

  defp filter_text(query, text) do
    pattern = like_pattern(text)
    ids = actor_ids_matching(pattern)

    Ash.Query.filter(
      query,
      actor_id in ^ids or fragment("? ILIKE ?", ip, ^pattern) or
        fragment("?::text ILIKE ?", metadata, ^pattern)
    )
  end

  # ── counts ───────────────────────────────────────────────────────

  @doc """
  Entries per family plus `:all`, under every filter except the family
  itself, so each chip says what picking it would show.
  """
  def counts(%__MODULE__{} = search) do
    by_action =
      from(l in PlatformAuditLog, group_by: l.action, select: {l.action, count(l.id)})
      |> where_actions(severity_actions(search))
      |> where_since(since(search, DateTime.utc_now()))
      |> where_text(search.q)
      |> Emakola.Repo.all()
      |> Map.new()

    Families.keys()
    |> Map.new(fn family ->
      {family, family |> Families.actions() |> Enum.map(&Map.get(by_action, &1, 0)) |> Enum.sum()}
    end)
    |> Map.put(:all, by_action |> Map.values() |> Enum.sum())
  end

  defp where_actions(query, nil), do: query
  defp where_actions(query, actions), do: from(l in query, where: l.action in ^actions)

  defp where_since(query, nil), do: query
  defp where_since(query, at), do: from(l in query, where: l.inserted_at >= ^at)

  defp where_text(query, ""), do: query

  defp where_text(query, text) do
    pattern = like_pattern(text)
    ids = actor_ids_matching(pattern)

    from(l in query,
      where:
        l.actor_id in ^ids or ilike(l.ip, ^pattern) or
          ilike(fragment("?::text", l.metadata), ^pattern)
    )
  end

  # ── shared pieces ────────────────────────────────────────────────

  defp family_actions(%{family: :all}), do: nil
  defp family_actions(%{family: family}), do: Families.actions(family)

  defp severity_actions(%{severity: :any}), do: nil
  defp severity_actions(%{severity: severity}), do: Families.severity_actions(severity)

  # `%`, `_` and `\` are LIKE syntax; a search for "50%" means the characters.
  defp like_pattern(text) do
    "%" <> Regex.replace(~r/[\\%_]/, text, fn match -> "\\" <> match end) <> "%"
  end

  defp actor_ids_matching(pattern) do
    User
    |> Ash.Query.filter(
      fragment("? ILIKE ?", email, ^pattern) or fragment("? ILIKE ?", name, ^pattern)
    )
    |> Ash.Query.select([:id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.id)
  end

  @doc """
  Whether a freshly logged entry would appear under this search. Decided in
  memory for the live "N new" count; a text search cannot be checked without
  a query, so it never matches.
  """
  def matches?(%__MODULE__{q: q}, _entry) when q != "", do: false

  def matches?(%__MODULE__{} = search, entry) do
    in_family?(search, entry.action) and in_severity?(search, entry.action) and
      in_range?(search, entry.inserted_at)
  end

  defp in_family?(%{family: :all}, _action), do: true
  defp in_family?(%{family: family}, action), do: action in Families.actions(family)

  defp in_severity?(%{severity: :any}, _action), do: true
  defp in_severity?(%{severity: severity}, action), do: Families.severity_of(action) == severity

  defp in_range?(search, at) do
    case since(search, DateTime.utc_now()) do
      nil -> true
      start -> DateTime.compare(at, start) != :lt
    end
  end

  # ── presentation helpers ─────────────────────────────────────────

  @doc """
  Interleaves a band item before the first entry of each day. `last_date`
  is the date of the previous page's final entry, so a day that continues
  across a page boundary is not banded twice. Returns the items and the
  new last date.
  """
  def with_bands(entries, last_date) do
    {items, last} =
      Enum.reduce(entries, {[], last_date}, fn entry, {items, last} ->
        date = DateTime.to_date(entry.inserted_at)
        item = %{id: entry.id, kind: :entry, entry: entry}

        if date == last,
          do: {[item | items], last},
          else: {[item, band(date) | items], date}
      end)

    {Enum.reverse(items), last}
  end

  defp band(date) do
    %{
      id: "band-" <> Date.to_iso8601(date),
      kind: :band,
      date: date,
      label: band_label(date, Date.utc_today())
    }
  end

  defp band_label(date, today) do
    name = Calendar.strftime(date, "%a %-d %b")

    case Date.diff(today, date) do
      0 -> "Today · " <> name
      1 -> "Yesterday · " <> name
      _ -> name
    end
  end

  @doc """
  Resolves the actors of `entries` to `%{name, email}`, one batched query
  per call. Ids already in `known` are never re-queried.
  """
  def actor_names(known, entries) do
    ids =
      entries
      |> Enum.map(& &1.actor_id)
      |> Enum.reject(&(is_nil(&1) or Map.has_key?(known, &1)))
      |> Enum.uniq()

    case ids do
      [] ->
        known

      ids ->
        User
        |> Ash.Query.filter(id in ^ids)
        |> Ash.read(authorize?: false)
        |> case do
          {:ok, users} ->
            Enum.into(users, known, &{&1.id, %{name: &1.name, email: to_string(&1.email)}})

          {:error, _reason} ->
            known
        end
    end
  end
end
