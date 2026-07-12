defmodule EmakolaWeb.LandingController do
  @moduledoc """
  Serves the marketing landing page as a dead render — the highest-traffic
  anonymous page no longer holds a LiveView process per visitor.
  """

  use EmakolaWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      layout: false,
      page_title: "Makola — Start Selling Online in Ghana | Mobile Money & Dropshipping",
      meta_description:
        "Create your online store in Ghana. Accept MTN MoMo and Vodafone Cash, dropship from local suppliers, and send WhatsApp order updates. Free to start.",
      og_image: url(~p"/images/og-image.png"),
      canonical_url: url(~p"/"),
      preload_image: "/images/landing/hero-market-woman.jpg",
      json_ld: EmakolaWeb.LandingHTML.json_ld()
    )
  end
end
