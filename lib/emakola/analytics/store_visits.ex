defmodule Emakola.Analytics.StoreVisits do
  @moduledoc """
  Recording and reading storefront traffic.

  Admin reports lost their conversion rate and their sales-by-channel
  breakdown because nothing in this codebase counted visits, and inventing the
  numbers was rightly refused. This is the denominator those figures need.

  ## Honest counting

  `visits/2` counts page views. `visitors/2` counts distinct people. The
  difference matters: one person browsing five pages is one visitor, and
  dividing orders by pageviews would understate every merchant's conversion
  rate while looking like the same calculation.

  ## Sources are a closed set

  A visit's `source` is bucketed into a handful of known channels from the UTM
  tag or the referrer. The raw referrer is never stored — it is a URL, and URLs
  carry query strings that people put surprising things in. `utm_source` comes
  straight off a link anyone can craft, so it is matched against a fixed list
  rather than converted to an atom; `String.to_atom/1` on that input would be an
  atom-table exhaustion bug, and `to_existing_atom/1` would be a 500.
  """

  import Ecto.Query, only: [from: 2]

  alias Emakola.Analytics.StoreVisit

  # The buckets a merchant is shown. Anything else is :other — a report with a
  # long tail of one-off referrers answers no question worth asking.
  @sources %{
    "instagram" => :instagram,
    "tiktok" => :tiktok,
    "whatsapp" => :whatsapp,
    "facebook" => :facebook,
    "twitter" => :x,
    "x" => :x,
    "qr" => :qr,
    "google" => :search,
    "bing" => :search,
    "search" => :search,
    "direct" => :direct
  }

  @referrer_hosts [
    {~r/instagram\./i, :instagram},
    {~r/tiktok\./i, :tiktok},
    {~r/(whatsapp|wa\.me)/i, :whatsapp},
    {~r/(facebook\.|fb\.me)/i, :facebook},
    {~r/(twitter\.|x\.com)/i, :x},
    {~r/(google\.|bing\.|duckduckgo\.|search\.yahoo)/i, :search}
  ]

  @doc """
  Records one visit.

  `session_id` is the `cart_session_id` the app already sets for every request;
  it is hashed here and never stored in the clear, because it is also the key to
  that browser's cart.

  `params` may carry `"utm_source"` and `"referrer"`. Both are attacker-supplied
  and are only ever used to pick a bucket.
  """
  @spec record(binary(), binary(), map()) :: {:ok, StoreVisit.t()} | {:error, term()}
  def record(store_id, session_id, params)
      when is_binary(store_id) and is_binary(session_id) and is_map(params) do
    result =
      StoreVisit
      |> Ash.Changeset.for_create(:record, %{
        store_id: store_id,
        visitor_hash: hash(session_id),
        source: source_from(params),
        occurred_at: DateTime.utc_now()
      })
      |> Ash.create(authorize?: false)

    with {:ok, _visit} <- result, do: bump_view_count(store_id)

    result
  end

  # Store.view_count is what the directory's "Most popular" sort reads, and
  # for months nothing wrote it — the sort ordered twenty zeros. Bumping it
  # here, on the same event that records the visit, makes that sort mean
  # "most viewed" again. Atomic on the database side; best-effort on ours,
  # because a counter that cannot be written is not worth failing a
  # storefront visit over.
  defp bump_view_count(store_id) do
    Emakola.Stores.Store
    |> Ash.get!(store_id, authorize?: false)
    |> Ash.Changeset.for_update(:increment_view_count, %{})
    |> Ash.update(authorize?: false)
  rescue
    exception ->
      require Logger
      Logger.warning("[store_visits] view_count bump failed: #{Exception.message(exception)}")
      :ok
  end

  @doc "Page views for a store over the last `days`."
  @spec visits(binary(), pos_integer()) :: non_neg_integer()
  def visits(store_id, days) do
    Emakola.Repo.one(
      from(v in "store_visits",
        where: v.store_id == type(^store_id, :binary_id) and v.occurred_at >= ^since(days),
        select: count(v.id)
      )
    ) || 0
  end

  @doc """
  Distinct people for a store over the last `days`.

  This is the denominator a conversion rate needs. `visits/2` is not.
  """
  @spec visitors(binary(), pos_integer()) :: non_neg_integer()
  def visitors(store_id, days) do
    Emakola.Repo.one(
      from(v in "store_visits",
        where: v.store_id == type(^store_id, :binary_id) and v.occurred_at >= ^since(days),
        select: count(fragment("distinct ?", v.visitor_hash))
      )
    ) || 0
  end

  @doc "Page views grouped by channel, as a map of source atom to count."
  @spec by_source(binary(), pos_integer()) :: %{atom() => non_neg_integer()}
  def by_source(store_id, days) do
    from(v in "store_visits",
      where: v.store_id == type(^store_id, :binary_id) and v.occurred_at >= ^since(days),
      group_by: v.source,
      select: {v.source, count(v.id)}
    )
    |> Emakola.Repo.all()
    |> Map.new(fn {source, count} -> {String.to_existing_atom(source), count} end)
  end

  @doc """
  Store ids ranked by distinct people over the last `days`, busiest first.

  Ranks on visitors rather than page views for the same reason `visitors/2`
  exists: one person refreshing a page all afternoon is one interested person,
  and letting that outrank three separate shoppers would put the wrong shop at
  the top of the directory.

  Returns ids, not stores — the caller loads them through the directory's own
  read action so the live/active filters and the tenant rules still apply.
  """
  @spec most_visited(non_neg_integer(), pos_integer()) :: [binary()]
  def most_visited(days, limit) do
    from(v in "store_visits",
      where: v.occurred_at >= ^since(days),
      group_by: v.store_id,
      order_by: [desc: count(fragment("distinct ?", v.visitor_hash))],
      limit: ^limit,
      select: type(v.store_id, :binary_id)
    )
    |> Emakola.Repo.all()
  end

  # -- internals --------------------------------------------------------------

  defp since(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

  defp hash(session_id), do: :crypto.hash(:sha256, session_id) |> Base.encode16(case: :lower)

  # utm_source is the explicit claim and wins over the referrer, which is only
  # ever a guess about where someone came from.
  defp source_from(params) do
    case bucket_utm(params["utm_source"]) do
      nil -> bucket_referrer(params["referrer"])
      source -> source
    end
  end

  defp bucket_utm(nil), do: nil

  defp bucket_utm(value) when is_binary(value) do
    Map.get(@sources, String.downcase(String.trim(value)), :other)
  end

  defp bucket_utm(_value), do: nil

  defp bucket_referrer(nil), do: :direct
  defp bucket_referrer(""), do: :direct

  defp bucket_referrer(referrer) when is_binary(referrer) do
    Enum.find_value(@referrer_hosts, :other, fn {pattern, source} ->
      if referrer =~ pattern, do: source
    end)
  end

  defp bucket_referrer(_referrer), do: :direct
end
