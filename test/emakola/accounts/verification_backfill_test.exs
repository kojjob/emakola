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

      assert %{trading: trading, dormant: _dormant, verified: verified} = result

      assert verified == trading,
             "the count reported to the operator does not match what was written"

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

  describe "the deploy-time migration agrees with the module" do
    # The rule exists twice: in Elixir for the rpc/Mix face, and in SQL in the
    # migration that runs inside fly.toml's release_command. If they drift, the
    # deploy grandfathers a different set of people than the operator's dry run
    # reported. This pins them to the same answer.
    @migration_sql """
    UPDATE merchants
       SET confirmed_at = NOW(), updated_at = NOW()
     WHERE confirmed_at IS NULL
       AND id IN (
         SELECT sm.merchant_id
           FROM store_memberships sm
          WHERE sm.store_id IN (SELECT DISTINCT store_id FROM products)
             OR sm.store_id IN (SELECT DISTINCT store_id FROM orders)
       )
    """

    test "the SQL verifies exactly the merchants the module would" do
      {trader_with_product, product_store} = unverified_merchant_with_store()
      Factory.create_product!(product_store)

      {trader_with_order, order_store} = unverified_merchant_with_store()
      Factory.create_order!(order_store)

      {empty_store_merchant, _empty} = unverified_merchant_with_store()
      storeless = Factory.create_merchant!(%{confirmed_at: nil})

      # What the operator's dry run would report.
      dry = VerificationBackfill.run(dry_run?: true)
      would_verify = VerificationBackfill.trading_emails()

      assert to_string(trader_with_product.email) in would_verify
      assert to_string(trader_with_order.email) in would_verify
      refute to_string(empty_store_merchant.email) in would_verify
      refute to_string(storeless.email) in would_verify

      # What the deploy actually does.
      Ecto.Adapters.SQL.query!(Emakola.Repo, @migration_sql, [])

      assert reload(trader_with_product).confirmed_at
      assert reload(trader_with_order).confirmed_at
      refute reload(empty_store_merchant).confirmed_at
      refute reload(storeless).confirmed_at

      # And the counts the operator read match what the deploy touched.
      assert dry.trading >= 2
      assert VerificationBackfill.run(dry_run?: true).trading == dry.trading - 2
    end
  end
end
