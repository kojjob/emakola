defmodule Emakola.Suppliers.SalesSharing do
  @moduledoc "Tracked sales kits and first-sale attribution for Makola Earn listings."

  require Ash.Query

  alias Emakola.Suppliers.{ListingImporter, SalesShare, SalesShareConversion}

  @channels [:whatsapp, :facebook, :copy_link]

  def create_kit(actor, listing) do
    with {:ok, listings} <- ListingImporter.list(actor, listing.reseller_store_id),
         %{} = authorized <- Enum.find(listings, &(&1.id == listing.id)) do
      listing = Ash.load!(authorized, :reseller_product, authorize?: false)
      {:ok, Enum.map(@channels, &find_or_create!(listing, &1))}
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  def list_for_store(actor, store_id) do
    with {:ok, _listings} <- ListingImporter.list(actor, store_id) do
      SalesShare
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load([
        :store,
        :product,
        :order_count,
        :revenue,
        conversions: [order: :fulfillments]
      ])
      |> Ash.read(authorize?: false)
    end
  end

  def record_click(token) when is_binary(token) do
    SalesShare
    |> Ash.Query.filter(token == ^token)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{} = share} ->
        share
        |> Ash.Changeset.for_update(:record_click, %{})
        |> Ash.update(authorize?: false)
        |> normalize_side_effect()

      _ ->
        :ok
    end
  rescue
    _exception -> :ok
  end

  def record_click(_token), do: :ok

  def record_share(actor, store_id, share_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, share} <- Ash.get(SalesShare, share_id, authorize?: false),
         true <- share.store_id == store_id do
      share
      |> Ash.Changeset.for_update(:record_share, %{})
      |> Ash.update(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def record_conversion(%{attribution: attribution} = order) when is_map(attribution) do
    token = Map.get(attribution, "share_token") || Map.get(attribution, :share_token)

    with token when is_binary(token) <- token,
         {:ok, %{} = share} <- find_share(token, order.store_id),
         true <- order_contains_product?(order, share.product_id) do
      SalesShareConversion
      |> Ash.Changeset.for_create(:record, %{
        share_id: share.id,
        order_id: order.id,
        store_id: order.store_id,
        revenue: order.total
      })
      |> Ash.create(authorize?: false)
      |> normalize_side_effect()
    else
      _ -> :ok
    end
  rescue
    _exception -> :ok
  end

  def record_conversion(_order), do: :ok

  def url(%SalesShare{} = share) do
    share = Ash.load!(share, [:store, :product], authorize?: false)

    query =
      URI.encode_query(%{
        "share" => share.token,
        "utm_source" => Atom.to_string(share.channel),
        "utm_medium" => "earn_share",
        "utm_campaign" => "earn-#{String.slice(share.listing_id, 0, 8)}"
      })

    EmakolaWeb.SEO.Canonical.product_url(share.store, share.product) <> "?" <> query
  end

  def message(%SalesShare{} = share) do
    share = Ash.load!(share, :product, authorize?: false)
    "Take a look at #{share.product.title} on my Makola store: #{url(share)}"
  end

  def delivered_conversion?(%{order: %{fulfillments: fulfillments}})
      when is_list(fulfillments) and fulfillments != [],
      do: Enum.all?(fulfillments, &(&1.status == :delivered))

  def delivered_conversion?(_conversion), do: false

  defp find_or_create!(listing, channel) do
    SalesShare
    |> Ash.Query.filter(listing_id == ^listing.id and channel == ^channel)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{} = share} ->
        share

      _ ->
        Emakola.Suppliers.create_sales_share!(
          %{
            store_id: listing.reseller_store_id,
            listing_id: listing.id,
            product_id: listing.reseller_product_id,
            token: token(),
            channel: channel
          },
          authorize?: false
        )
    end
  end

  # A share promotes ONE product, so only an order containing that product is
  # its conversion. Matching on token + store alone credited a share with every
  # sale the shop made while its token sat in the buyer's session — tolerable
  # as an inflated analytic, indefensible once commission is paid on it.
  defp order_contains_product?(order, product_id) do
    order_id = order.id

    Emakola.Orders.LineItem
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load(:variant)
    |> Ash.read!(authorize?: false)
    |> Enum.any?(&(&1.variant && &1.variant.product_id == product_id))
  end

  defp find_share(token, store_id) do
    SalesShare
    |> Ash.Query.filter(token == ^token and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read_one(authorize?: false)
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}

  defp token, do: :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
  defp normalize_side_effect({:ok, _record}), do: :ok
  defp normalize_side_effect(_error), do: :ok
end
