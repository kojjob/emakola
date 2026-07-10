defmodule Emakola.Suppliers.Franchises do
  @moduledoc "Authorized micro-franchise packages for product sales only; never recruitment compensation."

  require Ash.Query

  alias Emakola.Suppliers.{FranchiseEnrollment, FranchisePackage, Network, Offers}
  @channels [:storefront, :whatsapp, :facebook, :in_person]

  def create(actor, supplier_store_id, attrs) do
    with :ok <- ensure_store_access(actor, supplier_store_id),
         {:ok, offer_ids} <-
           validate_owned_offers(actor, supplier_store_id, value(attrs, :offer_ids)),
         {:ok, commission} <- commission(value(attrs, :commission_bps)),
         {:ok, channels} <- channels(value(attrs, :channel_permissions)) do
      FranchisePackage
      |> Ash.Changeset.for_create(:create, %{
        supplier_store_id: supplier_store_id,
        name: value(attrs, :name),
        offer_ids: offer_ids,
        training: value(attrs, :training) || %{},
        brand_rules: value(attrs, :brand_rules) || %{},
        channel_permissions: channels,
        territory: value(attrs, :territory),
        commission_bps: commission
      })
      |> Ash.create(authorize?: false)
    end
  end

  def publish(actor, supplier_store_id, package_id) do
    with {:ok, package} <- owned_package(actor, supplier_store_id, package_id),
         {:ok, offers} <- Offers.list_owned(actor, supplier_store_id),
         true <-
           package.offer_ids != [] and
             Enum.all?(package.offer_ids, fn id ->
               Enum.any?(offers, &(&1.id == id and &1.status == :published))
             end),
         true <- map_size(package.training) > 0,
         true <- map_size(package.brand_rules) > 0,
         true <- package.channel_permissions != [] do
      package |> Ash.Changeset.for_update(:publish, %{}) |> Ash.update(authorize?: false)
    else
      false -> {:error, :package_incomplete}
      error -> error
    end
  end

  def discover(actor, reseller_store_id) do
    with :ok <- ensure_store_access(actor, reseller_store_id),
         {:ok, connections} <- Network.list_for_store(actor, reseller_store_id) do
      suppliers =
        connections
        |> Enum.filter(&(&1.reseller_store_id == reseller_store_id and &1.status == :active))
        |> Enum.map(& &1.wholesaler_store_id)

      FranchisePackage
      |> Ash.Query.filter(status == :published and supplier_store_id in ^suppliers)
      |> Ash.Query.load(:supplier_store)
      |> Ash.read(authorize?: false)
    end
  end

  def apply(actor, reseller_store_id, package_id, accept_terms?) do
    with true <- accept_terms?,
         {:ok, packages} <- discover(actor, reseller_store_id),
         %{} = package <- Enum.find(packages, &(&1.id == package_id)) do
      FranchiseEnrollment
      |> Ash.Changeset.for_create(:apply, %{
        package_id: package.id,
        reseller_store_id: reseller_store_id,
        terms_accepted_at: DateTime.utc_now()
      })
      |> Ash.create(authorize?: false)
    else
      false -> {:error, :terms_must_be_accepted}
      nil -> {:error, :package_not_available}
      error -> error
    end
  end

  def approve(actor, supplier_store_id, enrollment_id) do
    with :ok <- ensure_store_access(actor, supplier_store_id),
         {:ok, enrollment} <- Ash.get(FranchiseEnrollment, enrollment_id, authorize?: false),
         {:ok, package} <- Ash.get(FranchisePackage, enrollment.package_id, authorize?: false),
         true <- package.supplier_store_id == supplier_store_id do
      enrollment |> Ash.Changeset.for_update(:approve, %{}) |> Ash.update(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp validate_owned_offers(actor, store_id, ids) when is_list(ids) and ids != [] do
    with {:ok, offers} <- Offers.list_owned(actor, store_id),
         true <- Enum.all?(ids, fn id -> Enum.any?(offers, &(&1.id == id)) end) do
      {:ok, Enum.uniq(ids)}
    else
      false -> {:error, :offer_not_owned}
      error -> error
    end
  end

  defp validate_owned_offers(_actor, _store_id, _ids), do: {:error, :offers_required}

  defp commission(value) when is_integer(value) and value in 1..10_000, do: {:ok, value}

  defp commission(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> commission(number)
      _ -> {:error, :invalid_commission}
    end
  end

  defp commission(_value), do: {:error, :invalid_commission}

  defp channels(values) when is_list(values) do
    parsed =
      Enum.map(values, fn value ->
        if is_atom(value), do: value, else: Enum.find(@channels, &(Atom.to_string(&1) == value))
      end)

    if parsed != [] and Enum.all?(parsed, &(&1 in @channels)),
      do: {:ok, Enum.uniq(parsed)},
      else: {:error, :invalid_channels}
  end

  defp channels(_values), do: {:error, :invalid_channels}

  defp owned_package(actor, store_id, id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, package} <- Ash.get(FranchisePackage, id, authorize?: false),
         true <- package.supplier_store_id == store_id do
      {:ok, package}
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
