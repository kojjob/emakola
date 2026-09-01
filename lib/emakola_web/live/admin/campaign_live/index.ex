defmodule EmakolaWeb.Admin.CampaignLive.Index do
  @moduledoc """
  Campaigns — one SMS, sent to the store's own customers.

  This page previously rendered invented campaigns with "89% Opened" and
  "34% Clicked", and its buttons flashed success while saving nothing. Every
  number here is now the merchant's own, and the only counts shown are of
  messages this platform actually attempted: neither the SMS gateway nor the
  WhatsApp API reports opens without webhooks we do not receive.

  The audience count is deliberately visible *before* the merchant writes
  anything — a campaign costs real money per message, so "who will this
  reach" should not be a surprise revealed after they press send.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Marketing.{Campaigns, CampaignSendWorker}

  @body_limit 480

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign_defaults() |> load()}
  end

  defp assign_defaults(socket) do
    assign(socket,
      page_title: "Campaigns",
      active_nav: :campaigns,
      body_limit: @body_limit,
      form: blank_form()
    )
  end

  defp blank_form, do: to_form(%{"name" => "", "body" => ""}, as: :campaign)

  defp load(socket) do
    store = socket.assigns[:current_store]
    actor = socket.assigns[:current_merchant]

    {campaigns, audience} =
      if store do
        {:ok, campaigns} = Campaigns.list(actor, store.id)
        {:ok, %{count: count}} = Campaigns.audience(actor, store.id)
        {campaigns, count}
      else
        {[], 0}
      end

    assign(socket, campaigns: campaigns, audience_count: audience)
  end

  @impl true
  def handle_event("create", %{"campaign" => params}, socket) do
    store = socket.assigns[:current_store]

    attrs = %{
      name: String.trim(params["name"] || ""),
      channel: :sms,
      body: String.trim(params["body"] || "")
    }

    case Campaigns.create(socket.assigns.current_merchant, store.id, attrs) do
      {:ok, _campaign} ->
        {:noreply,
         socket
         |> assign(form: blank_form())
         |> load()
         |> put_flash(:info, "Campaign saved. Send it when you are ready.")}

      {:error, _error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Give the campaign a name, and a message that is not empty or too long."
         )}
    end
  end

  def handle_event("send", %{"id" => id}, socket) do
    # Fan-out is a paid, retryable job — never inline in the LiveView process.
    %{"campaign_id" => id}
    |> CampaignSendWorker.new()
    |> Oban.insert()

    {:noreply,
     socket
     |> load()
     |> put_flash(
       :info,
       "Sending to #{Emakola.Plural.count(socket.assigns.audience_count, "customer")}."
     )}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1200px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        icon="hero-megaphone"
        title="Campaigns"
        subtitle="One message, sent to your customers"
      />

      <div class="grid grid-cols-1 lg:grid-cols-[minmax(0,1fr)_320px] gap-6">
        <.admin_card class="p-6">
          <.form for={@form} id="campaign-form" phx-submit="create" class="space-y-4">
            <.input field={@form[:name]} label="Name this campaign" placeholder="Weekend sale" />

            <div>
              <.input
                field={@form[:body]}
                type="textarea"
                label="Your message"
                rows="4"
                maxlength={@body_limit}
                placeholder="20% off this weekend only."
              />
              <p class="text-xs text-slate-500 mt-1">
                Up to {@body_limit} letters. Longer messages cost more to send.
              </p>
            </div>

            <.admin_button type="submit">
              <.icon name="hero-plus" class="size-5" /> Save campaign
            </.admin_button>
          </.form>
        </.admin_card>

        <.stat_card
          id="campaign-audience"
          label="Customers you can reach"
          value={@audience_count}
          tone={:info}
        >
          <:icon><.icon name="hero-users" class="size-7" /></:icon>
          <:delta>
            <span id="campaign-audience-count" class="text-xs font-semibold text-slate-500">
              {@audience_count} with a phone number
            </span>
          </:delta>
        </.stat_card>
      </div>

      <div :if={@campaigns == []} class="bg-white border border-border rounded-card p-12 text-center">
        <div class="w-16 h-16 rounded-card bg-primary-soft flex items-center justify-center mx-auto mb-5">
          <.icon name="hero-megaphone" class="size-8 text-primary" />
        </div>
        <p class="text-lg font-semibold text-slate-900">No campaigns yet</p>
        <p class="text-sm text-slate-500 mt-2">Write your first message above.</p>
      </div>

      <div :if={@campaigns != []} id="campaigns" class="space-y-3">
        <.admin_card :for={campaign <- @campaigns} id={"campaign-#{campaign.id}"} class="p-5">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="min-w-0">
              <p class="font-semibold text-slate-900">{campaign.name}</p>
              <p class="text-sm text-slate-500 mt-1 break-words">{campaign.body}</p>
            </div>

            <div class="flex items-center gap-3 shrink-0">
              <.status_badge variant={:campaign} status={campaign.status} />

              <.admin_button
                :if={campaign.status == :draft}
                id={"send-campaign-#{campaign.id}"}
                phx-click="send"
                phx-value-id={campaign.id}
                data-confirm={"Send this to #{Emakola.Plural.count(@audience_count, "customer")}? Each message costs money."}
              >
                <.icon name="hero-paper-airplane" class="size-5" /> Send
              </.admin_button>
            </div>
          </div>

          <p :if={campaign.status == :sent} class="text-xs text-slate-500 mt-3">
            {campaign.sent_count} sent{if campaign.failed_count > 0,
              do: " · #{campaign.failed_count} failed"}
          </p>
        </.admin_card>
      </div>
    </div>
    """
  end
end
