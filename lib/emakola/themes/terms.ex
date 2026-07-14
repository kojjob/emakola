defmodule Emakola.Themes.Terms do
  @moduledoc """
  What a store can truthfully say about returns and warranty.

  Themes used to hardcode these: a "1-year warranty" pill beside the price on
  every Electronics product, "30-day returns" on every Home Living one,
  "14-day returns" on every Fashion one. No merchant had offered any of it,
  none could remove it, and two themes stated different windows for the same
  shop.

  Unlike delivery — which is derived from the `Emakola.Shipping.DeliveryZone`
  rows the checkout already charges from — a returns window and a warranty have
  nothing to derive from. They are a promise, and only the person who has to
  honour it can make it. So they come from `Emakola.Stores.StorePageContent`,
  which the merchant edits, and a merchant who has stated nothing gets a
  storefront that says nothing.

  ## Who the shopper is buying from

  On dropshipped goods there are two sets of terms. The supplier states what
  they will honour back to the reseller (`Emakola.Suppliers.SupplierOffer`),
  but the **merchant is the seller of record** — the shopper's contract is with
  the shop they paid, not with a supplier they have never heard of. So what a
  customer is quoted is always the merchant's own policy, on every product in
  the shop, and the supplier's terms are shown to the *merchant* in the supply
  network instead. A merchant who offers a 30-day return on goods a supplier
  only takes back for 7 is absorbing that gap knowingly rather than blind.
  """

  @doc """
  The store's page content, from the assigns map the storefront LiveViews build.

  Not every caller assigns it — the section-editor preview and the page-builder
  render themes from assigns of their own — so an absent one degrades to "this
  store stated nothing", never to a crash.
  """
  def content(assigns), do: Map.get(assigns, :page_content) || %{}

  @doc ~S"""
  The merchant's returns window — `"30-day returns"` — or `nil` when they have
  stated none.

  A window of `0` is a *stated* policy, not an absent one: final-sale goods are
  a material restriction the shopper must be able to read before paying, and
  silence would let them assume the window every other shop offers.
  """
  def returns(content) do
    case Map.get(content, :returns_window_days) do
      nil -> nil
      0 -> "No returns"
      1 -> "1-day returns"
      days when is_integer(days) and days > 0 -> "#{days}-day returns"
      _ -> nil
    end
  end

  @doc ~S"""
  The merchant's warranty — `"1-year warranty"`, `"18-month warranty"` — or
  `nil` when they have stated none.

  Whole years are stated in years, because that is how a shopper reads them.
  Zero months is the absence of a warranty rather than a restriction on one —
  no warranty is the default state of an ordinary sale — so it says nothing.
  """
  def warranty(content) do
    case Map.get(content, :warranty_months) do
      months when is_integer(months) and months > 0 -> warranty_label(months)
      _ -> nil
    end
  end

  @doc """
  The merchant's warranty prose, or `nil` when blank. This is the detail behind
  the badge; it belongs on the policies page, which the badge links to.
  """
  def warranty_terms(content) do
    case Map.get(content, :warranty_terms) do
      text when is_binary(text) -> if String.trim(text) == "", do: nil, else: text
      _ -> nil
    end
  end

  @doc """
  Every term the store has actually stated, ready to render as badges. An empty
  list means the merchant has promised nothing, and the theme shows no strip.
  """
  def badges(assigns) do
    content = content(assigns)

    [returns(content), warranty(content)]
    |> Enum.reject(&is_nil/1)
  end

  defp warranty_label(months) when rem(months, 12) == 0 do
    case div(months, 12) do
      1 -> "1-year warranty"
      years -> "#{years}-year warranty"
    end
  end

  defp warranty_label(1), do: "1-month warranty"
  defp warranty_label(months), do: "#{months}-month warranty"
end
