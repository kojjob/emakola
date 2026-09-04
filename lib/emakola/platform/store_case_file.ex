defmodule Emakola.Platform.StoreCaseFile do
  @moduledoc """
  Read-only rollup behind the platform store detail page ("the case file"):
  order and money counts, open protection holds, per-store onboarding
  milestones, latest verification status, recent orders, and product photo
  URLs for the identity header.

  All reads are platform-side (authorize?: false); protection holds are the
  one tenant-scoped read. GMV here counts money that settled (successful
  payments including later-refunded ones) — the refund is reported in
  `refunds_count`, not as a GMV subtraction.
  """
  require Ash.Query

  alias Emakola.Catalog.Product
  alias Emakola.Orders.Order
  alias Emakola.Payments.Payment
  alias Emakola.Payments.ProtectionHold
  alias Emakola.Stores.StorePayoutAccount
  alias Emakola.Stores.StoreVerification

  @recent_orders_limit 5
  @photo_limit 4

  def load(store) do
    orders =
      Order
      |> Ash.Query.filter(store_id == ^store.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(authorize?: false)

    payments =
      Payment
      |> Ash.Query.filter(store_id == ^store.id)
      |> Ash.Query.select([:amount, :status, :refunded_amount])
      |> Ash.read!(authorize?: false)

    milestones = milestones(store, orders)

    %{
      orders_count: length(orders),
      gmv: settled_gmv(payments),
      holds_count: open_holds_count(store),
      refunds_count: Enum.count(payments, &refunded?/1),
      milestones: milestones,
      completed: milestones |> Map.values() |> Enum.count(& &1),
      verification_status: latest_verification_status(store),
      recent_orders: Enum.take(orders, @recent_orders_limit),
      product_photo_urls: product_photo_urls(store)
    }
  end

  # The platform's one GMV rule, shared with the dashboard tiles.
  defp settled_gmv(payments) do
    statuses = Emakola.Platform.Stats.gmv_statuses()

    payments
    |> Enum.filter(&(&1.status in statuses))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  defp refunded?(payment), do: is_integer(payment.refunded_amount) and payment.refunded_amount > 0

  defp open_holds_count(store) do
    ProtectionHold
    |> Ash.Query.filter(status == :held)
    |> Ash.Query.select([:id])
    |> Ash.read!(tenant: store.id, authorize?: false)
    |> length()
  end

  defp milestones(store, orders) do
    %{
      products: exists_for_store?(Product, store.id),
      live: store.active == true and store.status == :active,
      payout: exists_for_store?(StorePayoutAccount, store.id),
      kyc: exists_for_store?(Ash.Query.filter(StoreVerification, status == :approved), store.id),
      first_order: orders != []
    }
  end

  defp exists_for_store?(queryable, store_id) do
    queryable
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.Query.select([:id])
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> Kernel.!=([])
  end

  defp latest_verification_status(store) do
    StoreVerification
    |> Ash.Query.filter(store_id == ^store.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [latest | _] -> latest.status
      [] -> nil
    end
  end

  defp product_photo_urls(store) do
    Product
    |> Ash.Query.filter(store_id == ^store.id and status == :active)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(@photo_limit * 2)
    |> Ash.Query.load(:images)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&first_image_url/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(@photo_limit)
  end

  defp first_image_url(product) do
    case product.images do
      [%{thumbnail_url: url} | _] when is_binary(url) -> url
      [%{url: url} | _] when is_binary(url) -> url
      _ -> nil
    end
  end
end
