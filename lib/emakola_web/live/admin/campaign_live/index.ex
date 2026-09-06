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

  alias Emakola.Customers.Segments
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
      audience: :everyone,
      form: blank_form()
    )
  end

  defp blank_form(audience \\ :everyone) do
    to_form(%{"name" => "", "body" => "", "audience" => to_string(audience)}, as: :campaign)
  end

  defp load(socket) do
    store = socket.assigns[:current_store]
    actor = socket.assigns[:current_merchant]
    audience = socket.assigns[:audience] || :everyone

    {campaigns, audience_count, draft_audience_counts} =
      if store do
        {:ok, campaigns} = Campaigns.list(actor, store.id)
        {:ok, %{count: count}} = Campaigns.audience(actor, store.id, audience)
        {campaigns, count, draft_audience_counts(store.id, campaigns)}
      else
        {[], 0, %{}}
      end

    assign(socket,
      campaigns: campaigns,
      audience_count: audience_count,
      draft_audience_counts: draft_audience_counts,
      failed_recipients: failed_recipients_by_campaign(store, campaigns)
    )
  end

  # Every campaign the page offers a send button for — :failed included, or a
  # retry's confirm dialog would read "Send this to 0 customers?".
  #
  # The confirm dialog and the per-row "sending to N" flash need the count for
  # THAT campaign's own audience, not whatever segment is currently selected
  # in the draft form above.
  defp draft_audience_counts(store_id, campaigns) do
    campaigns
    |> Enum.filter(&(&1.status in [:draft, :failed]))
    |> Map.new(fn campaign ->
      {:ok, %{count: count}} = Campaigns.audience(nil, store_id, campaign.audience)
      {campaign.id, count}
    end)
  end

  defp count_for(socket, campaign),
    do: Map.get(socket.assigns.draft_audience_counts, campaign.id, 0)

  # The numbers a campaign was attempted on and failed — one bounded lookup
  # per sent campaign, not per row, and never more than
  # Campaigns.failed_recipients/2's own cap even on a store with thousands
  # of failures. Only campaigns whose lookup actually returns rows appear in
  # the map at all — the template gates on that, not on `failed_count > 0`,
  # so a lookup error or a stale `failed_count` never renders an empty list.
  defp failed_recipients_by_campaign(nil, _campaigns), do: %{}

  defp failed_recipients_by_campaign(store, campaigns) do
    campaigns
    |> Enum.filter(&(&1.failed_count > 0))
    |> Map.new(&{&1.id, failed_summary(store.id, &1)})
    |> Map.reject(fn {_id, summary} -> is_nil(summary) end)
  end

  defp failed_summary(store_id, campaign) do
    case Campaigns.failed_recipients(store_id, campaign.id) do
      {:ok, []} ->
        nil

      {:ok, recipients} ->
        %{recipients: recipients, more: max(campaign.failed_count - length(recipients), 0)}

      {:error, _} ->
        nil
    end
  end

  @impl true
  def handle_event("create", %{"campaign" => params}, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:noreply, put_flash(socket, :error, "Create your store first.")}

      %{id: store_id} ->
        with {:ok, name} <- as_binary(params["name"]),
             {:ok, body} <- as_binary(params["body"]),
             {:ok, audience_param} <- as_binary(params["audience"]) do
          audience = Emakola.SafeAtom.to_atom_in(audience_param, Segments.all(), :everyone)

          attrs = %{
            name: String.trim(name || ""),
            channel: :sms,
            body: String.trim(body || ""),
            audience: audience
          }

          case Campaigns.create(socket.assigns.current_merchant, store_id, attrs) do
            {:ok, _campaign} ->
              {:noreply,
               socket
               |> assign(form: blank_form(), audience: :everyone)
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
        else
          # A crafted param (e.g. campaign[name][x]=y) arrives as a map, not a
          # string — reject it the same way as a blank field, rather than
          # crashing inside String.trim/1.
          :error ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Give the campaign a name, and a message that is not empty or too long."
             )}
        end
    end
  end

  def handle_event("audience", %{"campaign" => params}, socket) do
    with {:ok, _name} <- as_binary(params["name"]),
         {:ok, _body} <- as_binary(params["body"]),
         {:ok, audience_param} <- as_binary(params["audience"]) do
      store = socket.assigns[:current_store]
      audience = Emakola.SafeAtom.to_atom_in(audience_param, Segments.all(), :everyone)
      count = audience_count_for(store, audience)

      {:noreply,
       assign(socket,
         audience: audience,
         audience_count: count,
         form: to_form(params, as: :campaign)
       )}
    else
      :error -> {:noreply, socket}
    end
  end

  def handle_event("send", %{"id" => id}, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:noreply, put_flash(socket, :error, "Create your store first.")}

      %{id: store_id} ->
        case Campaigns.get_for_store(store_id, id) do
          # :failed too — a campaign whose job was discarded is retryable.
          {:ok, %{status: status} = campaign} when status in [:draft, :failed] ->
            send_campaign(socket, campaign)

          {:ok, _not_sendable} ->
            {:noreply,
             socket
             |> load()
             |> put_flash(:error, "That campaign is already sending.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "That campaign is not yours to send.")}
        end
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # Insert first, mark :sending only once the job is actually queued — a
  # failed insert then leaves the campaign exactly as it was, nothing to
  # revert. states: :incomplete + period: :infinity means an in-flight job
  # for this campaign blocks a duplicate insert for as long as it takes to
  # finish, not just for a five-minute window.
  defp send_campaign(socket, campaign) do
    count = count_for(socket, campaign)

    %{"campaign_id" => campaign.id}
    |> CampaignSendWorker.new(
      unique: [period: :infinity, keys: [:campaign_id], states: :incomplete]
    )
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        Campaigns.mark_sending(campaign, count)

        {:noreply,
         socket
         |> load()
         |> put_flash(:info, "Sending to #{Emakola.Plural.count(count, "customer")}.")}

      _error ->
        {:noreply, put_flash(socket, :error, "Could not queue this campaign.")}
    end
  end

  defp audience_count_for(nil, _audience), do: 0

  defp audience_count_for(store, audience) do
    {:ok, %{count: count}} = Campaigns.audience(nil, store.id, audience)
    count
  end

  # A campaign only reaches :failed after a send was attempted and discarded,
  # so "Send" would read as though nothing had happened yet.
  defp send_label(:failed), do: "Try again"
  defp send_label(_status), do: "Send"

  defp as_binary(nil), do: {:ok, nil}
  defp as_binary(value) when is_binary(value), do: {:ok, value}
  defp as_binary(_value), do: :error

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
          <.form
            for={@form}
            id="campaign-form"
            phx-submit="create"
            phx-change="audience"
            class="space-y-4"
          >
            <.input field={@form[:name]} label="Name this campaign" placeholder="Weekend sale" />

            <.input
              field={@form[:audience]}
              type="select"
              label="Who is this for"
              options={Enum.map(Segments.all(), &{Segments.label(&1), &1})}
            />

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
              {@audience_count} {Segments.label(@audience) |> String.downcase()} with a phone
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
              <span class="text-xs font-medium text-slate-500">
                {Segments.label(campaign.audience)}
              </span>
              <.status_badge variant={:campaign} status={campaign.status} />

              <.admin_button
                :if={campaign.status in [:draft, :failed]}
                id={"send-campaign-#{campaign.id}"}
                phx-click="send"
                phx-value-id={campaign.id}
                data-confirm={"Send this to #{Emakola.Plural.count(Map.get(@draft_audience_counts, campaign.id, 0), "customer")}? Each message costs money."}
              >
                <.icon name="hero-paper-airplane" class="size-5" />{send_label(campaign.status)}
              </.admin_button>
            </div>
          </div>

          <p :if={campaign.status == :sent} class="text-xs text-slate-500 mt-3">
            {campaign.sent_count} sent{if campaign.failed_count > 0,
              do: " · #{campaign.failed_count} failed"}
          </p>

          <% failed = Map.get(@failed_recipients, campaign.id) %>
          <ul
            :if={failed}
            id={"campaign-#{campaign.id}-failed"}
            class="mt-2 space-y-1 text-xs text-slate-500"
          >
            <li class="font-semibold text-slate-700">Numbers that did not get it</li>
            <li :for={r <- failed.recipients}>{r.phone}: Not delivered</li>
            <li :if={failed.more > 0}>and {failed.more} more</li>
          </ul>
        </.admin_card>
      </div>
    </div>
    """
  end
end
