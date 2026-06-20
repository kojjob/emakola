defmodule EmakolaWeb.SEO.Regions do
  @moduledoc """
  Ghana regions as a programmatic-SEO surface (Phase 4).

  Single source of the region list, slug↔name mapping, and which regions are
  "indexable" — enough active shops to justify a `/shops/:region` page in the
  sitemap. Shared by `ShopsLive` (page rendering) and the platform sitemap
  (enumeration), so the indexed set and the rendered set never drift.
  """

  require Ash.Query

  alias Emakola.Stores.Store

  @names [
    "Greater Accra",
    "Ashanti",
    "Western",
    "Central",
    "Eastern",
    "Northern",
    "Volta",
    "Upper East",
    "Upper West",
    "Bono",
    "Bono East",
    "Ahafo",
    "Savannah",
    "North East",
    "Western North",
    "Oti"
  ]
  @min_for_index 3

  @spec names() :: [String.t()]
  def names, do: @names

  @spec min_for_index() :: pos_integer()
  def min_for_index, do: @min_for_index

  @spec slug(String.t()) :: String.t()
  def slug(name) do
    name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  @spec from_slug(String.t()) :: String.t() | nil
  def from_slug(slug), do: Enum.find(@names, fn name -> slug(name) == slug end)

  @doc """
  Regions with at least `min_for_index` active shops, as `{name, slug}` — the
  set that's safe to list in the sitemap (matches the page's noindex guardrail).
  """
  @spec indexable() :: [{String.t(), String.t()}]
  def indexable do
    counts = active_store_region_counts()

    @names
    |> Enum.filter(fn name -> Map.get(counts, name, 0) >= @min_for_index end)
    |> Enum.map(fn name -> {name, slug(name)} end)
  end

  defp active_store_region_counts do
    Store
    |> Ash.Query.filter(active == true and not is_nil(region))
    |> Ash.Query.select([:region])
    |> Ash.read!(authorize?: false)
    |> Enum.frequencies_by(& &1.region)
  end
end
