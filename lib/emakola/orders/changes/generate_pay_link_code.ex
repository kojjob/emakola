defmodule Emakola.Orders.Changes.GeneratePayLinkCode do
  @moduledoc """
  Sets an 8-char lowercase base32 `code` (5 random bytes → a-z2-7, no
  ambiguous 0/1/8/9) on a new PayLink. ~40 bits — unguessable, short
  enough to read aloud over a call.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    code =
      :crypto.strong_rand_bytes(5)
      |> Base.encode32(case: :lower, padding: false)

    Ash.Changeset.force_change_attribute(changeset, :code, code)
  end
end
