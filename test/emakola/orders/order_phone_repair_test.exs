defmodule Emakola.Orders.OrderPhoneRepairTest do
  @moduledoc """
  Checkout wrote "+233" in front of whatever the buyer typed, so a Ghanaian's
  0244… landed as +2330244…. The data migration that repairs the stored orders
  runs in the release command; this pins its SQL to the same answer on a real
  database: only the +2330 rows change, and a second run changes nothing.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  @repair_sql """
  UPDATE orders
     SET shipping_address = jsonb_set(
           shipping_address,
           '{phone}',
           to_jsonb(regexp_replace(shipping_address->>'phone', '^\\+2330', '+233'))
         ),
         updated_at = NOW()
   WHERE shipping_address->>'phone' LIKE '+2330%'
  """

  defp order_with_phone(store, phone) do
    order = Factory.create_order!(store)

    Emakola.Repo.query!(
      "UPDATE orders SET shipping_address = jsonb_set(coalesce(shipping_address, '{}'::jsonb), '{phone}', to_jsonb($1::text)) WHERE id = $2",
      [phone, Ecto.UUID.dump!(order.id)]
    )

    order
  end

  defp stored_phone(order) do
    %{rows: [[phone]]} =
      Emakola.Repo.query!("SELECT shipping_address->>'phone' FROM orders WHERE id = $1", [
        Ecto.UUID.dump!(order.id)
      ])

    phone
  end

  test "strips the trunk zero from +2330 numbers and leaves correct ones alone" do
    store = Factory.create_store!()
    bad = order_with_phone(store, "+2330244000111")
    good = order_with_phone(store, "+233244000112")
    nigerian = order_with_phone(store, "+2348012345678")

    Emakola.Repo.query!(@repair_sql, [])

    assert stored_phone(bad) == "+233244000111"
    assert stored_phone(good) == "+233244000112"
    assert stored_phone(nigerian) == "+2348012345678"
  end

  test "a second run has nothing to do" do
    store = Factory.create_store!()
    order = order_with_phone(store, "+2330201112222")

    %{num_rows: 1} = Emakola.Repo.query!(@repair_sql, [])
    %{num_rows: 0} = Emakola.Repo.query!(@repair_sql, [])

    assert stored_phone(order) == "+233201112222"
  end
end
