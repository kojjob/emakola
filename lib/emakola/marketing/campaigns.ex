defmodule Emakola.Marketing.Campaigns do
  @moduledoc """
  Coordination layer for merchant campaigns: drafting, sizing the audience,
  and the customer opt-out.

  Sending itself lives in `Emakola.Marketing.CampaignSendWorker` — a campaign
  fans out to hundreds of paid SMS messages, which belongs in a retryable job
  rather than a LiveView process.

  Every function is store-scoped. A merchant may only ever see and message
  their own customers.
  """

  require Ash.Query

  alias Emakola.Customers.Customer
  alias Emakola.Marketing.{Campaign, CampaignRecipient}

  @failed_recipients_limit 50

  @doc "Drafts a campaign. Nothing is sent until the send worker runs."
  def create(_actor, store_id, attrs) when is_binary(store_id) do
    Campaign
    |> Ash.Changeset.for_create(:create, Map.put(Map.new(attrs), :store_id, store_id))
    |> Ash.create()
  end

  @doc "The store's campaigns, newest first."
  def list(_actor, store_id) when is_binary(store_id) do
    Campaign
    |> Ash.Query.for_read(:for_store, %{store_id: store_id})
    |> Ash.read(authorize?: false)
  end

  @doc """
  Who a campaign to `audience` would reach right now.

  Returned as a map so the caller can show the merchant a count *before* they
  confirm — the previous page let them "send" to an audience it never named.
  A count, not a full read, of the reachable rows — this is called on every
  segment change and every draft row, not just at send time.
  """
  def audience(_actor, store_id, audience \\ :everyone) when is_binary(store_id) do
    count =
      store_id
      |> reachable_query(audience)
      |> Ash.count!(authorize?: false)

    {:ok, %{count: count}}
  end

  @doc "The customer rows a send would target: in the segment, phone present, not opted out."
  def reachable_customers(store_id, audience \\ :everyone) when is_binary(store_id) do
    store_id
    |> reachable_query(audience)
    |> Ash.read(authorize?: false)
  end

  defp reachable_query(store_id, audience) do
    store_id
    |> Emakola.Customers.Segments.query(audience)
    |> Ash.Query.filter(not is_nil(phone) and phone != "" and is_nil(marketing_opt_out_at))
  end

  @doc "One campaign, only if it belongs to the store."
  def get_for_store(store_id, campaign_id) when is_binary(store_id) and is_binary(campaign_id) do
    with {:ok, _} <- Ecto.UUID.cast(campaign_id),
         {:ok, %Campaign{store_id: ^store_id} = campaign} <-
           Ash.get(Campaign, campaign_id, authorize?: false) do
      {:ok, campaign}
    else
      _ -> {:error, :not_found}
    end
  end

  # A crafted id (e.g. id[]=x) arrives as a list/map, not a string — reject
  # it the same way as an unknown id, rather than crashing the LiveView.
  def get_for_store(_store_id, _campaign_id), do: {:error, :not_found}

  @doc """
  Up to #{@failed_recipients_limit} of a campaign's failed recipients.

  `CampaignRecipient` carries no `store_id` of its own — isolation comes from
  confirming the campaign belongs to this store first, the same structural
  check `get_for_store/2` already does. Capped so a store with thousands of
  customers on a failed campaign doesn't pull every row into a LiveView.
  """
  def failed_recipients(store_id, campaign_id) do
    with {:ok, campaign} <- get_for_store(store_id, campaign_id) do
      CampaignRecipient
      |> Ash.Query.for_read(:for_campaign, %{campaign_id: campaign.id})
      |> Ash.Query.filter(status == :failed)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.limit(@failed_recipients_limit)
      |> Ash.read(authorize?: false)
    end
  end

  @doc "Marks a draft campaign as sending, with its audience size at the moment of sending."
  def mark_sending(%Campaign{} = campaign, audience_size) do
    campaign
    |> Ash.Changeset.for_update(:mark_sending, %{audience_size: audience_size})
    |> Ash.update(authorize?: false)
  end

  @doc "Records that a customer no longer wants marketing messages."
  def opt_out(%Customer{} = customer) do
    customer
    |> Ash.Changeset.for_update(:opt_out_of_marketing, %{})
    |> Ash.update(authorize?: false)
  end

  @doc "Undoes an opt-out, at the customer's request."
  def opt_in(%Customer{} = customer) do
    customer
    |> Ash.Changeset.for_update(:opt_in_to_marketing, %{})
    |> Ash.update(authorize?: false)
  end
end
