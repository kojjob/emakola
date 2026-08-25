defmodule Emakola.Affiliates.PayoutStoreNeverLeaksTest do
  @moduledoc """
  An affiliate's payout container must never be mistaken for a shop.

  It is a `Store` row only because every payout rail in this system is keyed
  to one. It has no products, no storefront and no merchant behind it — so if
  it ever appears in a store listing, a search result or the sitemap, buyers
  see a shop that does not exist and cannot be bought from.

  This is the guard for the one real risk the shell-store approach takes.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Affiliates
  alias Emakola.Stores.Store

  setup do
    real = Emakola.Factory.create_store!(name: "Kente Kingdom")

    {:ok, affiliate} =
      Affiliates.register(%{
        phone: "0201234567",
        name: "Ama Mensah",
        momo_number: "0201234567",
        momo_provider: "mtn"
      })

    %{real: real, payout_store_id: affiliate.payout_store_id}
  end

  test "the public store directory excludes it", ctx do
    ids =
      Store
      |> Ash.Query.for_read(:list_active)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    assert ctx.real.id in ids
    refute ctx.payout_store_id in ids
  end

  test "the featured list excludes it", ctx do
    ids =
      Store
      |> Ash.Query.for_read(:list_featured)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    refute ctx.payout_store_id in ids
  end

  test "no read action returns it as a shop", _ctx do
    # A blunt sweep: whatever reads exist for listing shops, none may return a
    # payout container. Written as a sweep rather than one assertion per
    # action so a NEW listing action added later is covered by default.
    for action <- [:list_active, :list_featured] do
      kinds =
        Store
        |> Ash.Query.for_read(action)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.kind)
        |> Enum.uniq()

      refute :affiliate_payout in kinds,
             "#{action} returns an affiliate payout container as if it were a shop"
    end
  end
end
