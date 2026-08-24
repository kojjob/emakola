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
  alias Emakola.Marketing.Campaign

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
  Who a campaign would reach right now: customers of this store who have a
  phone number and have not opted out.

  Returned as a map so the caller can show the merchant a count *before* they
  confirm — the previous page let them "send" to an audience it never named.
  """
  def audience(_actor, store_id) when is_binary(store_id) do
    with {:ok, customers} <- reachable_customers(store_id) do
      {:ok, %{count: length(customers)}}
    end
  end

  @doc "The customer rows a send would target — phone present, not opted out."
  def reachable_customers(store_id) when is_binary(store_id) do
    Customer
    |> Ash.Query.filter(
      store_id == ^store_id and not is_nil(phone) and phone != "" and
        is_nil(marketing_opt_out_at)
    )
    |> Ash.read(authorize?: false)
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
