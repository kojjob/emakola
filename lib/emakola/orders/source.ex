defmodule Emakola.Orders.Source do
  @moduledoc """
  Where an order came from, in the same buckets storefront visits use, plus
  the two rails that are their own channel: pay links and susu plans.

  Read from what the order already carries. `attribution` is written by
  `EmakolaWeb.Plugs.UtmCapture` at checkout and at pay links; nothing else
  is tracked, so nothing else is claimed.
  """

  alias Emakola.Orders.Order

  @utm %{
    "instagram" => :instagram,
    "tiktok" => :tiktok,
    "whatsapp" => :whatsapp,
    "facebook" => :facebook,
    "twitter" => :x,
    "x" => :x,
    "qr" => :qr,
    "google" => :search,
    "bing" => :search,
    "search" => :search,
    "direct" => :direct
  }

  @labels %{
    whatsapp: "WhatsApp",
    instagram: "Instagram",
    tiktok: "TikTok",
    facebook: "Facebook",
    x: "X",
    qr: "QR code",
    search: "Google search",
    pay_link: "Pay link",
    susu: "Susu plan",
    direct: "Typed the link or saved it",
    other: "Somewhere else"
  }

  @type source ::
          :whatsapp
          | :instagram
          | :tiktok
          | :facebook
          | :x
          | :qr
          | :search
          | :pay_link
          | :susu
          | :direct
          | :other

  @spec of(Order.t()) :: source()
  def of(%Order{pay_link_id: id}) when is_binary(id), do: :pay_link
  def of(%Order{susu_plan_id: id}) when is_binary(id), do: :susu
  def of(%Order{attribution: %{"click_to_whatsapp" => true}}), do: :whatsapp

  def of(%Order{attribution: %{"utm_source" => utm}}) when is_binary(utm) do
    Map.get(@utm, utm |> String.trim() |> String.downcase(), :other)
  end

  def of(%Order{}), do: :direct

  @spec label(source()) :: String.t()
  def label(source), do: Map.fetch!(@labels, source)

  @doc """
  Every source this module can label, source atom to label text.

  `Emakola.Analytics.StoreVisit`'s `:source` attribute shares this atom set;
  a test asserts that constraint's `one_of` list stays a subset of these
  keys, so a visit bucket added without a label fails a test instead of
  raising for a merchant on `/admin/reports`.
  """
  @spec labels() :: %{source() => String.t()}
  def labels, do: @labels

  @doc "Orders and money per source, biggest money first."
  @spec tally([Order.t()]) :: [
          %{
            source: source(),
            label: String.t(),
            orders: non_neg_integer(),
            money: non_neg_integer()
          }
        ]
  def tally(orders) do
    orders
    |> Enum.group_by(&of/1)
    |> Enum.map(fn {source, rows} ->
      %{
        source: source,
        label: label(source),
        orders: length(rows),
        money: rows |> Enum.map(&(&1.total || 0)) |> Enum.sum()
      }
    end)
    |> Enum.sort_by(&{-&1.money, -&1.orders})
  end
end
