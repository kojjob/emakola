defmodule Emakola.Repo.Migrations.StripTrunkZeroFromOrderPhones do
  @moduledoc """
  Repairs buyer phones that checkout stored with the trunk zero.

  Checkout wrote "+233" in front of whatever the buyer typed, so the 0244… a
  Ghanaian types was stored as +2330244… — a number no SMS or WhatsApp gateway
  can deliver to. 15 of the 35 orders in production carried it on 1 Sep 2026.
  Checkout now normalises to E.164 before storing; this fixes what was already
  written.

  Only +2330 numbers change (the bug could produce nothing else), so a correct
  +233 or +234 number is untouched and a re-run is a no-op.
  """
  use Ecto.Migration

  def up do
    execute("""
    UPDATE orders
       SET shipping_address = jsonb_set(
             shipping_address,
             '{phone}',
             to_jsonb(regexp_replace(shipping_address->>'phone', '^\\+2330', '+233'))
           ),
           updated_at = NOW()
     WHERE shipping_address->>'phone' LIKE '+2330%'
    """)
  end

  def down do
    # Deliberately irreversible: putting the trunk zero back would re-break the
    # numbers, and there is no way to tell a repaired row from a correct one.
    :ok
  end
end
