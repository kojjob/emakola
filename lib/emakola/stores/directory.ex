defmodule Emakola.Stores.Directory do
  @moduledoc """
  Builds the browse rails on the public `/stores` directory.

  A rail is a query, never a hand-picked list. Nobody edits this page: the
  marketplace grows, shops publish, and the rails refill themselves.

  Two rules hold the whole thing together.

  **A thin rail hides itself.** A rail that cannot fill `#{4}` cards does not
  render at all. One lonely shop under a confident heading reads as a broken
  marketplace rather than a small one, and on a young directory most category
  rails are empty. So the page has no fixed number of rails — it shows the ones
  that are full today and grows more as merchants join.

  **The spotlight rotates on the date, not on a timer.** `spotlight/2` takes a
  window over `featured_rank` derived from the day itself, so every visitor sees
  the same shop all day and a different one tomorrow. Every featured merchant
  gets a real turn in the big slot, the page still caches, and a shopper can go
  back to the shop they saw this morning — none of which a browser-side carousel
  timer can offer.
  """

  require Logger

  alias Emakola.Stores.Store

  @min_cards 4
  @per_rail 12

  @typedoc "A rail: an id, what to call it, and the shops the query returned."
  @type rail :: %{id: atom(), title: String.t(), subtitle: String.t(), stores: list()}

  @doc """
  Rotates `featured` so the shop holding the big slot is decided by `date`.

  Nothing is dropped — the list is rotated, so the shops that are not first
  today are still there for the rail beside the hero.
  """
  @spec spotlight(list(), Date.t()) :: list()
  def spotlight([], _date), do: []

  def spotlight(featured, date) when is_list(featured) do
    {tail, head} = Enum.split(featured, rem(Date.day_of_year(date), length(featured)))
    head ++ tail
  end

  @doc """
  Every rail that has enough shops to be worth showing, in display order.

  Pass `:themes` as a list of `{rail_id, theme, label}` to control which category
  rails are attempted; the default is the set the directory filters already offer.
  """
  @spec rails(keyword()) :: [rail()]
  def rails(opts \\ []) do
    themes = Keyword.get(opts, :themes, default_themes())

    theme_rails = Enum.map(themes, &theme_rail/1)

    (theme_rails ++ [most_visited_rail(), just_opened_rail()])
    |> Enum.reject(&(length(&1.stores) < @min_cards))
  end

  # ── Rails ──────────────────────────────────────────────────────────────

  defp theme_rail({id, theme, label}) do
    %{
      id: id,
      title: label,
      subtitle: "Newest stock first",
      stores: query(%{theme: theme, sort: :newest})
    }
  end

  defp most_visited_rail do
    %{
      id: :most_visited,
      title: "Most visited",
      # view_count is cumulative — there is no per-week history to read, so the
      # heading does not claim one.
      subtitle: "Where shoppers are spending their time",
      stores: query(%{sort: :popular})
    }
  end

  defp just_opened_rail do
    %{
      id: :just_opened,
      title: "Just opened",
      subtitle: "New on Makola this week",
      stores: query(%{sort: :newest})
    }
  end

  # ── Query ──────────────────────────────────────────────────────────────

  defp query(args) do
    Store
    |> Ash.Query.for_read(:list_with_filters, Map.merge(%{limit: @per_rail}, args))
    |> Ash.Query.load([:product_count, :card_image_url, :card_image_medium_url])
    |> Ash.read!(authorize?: false)
  rescue
    exception ->
      Logger.error("[stores.directory] rail query raised: #{Exception.message(exception)}")
      []
  end

  # Rail ids are literal atoms rather than built from the theme string: a caller
  # can pass its own :themes, and deriving an atom from a runtime string is how
  # you hand someone an atom-table exhaustion bug.
  defp default_themes do
    [
      {:theme_fresh, "fresh", "Fresh"},
      {:theme_atelier, "atelier", "Atelier"},
      {:theme_beauty, "beauty", "Beauty"},
      {:theme_fashion, "fashion", "Fashion"},
      {:theme_market, "market", "Market"},
      {:theme_home_living, "home_living", "Home Living"},
      {:theme_electronics, "electronics", "Electronics"},
      {:theme_pharmacy, "pharmacy", "Pharmacy"}
    ]
  end
end
