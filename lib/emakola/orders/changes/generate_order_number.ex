defmodule Emakola.Orders.Changes.GenerateOrderNumber do
  @moduledoc """
  Ash resource change that stamps a new order with its public order number
  (`ORD-YYYYMMDD-XXXXXX`).

  Cryptographically random 6-char suffix: 4 random bytes → base32 → first 6
  alphanumerics. Collision space is ~1 billion per (store_id, date), so the
  practical collision rate is ~0% under any realistic order volume.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    date = Date.utc_today() |> Calendar.strftime("%Y%m%d")

    random =
      :crypto.strong_rand_bytes(4)
      |> Base.encode32(padding: false, case: :upper)
      |> binary_part(0, 6)

    Ash.Changeset.force_change_attribute(changeset, :order_number, "ORD-#{date}-#{random}")
  end
end
