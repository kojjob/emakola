defmodule Emakola.Affiliates.Programme do
  @moduledoc """
  A merchant's affiliate programme, and the links it mints.

  Turning it on is one decision — a rate — and it applies to the whole shop.
  Per-product rates were deliberately left out: this audience is being asked
  to understand commission at all for the first time, and one number they can
  say out loud ("I pay ten percent") is worth more than a pricing matrix.
  """

  alias Emakola.Affiliates.{Affiliate, AffiliateLink, AffiliateProgramme}

  @doc "Turns the programme on at `commission_bps`, or changes the rate."
  def enable(store_id, commission_bps) when is_binary(store_id) and is_integer(commission_bps) do
    AffiliateProgramme
    |> Ash.Changeset.for_create(:enable, %{store_id: store_id, commission_bps: commission_bps})
    |> Ash.create(authorize?: false)
  end

  @doc "Stops paying commission, without forgetting the rate."
  def disable(store_id) when is_binary(store_id) do
    case get(store_id) do
      {:ok, programme} ->
        programme
        |> Ash.Changeset.for_update(:disable, %{})
        |> Ash.update(authorize?: false)

      error ->
        error
    end
  end

  @doc "The store's programme, active or not."
  def get(store_id) when is_binary(store_id) do
    AffiliateProgramme
    |> Ash.Query.for_read(:for_store, %{store_id: store_id})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %AffiliateProgramme{} = programme} -> {:ok, programme}
      _ -> {:error, :not_found}
    end
  end

  @doc "Every programme row for a store — one, or none."
  def list_all(store_id) when is_binary(store_id) do
    AffiliateProgramme
    |> Ash.Query.for_read(:for_store, %{store_id: store_id})
    |> Ash.read(authorize?: false)
  end

  @doc "Whether this shop is paying commission right now."
  def enabled?(store_id) when is_binary(store_id) do
    match?({:ok, %{active: true}}, get(store_id))
  end

  @doc """
  The affiliate's link for one product, minted on first ask and stable after.

  Refuses while the programme is off: a link that cannot pay is worse than no
  link, because the affiliate shares it and earns nothing.
  """
  def link_for(%Affiliate{} = affiliate, store_id, product_id) do
    if enabled?(store_id) do
      AffiliateLink
      |> Ash.Changeset.for_create(:mint, %{
        affiliate_id: affiliate.id,
        store_id: store_id,
        product_id: product_id,
        token: mint_token()
      })
      |> Ash.create(authorize?: false)
    else
      {:error, :programme_inactive}
    end
  end

  @doc "Every link an affiliate holds."
  def links_for(%Affiliate{} = affiliate) do
    AffiliateLink
    |> Ash.Query.for_read(:for_affiliate, %{affiliate_id: affiliate.id})
    |> Ash.read(authorize?: false)
  end

  @doc "Resolves a token from a URL back to the link it belongs to."
  def find_link(token) when is_binary(token) do
    AffiliateLink
    |> Ash.Query.for_read(:by_token, %{token: token})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %AffiliateLink{} = link} -> {:ok, link}
      _ -> {:error, :not_found}
    end
  end

  @doc "Counts a visit. Never the basis for money — see AffiliateLink."
  def record_click(token) when is_binary(token) do
    with {:ok, link} <- find_link(token) do
      link
      |> Ash.Changeset.for_update(:record_click, %{})
      |> Ash.update(authorize?: false)
    end
  end

  @doc "The shareable URL: the product page, carrying the token."
  def url(%AffiliateLink{} = link) do
    store = Ash.get!(Emakola.Stores.Store, link.store_id, authorize?: false)
    product = Ash.get!(Emakola.Catalog.Product, link.product_id, authorize?: false)

    query =
      URI.encode_query(%{
        "aff" => link.token,
        "utm_source" => "affiliate",
        "utm_medium" => "affiliate_link"
      })

    EmakolaWeb.SEO.Canonical.product_url(store, product) <> "?" <> query
  end

  # 18 bytes of randomness, url-safe — the same shape SalesSharing already
  # uses for its share tokens.
  defp mint_token, do: 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
