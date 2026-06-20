defmodule EmakolaWeb.SellOnlineLive do
  @moduledoc """
  Programmatic-SEO merchant-acquisition page (Phase 4): "sell online in {region}",
  e.g. `/sell-online/ashanti`. Targets local "start an online shop in {region}"
  intent with the region woven through the copy, a register CTA, and apex-
  canonical SEO + FAQ JSON-LD. One per Ghana region.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.SEO.{Canonical, Regions}

  @impl true
  def mount(%{"region" => slug}, _session, socket) do
    case Regions.from_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: "/pricing")}

      region ->
        {:ok,
         socket
         |> assign(region: region, slug: slug, region_links: region_links(slug))
         |> assign_seo(region, slug)}
    end
  end

  defp assign_seo(socket, region, slug) do
    socket
    |> assign(:page_title, "Sell Online in #{region}, Ghana — Start Your Shop | Makola")
    |> assign(
      :meta_description,
      "Start an online shop in #{region}, Ghana. Accept MTN MoMo and Vodafone Cash, " <>
        "send WhatsApp order updates, and reach customers across #{region}. Free to start."
    )
    |> assign(:canonical_url, Canonical.url("/sell-online/#{slug}"))
    |> assign(:robots, "index, follow")
    |> assign(:og_type, "website")
    |> assign(:json_ld, [
      SEO.json_ld_breadcrumb([
        %{name: "Sell Online", url: Canonical.url("/pricing")},
        %{name: region, url: Canonical.url("/sell-online/#{slug}")}
      ]),
      SEO.json_ld_faq(faqs(region))
    ])
  end

  defp faqs(region) do
    [
      %{
        question: "How do I start selling online in #{region}?",
        answer:
          "Create a free Makola shop, add your products, and share your link. " <>
            "You can accept mobile money and card payments the same day."
      },
      %{
        question: "What does it cost to sell online in #{region}?",
        answer:
          "Makola is free to start — you only pay a small fee per sale. Paid plans " <>
            "with lower rates start at GHS 29 per month."
      }
    ]
  end

  defp region_links(current_slug) do
    Regions.names()
    |> Enum.map(fn r -> {r, Regions.slug(r)} end)
    |> Enum.reject(fn {_r, s} -> s == current_slug end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <div class="max-w-4xl mx-auto px-4 py-16">
        <p class="text-sm font-semibold uppercase tracking-wide text-emerald-700">
          Sell online in {@region}
        </p>
        <h1 class="mt-3 text-4xl font-bold text-stone-900">
          Start your online shop in {@region}, Ghana
        </h1>
        <p class="mt-4 max-w-2xl text-lg text-stone-600">
          Reach customers across {@region} with a shop that takes MTN MoMo and Vodafone Cash,
          sends order updates on WhatsApp, and loads fast on any phone. Free to start.
        </p>

        <div class="mt-8 flex flex-wrap gap-3">
          <.link
            navigate="/auth/register"
            class="rounded-lg bg-emerald-600 px-6 py-3 font-semibold text-white hover:bg-emerald-700"
          >
            Create your free shop
          </.link>
          <.link
            navigate={"/shops/#{@slug}"}
            class="rounded-lg border border-stone-300 px-6 py-3 font-semibold text-stone-700 hover:bg-stone-50"
          >
            See shops in {@region}
          </.link>
        </div>

        <dl class="mt-14 grid gap-8 sm:grid-cols-3">
          <div>
            <dt class="font-semibold text-stone-900">Mobile money built in</dt>
            <dd class="mt-1 text-sm text-stone-600">
              MTN MoMo, Vodafone Cash and AirtelTigo, plus cards — settled to your account.
            </dd>
          </div>
          <div>
            <dt class="font-semibold text-stone-900">WhatsApp order updates</dt>
            <dd class="mt-1 text-sm text-stone-600">
              Customers get automatic confirmations and delivery updates where they already chat.
            </dd>
          </div>
          <div>
            <dt class="font-semibold text-stone-900">Free to start</dt>
            <dd class="mt-1 text-sm text-stone-600">
              No upfront cost. Pay a small fee per sale, upgrade only when you grow.
            </dd>
          </div>
        </dl>

        <div class="mt-16 border-t border-stone-100 pt-8">
          <p class="text-sm font-medium text-stone-700">Sell online in other regions</p>
          <div class="mt-3 flex flex-wrap gap-2">
            <.link
              :for={{name, slug} <- @region_links}
              navigate={"/sell-online/#{slug}"}
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
