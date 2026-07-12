defmodule Emakola.Themes.Akwaaba.Sections.Usp do
  @moduledoc """
  Akwaaba USP row — four outlined cards under the hero panel.

  Every claim here is one the platform actually keeps: the payment rails are
  real, the policies link to the store's own pages. Nothing invented.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  @impl true
  def key, do: "akwaaba/usp"
  @impl true
  def label, do: "Why shop here"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    ~H"""
    <section
      class="bg-white px-5 py-12 [font-family:var(--akwaaba-body)] sm:px-10 sm:py-16"
      aria-label="Why shop here"
    >
      <ul class="mx-auto grid max-w-[1320px] gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <li
          :for={
            {title, line, path} <- [
              {"Mobile money", "MTN MoMo, Telecel Cash, AirtelTigo", nil},
              {"Secure checkout", "Payments processed securely", nil},
              {"Delivery & returns", "See this store's policies", "/policies"},
              {"Questions?", "Talk to the shop", "/contact"}
            ]
          }
          class="rounded-3xl border border-zinc-200 p-6 text-center"
        >
          <p class="text-lg text-[color:var(--akwaaba-ink)] [font-family:var(--akwaaba-display)]">
            {title}
          </p>
          <p :if={is_nil(path)} class="mt-1.5 text-sm text-zinc-500">{line}</p>
          <a
            :if={path}
            href={store_path(@store.slug, path)}
            class="mt-1.5 inline-block text-sm text-zinc-500 underline underline-offset-4 hover:text-[color:var(--akwaaba-sun)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--akwaaba-sun)]"
          >
            {line}
          </a>
        </li>
      </ul>
    </section>
    """
  end
end
