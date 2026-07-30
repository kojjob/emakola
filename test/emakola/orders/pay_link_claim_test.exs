defmodule Emakola.Orders.PayLinkClaimTest do
  use Emakola.DataCase, async: false

  alias Emakola.Orders.{PayLink, PayLinkClaim}

  defp custom_link_and_order(store) do
    link =
      PayLink
      |> Ash.Changeset.for_create(:create, %{
        store_id: store.id,
        type: :custom,
        title: "Deal",
        amount: 25_000
      })
      |> Ash.create!(authorize?: false)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Ama",
        customer_phone: "0201234567",
        pay_link_id: link.id
      )

    {link, order}
  end

  test "first claim marks the link paid" do
    store = Emakola.Factory.create_store!()
    {link, order} = custom_link_and_order(store)

    assert :ok = PayLinkClaim.claim_for_order(order.id)

    assert Ash.get!(PayLink, link.id, authorize?: false, tenant: store.id).status == :paid
  end

  test "second claim flags the second order for refund attention" do
    store = Emakola.Factory.create_store!()
    {link, order1} = custom_link_and_order(store)

    {:ok, order2} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Kofi",
        customer_phone: "0209876543",
        pay_link_id: link.id
      )

    assert :ok = PayLinkClaim.claim_for_order(order1.id)
    assert :ok = PayLinkClaim.claim_for_order(order2.id)

    reloaded = Ash.get!(Emakola.Orders.Order, order2.id, authorize?: false, tenant: store.id)
    assert reloaded.notes =~ "already used"
  end

  test "retrying the losing order's claim appends the refund note exactly once" do
    store = Emakola.Factory.create_store!()
    {link, order1} = custom_link_and_order(store)

    {:ok, order2} =
      Emakola.Orders.CheckoutService.checkout_custom!(
        store.id,
        %{title: "Deal", unit_price: 25_000},
        customer_name: "Kofi",
        customer_phone: "0209876543",
        pay_link_id: link.id
      )

    assert :ok = PayLinkClaim.claim_for_order(order1.id)
    assert :ok = PayLinkClaim.claim_for_order(order2.id)
    # Simulates an Oban retry of the SAME losing order's webhook job.
    assert :ok = PayLinkClaim.claim_for_order(order2.id)
    assert :ok = PayLinkClaim.claim_for_order(order2.id)

    reloaded = Ash.get!(Emakola.Orders.Order, order2.id, authorize?: false, tenant: store.id)

    assert Regex.scan(~r/already used/, reloaded.notes) |> length() == 1
  end

  test "retrying the same order's claim is idempotent — no refund note, stays paid" do
    store = Emakola.Factory.create_store!()
    {link, order} = custom_link_and_order(store)

    assert :ok = PayLinkClaim.claim_for_order(order.id)
    assert :ok = PayLinkClaim.claim_for_order(order.id)

    assert Ash.get!(PayLink, link.id, authorize?: false, tenant: store.id).status == :paid

    reloaded = Ash.get!(Emakola.Orders.Order, order.id, authorize?: false, tenant: store.id)
    refute "#{reloaded.notes}" =~ "already used"
  end

  test "orders without a pay link are a no-op" do
    store = Emakola.Factory.create_store!()

    order =
      Emakola.Orders.Order
      |> Ash.Changeset.for_create(:create, %{store_id: store.id})
      |> Ash.create!(authorize?: false)

    assert :ok = PayLinkClaim.claim_for_order(order.id)
  end

  # A genuine two-connection blocking-lock race (two overlapping
  # transactions actually contending for the same row) can't be exercised
  # under this repo's Ecto Sandbox setup: an `async: false` DataCase test
  # runs in `shared` mode — a single checked-out connection the whole test
  # (and anything it spawns) shares — and `Emakola.AsyncSandbox.run_async/1`
  # (used elsewhere for genuinely parallel Tasks, e.g.
  # catalog_edge_cases_test.exs's "concurrent stock adjustments") works via
  # `Sandbox.allow/3`, which lets another process borrow the SAME
  # connection rather than open a second one — so there is never a second,
  # independent Postgres session to actually block against. The repo's own
  # precedent for this same claim-lock pattern
  # (RefundServiceTest "a second approve from the same stale struct never
  # reaches the gateway") is likewise a sequential re-entrant call, not a
  # true concurrent race — it proves the re-read-after-lock DECISION logic,
  # not the lock's blocking behavior. We follow that precedent above (the
  # "second claim"/"idempotent"/"exactly once" tests all cover the decision
  # logic sequentially) and add this deterministic, non-flaky guard against
  # the one thing sequential tests can't catch: someone deleting the
  # `lock: "FOR UPDATE"` clause itself.
  test "the claim query holds a FOR UPDATE lock on the pay_links row" do
    {sql, _params} =
      Ecto.Adapters.SQL.to_sql(
        :all,
        Emakola.Repo,
        PayLinkClaim.locked_row_query(Ash.UUID.generate())
      )

    assert sql =~ "FOR UPDATE"
  end
end
