defmodule EmakolaWeb.ReservedStoreSlugs do
  @moduledoc """
  Store slugs that would collide with a page on the apex.

  A store is served at `makola.io/<slug>` by a root catch-all declared last, so
  a real page always wins the match — `makola.io/pricing` is the pricing page,
  never a shop. The hazard runs the other way: a store slugged `pricing` would
  simply be unreachable at its short URL.

  The list is **derived from the router at runtime**, not hand-maintained. That
  is the whole point: a hand-written list of ~58 top-level paths would rot the
  first time someone adds a marketing page, and the failure would be silent and
  months later. Anything routed on the apex is reserved automatically.

  Called from `Emakola.Stores.Changes.EnsureUniqueSlug`, which is domain-layer
  code reaching into the web layer. That is a deliberate exception: the router
  is the only honest source of truth for "what paths exist", and duplicating it
  into the domain is the thing that would actually cause bugs.
  """

  @doc "True when `slug` would collide with a routed apex path."
  @spec reserved?(String.t()) :: boolean()
  def reserved?(slug) when is_binary(slug), do: slug in all()
  def reserved?(_), do: false

  @doc """
  Every first path segment the router serves, plus a few names we keep back for
  future use rather than discovering the need at an awkward moment.
  """
  @spec all() :: MapSet.t(String.t())
  def all do
    EmakolaWeb.Router.__routes__()
    |> Enum.map(&first_segment(&1.path))
    |> Enum.reject(&(&1 in [nil, "", "*"]))
    |> Enum.reject(&String.starts_with?(&1, ":"))
    |> Enum.concat(~w(www api app mail static assets cdn help status support))
    |> MapSet.new()
  end

  defp first_segment(path) do
    path |> String.split("/", trim: true) |> List.first()
  end
end
