defmodule EmakolaWeb.Admin.CampaignLive.Index do
  @moduledoc """
  Campaigns — WhatsApp and SMS messages a merchant sends to their customers.

  This page previously rendered `sample_campaigns/0`: invented names, invented
  send counts, and "89% Opened / 34% Clicked" figures that describe nobody's
  shop — and that this platform cannot measure at all, since neither the SMS
  gateway nor the WhatsApp Business API reports opens without provider
  webhooks. Its Create and Delete buttons flashed success and saved nothing.

  The sending engine (`Emakola.Marketing.Campaign` + an Oban fan-out) is being
  built. Until it lands this page shows the merchant the truth: nothing has
  been sent, and sending is not available yet. An honest empty page beats a
  convincing dashboard describing a shop that does not exist.
  """
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Campaigns",
       active_nav: :campaigns,
       campaigns: []
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6">
      <.admin_page_header
        icon="hero-megaphone"
        title="Campaigns"
        subtitle="Message your customers on WhatsApp and SMS"
      />

      <div class="bg-white border border-border rounded-card p-12 text-center">
        <div class="w-16 h-16 rounded-card bg-primary-soft flex items-center justify-center mx-auto mb-5">
          <.icon name="hero-megaphone" class="size-8 text-primary" />
        </div>

        <p class="text-lg font-semibold text-slate-900">No campaigns yet</p>

        <p class="text-sm text-slate-500 mt-2 max-w-md mx-auto">
          Sending is not switched on yet. When it is, you will write one message
          here and send it to your customers.
        </p>
      </div>
    </div>
    """
  end
end
