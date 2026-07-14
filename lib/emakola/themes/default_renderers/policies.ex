defmodule Emakola.Themes.DefaultRenderers.Policies do
  @moduledoc """
  Default render for the storefront policies page.

  Used by `EmakolaWeb.Storefront.PoliciesLive` when no theme overrides
  `:render_policies`. One page with four anchored sections — shipping, returns
  and warranty, privacy and terms. Each section the merchant has not written
  falls back to a neutral, store-name-driven template so a brand-new store still
  has usable policies.

  The returns section is the authority every theme's returns badge links to
  (`/policies#returns`), and carries the merchant's stated window and warranty —
  the same numbers `Emakola.Themes.Terms` prints on the product page, from the
  same row, so the shop cannot quote two different windows.
  """

  use Phoenix.Component

  alias Emakola.Themes.Terms
  alias EmakolaWeb.Storefront.ContentLoader

  def render(assigns) do
    pc = Map.get(assigns, :page_content) || %{}
    store = assigns.store

    sections = [
      %{
        id: "shipping",
        title: "Shipping",
        badges: [],
        body: ContentLoader.field(pc, :shipping_returns) || default_shipping(store)
      },
      %{
        id: "returns",
        title: "Returns & Warranty",
        badges: Terms.badges(%{page_content: pc}),
        body: Terms.warranty_terms(pc) || default_returns(store)
      },
      %{
        id: "privacy",
        title: "Privacy Policy",
        badges: [],
        body: ContentLoader.field(pc, :privacy_policy) || default_privacy(store)
      },
      %{
        id: "terms",
        title: "Terms of Service",
        badges: [],
        body: ContentLoader.field(pc, :terms_of_service) || default_terms(store)
      }
    ]

    assigns = assign(assigns, :sections, sections)

    ~H"""
    <Emakola.Themes.DefaultRenderers.Chrome.navbar
      theme_module={assigns[:theme_module]}
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="policies"
    />

    <div class="max-w-3xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
      <h1 class="text-3xl sm:text-4xl font-black text-stone-900 mb-6">Store Policies</h1>

      <nav class="flex flex-wrap gap-x-6 gap-y-2 mb-10 pb-6 border-b border-stone-200">
        <a
          :for={section <- @sections}
          href={"##{section.id}"}
          class="text-sm font-semibold hover:underline"
          style="color: var(--theme-primary);"
        >
          {section.title}
        </a>
      </nav>

      <section :for={section <- @sections} id={section.id} class="mb-12 scroll-mt-24">
        <h2 class="text-xl sm:text-2xl font-bold text-stone-900 mb-4">{section.title}</h2>
        <ul :if={section.badges != []} class="flex flex-wrap gap-2 mb-4">
          <li
            :for={badge <- section.badges}
            class="px-3 py-1 rounded-full bg-stone-100 text-stone-900 text-sm font-semibold"
          >
            {badge}
          </li>
        </ul>
        <div class="text-stone-600 leading-relaxed whitespace-pre-line">{section.body}</div>
      </section>
    </div>

    <Emakola.Themes.DefaultRenderers.Chrome.footer
      theme_module={assigns[:theme_module]}
      store={@store}
      categories={@categories}
    />
    """
  end

  defp default_shipping(store) do
    "#{store.name} aims to process and dispatch your order promptly after it is confirmed. " <>
      "Delivery times depend on your location and the option chosen at checkout. " <>
      "If something is not right with your order, contact us and we will help arrange a return or exchange."
  end

  # Deliberately states no window and no warranty: a merchant who has set
  # neither has promised neither, and this page is where a shopper comes to find
  # out. Inventing "30 days" here is exactly the failure this section exists to
  # end. Contacting the shop is the one thing that is always true.
  defp default_returns(store) do
    "Contact #{store.name} if something is not right with your order and we will help arrange a return, " <>
      "exchange or repair. Returns windows and warranty cover vary by product — ask us before you buy " <>
      "if you need to be sure."
  end

  defp default_privacy(store) do
    "#{store.name} only collects the information needed to process your order, deliver it, and provide support. " <>
      "We do not sell your personal data. Payment details are handled securely by our payment provider."
  end

  defp default_terms(store) do
    "By placing an order with #{store.name} you agree to these terms. " <>
      "Prices and availability may change, and we reserve the right to cancel an order if an item is unavailable. " <>
      "Please reach out with any questions before you buy."
  end
end
