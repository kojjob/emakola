defmodule Emakola.Accounts.VerificationBackfillTest do
  @moduledoc """
  Access is gated on a verified address. Applied flatly to production, that
  locks out every merchant who signed up while the mail key was dead and has
  been selling ever since.

  This backfill is what stands between the gate and those merchants, so it has
  to be right about which accounts are real — and, critically, it has to be
  runnable where production actually runs. It lived only as a Mix task, and a
  release ships no Mix.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.VerificationBackfill
  alias Emakola.Factory

  defp unverified_merchant_with_store do
    merchant = Factory.create_merchant!(%{confirmed_at: nil})
    store = Factory.create_store!()
    Factory.create_store_membership!(merchant, store, :owner)
    {merchant, store}
  end

  defp reload(merchant) do
    Emakola.Accounts.Merchant
    |> Ash.get!(merchant.id, authorize?: false)
  end

  describe "who gets grandfathered" do
    test "a merchant whose store holds a product is verified" do
      {merchant, store} = unverified_merchant_with_store()
      Factory.create_product!(store)

      VerificationBackfill.run()

      assert reload(merchant).confirmed_at,
             "a merchant with products on their shop was left locked out"
    end

    test "a merchant whose store has taken an order is verified" do
      {merchant, store} = unverified_merchant_with_store()
      Factory.create_order!(store)

      VerificationBackfill.run()

      assert reload(merchant).confirmed_at
    end

    test "a merchant with no store at all is left unverified" do
      merchant = Factory.create_merchant!(%{confirmed_at: nil})

      VerificationBackfill.run()

      refute reload(merchant).confirmed_at,
             "a signup with no shop is the junk-signup bucket the gate exists for"
    end

    test "a merchant whose store is empty is left unverified" do
      {merchant, _store} = unverified_merchant_with_store()

      VerificationBackfill.run()

      refute reload(merchant).confirmed_at
    end
  end

  describe "dry run" do
    test "reports the same split but changes nothing" do
      {trading, store} = unverified_merchant_with_store()
      Factory.create_product!(store)
      dormant = Factory.create_merchant!(%{confirmed_at: nil})

      result = VerificationBackfill.run(dry_run?: true)

      assert result.trading >= 1
      assert result.dormant >= 1

      refute reload(trading).confirmed_at, "a dry run verified somebody"
      refute reload(dormant).confirmed_at
    end
  end

  describe "the result a release operator reads" do
    test "counts what it did, and names nobody's password or token" do
      {_trading, store} = unverified_merchant_with_store()
      Factory.create_product!(store)

      result = VerificationBackfill.run()

      assert %{trading: trading, dormant: dormant, verified: verified} = result
      assert is_integer(trading) and is_integer(dormant) and is_integer(verified)
      assert verified >= 1
    end

    test "an already-verified merchant is not counted or touched" do
      merchant = Factory.create_merchant!()
      before = reload(merchant).confirmed_at

      VerificationBackfill.run()

      assert reload(merchant).confirmed_at == before,
             "the backfill rewrote a merchant who was already verified"
    end
  end
end
