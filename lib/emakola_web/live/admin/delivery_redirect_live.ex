defmodule EmakolaWeb.Admin.DeliveryRedirectLive do
  @moduledoc """
  Delivery settings live at `/admin/settings/delivery`, but most of what sits
  beside them in the merchant sidebar does not: payouts, earnings,
  verification and theme are all `/admin/<thing>`. A merchant reaching for
  delivery the same way lands on `/admin/delivery`, which answered with a
  404 — a dead end at the exact moment they were told to set delivery up
  (it is one of the five steps on the dashboard setup card).

  This keeps the guessable URL alive and sends it where delivery zones
  actually live, the same way `/admin/discounts` forwards to `/admin/coupons`.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/admin/settings/delivery")}
  end

  @impl true
  def render(assigns), do: ~H""
end
