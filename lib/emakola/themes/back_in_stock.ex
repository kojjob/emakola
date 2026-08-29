defmodule Emakola.Themes.BackInStock do
  @moduledoc """
  What a store can truthfully offer a shopper who arrives after the last one
  sold.

  Themes design this differently on purpose — a black bar, a produce note, a
  stock readout, the seller's own voice — because a sold-out moment should
  sound like the shop it happened in. What must never drift is the promise
  underneath, and that lives here: one prefilled WhatsApp message to the
  merchant.

  A store that has given no WhatsApp number has no channel to promise, so this
  returns `nil` and the theme renders nothing at all. That rule is the reason
  this module exists rather than six copies of a URL.

  Sibling of `Emakola.Themes.Delivery`, which does the same job for what a
  store may say about delivery.
  """

  @doc """
  The prefilled WhatsApp URL for a back-in-stock ask, or `nil` when the
  merchant has given no number.
  """
  def whatsapp_url(store, product) do
    case digits(Map.get(store, :whatsapp_number)) do
      "" -> nil
      number -> "https://wa.me/#{number}?text=#{URI.encode(message(store, product))}"
    end
  end

  defp message(store, product) do
    "Hi #{store.name}, please tell me when #{product.title} is back in stock."
  end

  defp digits(number), do: number |> to_string() |> String.replace(~r/[^\d]/, "")
end
