defmodule Emakola.Themes.DefaultRenderers.Faq do
  @moduledoc """
  Default render for the storefront FAQ page.

  Used by `EmakolaWeb.Storefront.FaqLive` when no theme overrides `:render_faq`.
  Renders the store's `faq_items` as a native `<details>` accordion (works
  without JavaScript), reusing the markup style of the FAQ page-builder block.
  """

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias EmakolaWeb.Storefront.ContentLoader

  def render(assigns) do
    items =
      (Map.get(assigns, :page_content) || %{})
      |> ContentLoader.list(:faq_items)
      |> Enum.filter(&valid_item?/1)

    assigns = assign(assigns, :faq_items, items)

    ~H"""
    <Emakola.Themes.DefaultRenderers.Chrome.navbar
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
      categories={@categories}
      cart_count={@cart_count}
      active_path="faq"
    />

    <div class="max-w-3xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
      <h1 class="text-3xl sm:text-4xl font-black text-stone-900 mb-8">
        Frequently Asked Questions
      </h1>

      <div :if={@faq_items == []} class="rounded-xl border border-stone-200 bg-white p-8 text-center">
        <p class="text-stone-500">No FAQs have been added yet.</p>
        <a
          href={store_path(@store.slug, "/contact")}
          class="inline-block mt-3 text-sm font-semibold"
          style="color: var(--theme-primary);"
        >
          Have a question? Contact us →
        </a>
      </div>

      <div class="space-y-3">
        <details
          :for={item <- @faq_items}
          name="faq"
          class="bg-white rounded-xl border border-stone-200 group"
        >
          <summary class="flex items-center justify-between p-5 cursor-pointer list-none">
            <span class="text-base font-semibold text-stone-900 pr-4">
              {item_field(item, "question")}
            </span>
            <span
              class="material-symbols-outlined text-stone-500 transition-transform group-open:rotate-45"
              style="font-size: 22px;"
            >
              add
            </span>
          </summary>
          <div class="px-5 pb-5 -mt-1">
            <p class="text-sm text-stone-600 leading-relaxed whitespace-pre-line">
              {item_field(item, "answer")}
            </p>
          </div>
        </details>
      </div>
    </div>

    <Emakola.Themes.DefaultRenderers.Chrome.footer
      theme_module={assigns[:theme_module]}
      theme={assigns[:theme] || %{}}
      store={@store}
      categories={@categories}
    />
    """
  end

  defp valid_item?(item) when is_map(item) do
    # item_field/2 always returns a binary, so a non-empty trimmed question
    # is the only validity condition.
    String.trim(item_field(item, "question")) != ""
  end

  defp valid_item?(_), do: false

  defp item_field(item, key) when is_map(item) do
    case Map.get(item, key) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end
end
