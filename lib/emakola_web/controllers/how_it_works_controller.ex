defmodule EmakolaWeb.HowItWorksController do
  @moduledoc """
  Serves the full Makola network explainer as a dead render.

  The page is intentionally static: it is public marketing content and does
  not need a LiveView process per visitor.
  """

  use EmakolaWeb, :controller

  def tour(conn, _params) do
    render(conn, :tour,
      layout: false,
      page_title: "Watch how Makola works — one sale, start to finish",
      meta_description:
        "Scroll through one connected Makola sale: a maker lists once, a shop stocks in one tap, the buyer pays with MoMo, delivery goes to the door, and the money shares itself.",
      og_image: url(~p"/images/og-image.png"),
      canonical_url: url(~p"/how-it-works/tour")
    )
  end

  def show(conn, _params) do
    render(conn, :show,
      layout: false,
      page_title: "How Makola Works — One Market, Every Stall Connected",
      meta_description:
        "See how Makola connects Ghanaian suppliers, online shops, shoppers, delivery, and automatic mobile-money settlement in one transparent sale.",
      og_image: url(~p"/images/og-image.png"),
      canonical_url: url(~p"/how-it-works"),
      preload_image: "/images/landing/hero-market-woman.jpg",
      json_ld: EmakolaWeb.Helpers.SEO.json_ld_organization()
    )
  end
end
