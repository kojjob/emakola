defmodule EmakolaWeb.ShopsLive do
  @moduledoc """
  Programmatic-SEO landing page (Phase 4): online shops in a Ghana region, e.g.
  `/shops/greater-accra`. Renders a real grid of active stores in the region
  with apex-canonical SEO and FAQ/breadcrumb JSON-LD.

  Thin-content guardrail: a region with fewer than `@min_for_index` shops still
  renders (useful to visitors) but is `noindex`ed so Google doesn't index a
  near-empty page.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Stores.Store
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.SEO.{Canonical, Regions}

  @impl true
  def mount(%{"region" => slug}, _session, socket) do
    case Regions.from_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: "/stores")}

      region ->
        stores = stores_in_region(region)

        {:ok,
         socket
         |> assign(region: region, slug: slug, stores: stores, region_links: region_links(slug))
         |> assign_seo(region, slug, stores)}
    end
  end

  defp assign_seo(socket, region, slug, stores) do
    count = length(stores)

    socket
    |> assign(:page_title, "Online Shops in #{region}, Ghana | Makola")
    |> assign(
      :meta_description,
      "Discover #{count} online #{plural("shop", count)} in #{region}, Ghana. " <>
        "Buy from local sellers and pay with MTN MoMo, Vodafone Cash and more on Makola."
    )
    |> assign(:canonical_url, Canonical.url("/shops/#{slug}"))
    |> assign(
      :robots,
      if(count >= Regions.min_for_index(), do: "index, follow", else: "noindex, follow")
    )
    |> assign(:og_type, "website")
    |> assign(:json_ld, [
      SEO.json_ld_breadcrumb([
        %{name: "Shops", url: Canonical.url("/stores")},
        %{name: region, url: Canonical.url("/shops/#{slug}")}
      ]),
      SEO.json_ld_faq(faqs(region))
    ])
  end

  defp stores_in_region(region) do
    Store
    |> Ash.Query.filter(active == true and region == ^region)
    |> Ash.Query.sort(name: :asc)
    |> Ash.Query.limit(60)
    |> Ash.read!(authorize?: false)
  end

  defp faqs(region) do
    [
      %{
        question: "How do I buy from a shop in #{region}?",
        answer:
          "Open any shop below, add what you want to your cart, and pay with mobile money " <>
            "(MTN MoMo, Vodafone Cash) or card at checkout."
      },
      %{
        question: "Do shops in #{region} deliver?",
        answer:
          "Most shops deliver across #{region} and beyond. Delivery areas and fees are shown at checkout."
      }
    ]
  end

  defp region_links(current_slug) do
    Regions.names()
    |> Enum.map(fn r -> {r, Regions.slug(r)} end)
    |> Enum.reject(fn {_r, s} -> s == current_slug end)
  end

  defp plural(word, 1), do: word
  defp plural(word, _), do: word <> "s"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <div class="max-w-6xl mx-auto px-4 py-12">
        <nav class="text-sm text-stone-500">
          <.link navigate="/stores" class="hover:text-stone-800">Shops</.link>
          <span class="mx-1">/</span>
          <span class="text-stone-800">{@region}</span>
        </nav>

        <h1 class="mt-4 text-3xl font-bold text-stone-900">
          Online shops in {@region}, Ghana
        </h1>
        <p class="mt-3 max-w-2xl text-stone-600">
          Browse local online shops in {@region} — market traders, tailors, food vendors and more.
          Pay securely with MTN MoMo, Vodafone Cash or card, and get it delivered.
        </p>

        <div :if={@stores == []} class="mt-10 rounded-lg border border-stone-200 bg-stone-50 p-6">
          <p class="text-stone-700">
            No shops in {@region} yet. <.link
              navigate="/stores"
              class="font-semibold text-emerald-700"
            >Browse all shops</.link>.
          </p>
        </div>

        <div :if={@stores != []} class="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={store <- @stores}
            navigate={"/@#{store.slug}"}
            class="block rounded-xl border border-stone-200 p-5 transition hover:border-emerald-400 hover:shadow-sm"
          >
            <p class="font-semibold text-stone-900">{store.name}</p>
            <p :if={store.tagline} class="mt-1 text-sm text-stone-500">{store.tagline}</p>
          </.link>
        </div>

        <div class="mt-14 border-t border-stone-100 pt-8">
          <p class="text-sm font-medium text-stone-700">Shops in other regions</p>
          <div class="mt-3 flex flex-wrap gap-2">
            <.link
              :for={{name, slug} <- @region_links}
              navigate={"/shops/#{slug}"}
              class="rounded-full bg-stone-100 px-3 py-1 text-sm text-stone-600 hover:bg-stone-200"
            >
              {name}
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
