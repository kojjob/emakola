defmodule EmakolaWeb.Storefront.FaqLive do
  @moduledoc """
  FAQ page for a store — renders the merchant's own question/answer pairs.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Cart.CartStore
  alias EmakolaWeb.Helpers.SEO
  alias EmakolaWeb.SEO.Canonical
  alias EmakolaWeb.Storefront.ContentLoader

  @impl true
  def mount(_params, session, socket) do
    store = socket.assigns.store
    page_content = ContentLoader.load(store.id)
    faq_items = valid_faq_items(page_content)
    cart_session_id = session["cart_session_id"]

    cart_count =
      if connected?(socket) && cart_session_id,
        do: CartStore.cart_count(cart_session_id, store.id),
        else: 0

    {:ok,
     socket
     |> assign(:categories, Emakola.Catalog.list_root_categories!(store.id))
     |> assign(:cart_session_id, cart_session_id)
     |> assign(:cart_count, cart_count)
     |> assign(:page_content, page_content)
     |> assign(:page_title, "FAQ - #{store.name}")
     |> assign(
       :meta_description,
       "Answers from #{store.name} about products, ordering, payment, delivery, and returns."
     )
     |> assign(:canonical_url, Canonical.path(store, "/faq"))
     |> assign(:og_site_name, store.name)
     |> assign(:robots, if(faq_items == [], do: "noindex, follow", else: "index, follow"))
     |> assign(:json_ld, if(faq_items == [], do: nil, else: SEO.json_ld_faq(faq_items)))}
  end

  @impl true
  def render(assigns) do
    case Emakola.Themes.ThemeRenderer.theme_render(assigns, :faq) do
      {:ok, rendered} -> rendered
      :default -> Emakola.Themes.DefaultRenderers.Faq.render(assigns)
    end
  end

  defp valid_faq_items(page_content) do
    page_content
    |> ContentLoader.list(:faq_items)
    |> Enum.filter(fn item ->
      non_blank?(Map.get(item, "question") || Map.get(item, :question)) and
        non_blank?(Map.get(item, "answer") || Map.get(item, :answer))
    end)
  end

  defp non_blank?(value) when is_binary(value), do: String.trim(value) != ""
  defp non_blank?(_value), do: false
end
