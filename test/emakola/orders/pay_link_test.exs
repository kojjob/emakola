defmodule Emakola.Orders.PayLinkTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.PayLink

  defp create!(store, attrs) do
    PayLink
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  test "custom link gets an 8-char code, active status, 7-day default expiry" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    assert String.match?(link.code, ~r/^[a-z2-7]{8}$/)
    assert link.status == :active
    assert_in_delta DateTime.diff(link.expires_at, DateTime.utc_now(), :day), 7, 1
  end

  test "catalog link has no default expiry and keeps its variant" do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store)
    variant = Emakola.Factory.create_variant!(product, store)
    link = create!(store, %{type: :catalog, variant_id: variant.id})

    assert link.expires_at == nil
    assert link.variant_id == variant.id
  end

  test "catalog link's variant_id must belong to the tenant" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store_b)
    variant = Emakola.Factory.create_variant!(product, store_b)

    assert {:error, %Ash.Error.Invalid{}} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{
               store_id: store_a.id,
               type: :catalog,
               variant_id: variant.id
             })
             |> Ash.create(authorize?: false)
  end

  test "custom link requires amount >= 100" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Deal",
               amount: 99
             })
             |> Ash.create(authorize?: false)
  end

  test "catalog link requires variant_id; custom requires title+amount" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :catalog})
             |> Ash.create(authorize?: false)

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :custom})
             |> Ash.create(authorize?: false)
  end

  test "usable?/1 covers active, expired, cancelled, consumed" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})
    assert :ok = PayLink.usable?(link)

    expired = %{link | expires_at: DateTime.add(DateTime.utc_now(), -1, :day)}
    assert {:error, :expired} = PayLink.usable?(expired)

    assert {:error, :cancelled} = PayLink.usable?(%{link | status: :cancelled})
    assert {:error, :consumed} = PayLink.usable?(%{link | status: :paid})
  end

  test "tenant isolation: store B cannot read store A's link by code" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    link = create!(store_a, %{type: :custom, title: "Deal", amount: 25_000})

    assert {:ok, []} =
             PayLink
             |> Ash.Query.for_read(:get_by_code, %{code: link.code})
             |> Ash.Query.set_tenant(store_b.id)
             |> Ash.read(authorize?: false)
  end

  test "increment_opened bumps the counter" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    updated =
      link
      |> Ash.Changeset.for_update(:increment_opened, %{})
      |> Ash.update!(authorize?: false)

    assert updated.opened_count == 1
  end

  test "cancel transitions an active link to cancelled" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    updated =
      link
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert updated.status == :cancelled
  end

  test "mark_paid transitions an active link to paid" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    updated =
      link
      |> Ash.Changeset.for_update(:mark_paid, %{})
      |> Ash.update!(authorize?: false)

    assert updated.status == :paid
  end

  test "cancel rejects a link that is already paid" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    paid =
      link
      |> Ash.Changeset.for_update(:mark_paid, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             paid
             |> Ash.Changeset.for_update(:cancel, %{})
             |> Ash.update(authorize?: false)
  end

  test "paid_orders_count excludes pending/cancelled orders, counts confirmed+" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    _pending = Emakola.Factory.create_order!(store, %{pay_link_id: link.id})
    _cancelled = Emakola.Factory.create_order!(store, %{pay_link_id: link.id, status: :cancelled})
    _confirmed = Emakola.Factory.create_order!(store, %{pay_link_id: link.id, status: :confirmed})
    _shipped = Emakola.Factory.create_order!(store, %{pay_link_id: link.id, status: :shipped})

    # Unrelated order on the same store, no pay_link_id — must not be counted.
    _unrelated = Emakola.Factory.create_order!(store, %{status: :confirmed})

    loaded = Ash.load!(link, :paid_orders_count, authorize?: false, tenant: store.id)

    assert loaded.paid_orders_count == 2
  end

  test "mark_paid rejects a link that is already cancelled" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    cancelled =
      link
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             cancelled
             |> Ash.Changeset.for_update(:mark_paid, %{})
             |> Ash.update(authorize?: false)
  end

  test "the code unique index spans every store — get_by_code has no tenant to disambiguate with" do
    result =
      Emakola.Repo.query!(
        """
        SELECT indexdef FROM pg_indexes
        WHERE tablename = 'pay_links' AND indexname = 'pay_links_unique_code_index'
        """,
        []
      )

    assert [[indexdef]] = result.rows
    assert indexdef =~ "UNIQUE"

    refute indexdef =~ "store_id",
           "unique_code must stay all_tenants?: true — a per-store index would let " <>
             "two stores mint the same code and crash get_by_code's get?(true)"
  end
end
