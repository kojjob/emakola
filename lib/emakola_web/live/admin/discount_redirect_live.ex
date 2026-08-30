defmodule EmakolaWeb.Admin.DiscountRedirectLive do
  @moduledoc """
  `/admin/discounts` used to render a page built from invented discount codes,
  usage counts and date ranges. The real feature is `Emakola.Marketing.Coupon`,
  and `/admin/coupons` has always been its working page — the sidebar simply
  pointed at the wrong one.

  This keeps the old URL alive for bookmarks and sends it where the merchant's
  own discounts actually live.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/admin/coupons")}
  end

  @impl true
  def render(assigns), do: ~H""
end
