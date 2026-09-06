defmodule Emakola.Customers.GuestBackfill do
  @moduledoc """
  Links guest orders to customers by the phone in their shipping address.

  Storefront checkout created every guest order with `customer_id: nil`, so
  the customers page described only signed-in and pay-link buyers. This walks
  the orders that have no customer, oldest first, and finds or creates the
  customer for the phone each carries. Idempotent: an order with a customer is
  never revisited, and a phone seen twice makes one customer.

  Runs in a release too: `Emakola.Release.backfill_guest_customers/1`.
  """

  require Ash.Query

  alias Emakola.Customers.Customer
  alias Emakola.Orders.{CheckoutService, Order}

  @type result :: %{linked: non_neg_integer(), skipped: non_neg_integer()}

  @spec run(keyword()) :: result()
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, false)

    Order
    |> Ash.Query.filter(is_nil(customer_id))
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.stream!(authorize?: false)
    |> Enum.reduce(%{linked: 0, skipped: 0}, fn order, acc ->
      case phone_of(order) do
        nil ->
          %{acc | skipped: acc.skipped + 1}

        phone ->
          if not dry_run?, do: link!(order, phone)
          %{acc | linked: acc.linked + 1}
      end
    end)
  end

  defp phone_of(%Order{shipping_address: %{"phone" => phone}}) when is_binary(phone) do
    # A whitespace-only phone normalises to the bare country code ("+233")
    # in PhoneAuth — treating that as real would find-or-create the SAME
    # customer for every such order, merging unrelated buyers.
    if String.trim(phone) == "", do: nil, else: phone
  end

  defp phone_of(_order), do: nil

  defp link!(order, phone) do
    customer =
      Customer
      |> Ash.ActionInput.for_action(:find_or_create, %{
        email: CheckoutService.phone_placeholder_email(phone),
        store_id: order.store_id,
        name: order.shipping_address["name"],
        phone: phone
      })
      |> Ash.run_action!()

    order
    |> Ash.Changeset.for_update(:attach_customer, %{customer_id: customer.id})
    |> Ash.update!(authorize?: false)

    if newer?(order.inserted_at, customer.last_order_at) do
      customer
      |> Ash.Changeset.for_update(:backdate_last_order, %{last_order_at: order.inserted_at})
      |> Ash.update!(authorize?: false)
    end
  end

  defp newer?(_at, nil), do: true
  defp newer?(at, last), do: DateTime.compare(at, last) == :gt
end
