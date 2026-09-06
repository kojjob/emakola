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
  require Logger

  alias Emakola.Customers.Customer
  alias Emakola.Orders.{CheckoutService, Order}

  @type result :: %{
          linked: non_neg_integer(),
          skipped: non_neg_integer(),
          failed: non_neg_integer()
        }

  @spec run(keyword()) :: result()
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, false)

    # Strategy stated, not inferred — this loop mutates `customer_id` on the
    # very rows the filter selects on, so which strategy Ash lands on is a
    # correctness question, not a performance one.
    #
    # `Order`'s default `:read` declares no pagination (only the named read at
    # order.ex:532 does), so `:full_read` is what Ash resolves to anyway;
    # pinning it means a later `pagination` block on that action cannot
    # silently switch this sweep to `:offset`, which WOULD skip rows — every
    # linked order leaves the filter, so each offset page would step past as
    # many unprocessed rows as it just linked.
    #
    # The cost is that every customer-less order is materialised at once. That
    # is the known ceiling here; it is a one-shot migration sweep whose input
    # set only shrinks, and correctness is worth more than the heap.
    Order
    |> Ash.Query.filter(is_nil(customer_id))
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.stream!(authorize?: false, stream_with: :full_read)
    |> Enum.reduce(%{linked: 0, skipped: 0, failed: 0}, fn order, acc ->
      case phone_of(order) do
        nil ->
          %{acc | skipped: acc.skipped + 1}

        phone ->
          cond do
            dry_run? -> %{acc | linked: acc.linked + 1}
            link_safely(order, phone) -> %{acc | linked: acc.linked + 1}
            true -> %{acc | failed: acc.failed + 1}
          end
      end
    end)
  end

  # One bad historical row (a name or phone that fails a resource
  # constraint the storefront didn't enforce when it was written) must not
  # abort the whole sweep. Logs only the order id and the exception's
  # module — never Exception.message/1, which would put the offending
  # name/phone value itself into the deploy log.
  defp link_safely(order, phone) do
    link!(order, phone)
    true
  rescue
    exception ->
      Logger.warning(
        "[guest_backfill] order #{order.id} failed to link: #{inspect(exception.__struct__)}"
      )

      false
  end

  # PhoneAuth.normalize/1 collapses any blank or digit-free phone to the bare
  # country code, with no national digits after it — this is that sentinel.
  @blank_phone Emakola.Accounts.PhoneAuth.normalize("")

  defp phone_of(%Order{shipping_address: %{"phone" => phone}}) when is_binary(phone) do
    # checkout_live.ex has normalised the shipping-address phone since before
    # this task existed, so a blank/whitespace phone typed at checkout may
    # already be stored as literally `@blank_phone` on historical orders, not
    # just as a raw blank string. Either way, treating it as real would
    # find-or-create the SAME customer for every such order, merging
    # unrelated buyers.
    if Emakola.Accounts.PhoneAuth.normalize(phone) == @blank_phone, do: nil, else: phone
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
